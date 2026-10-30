// 一次同步会话：在握手建立的加密信道上，发起方与响应方按 docs/lan_sync.md
// §5.3 的消息顺序交换清单、按需取数、规划、传媒体、写入（§6）。
//
// 职责边界：
// - 输入：已建立的 [LanSyncChannel]、本机同步部件（[LanSyncSessionContext]）、
//   对方信息与本次选项；发起方另有确认回调与冲突副本标题后缀；
// - 输出：[LanSyncSession.progress]（进度）、[LanSyncSession.run] 的
//   [LanSyncSessionResult]（成功或失败原因、两边实际写入的计数、冲突副本）；
// - 副作用：经 [SyncLocalState] 刷新检查点、经 [SyncApplier] 写库与就位媒体、
//   在数据根目录的暂存区收文件；结束时（任何路径）关闭信道、删除暂存区。
//
// 状态机（两个角色各自按顺序推进，任一步失败即进入“结束”）：
//   连接 → hello（拒绝即结束）→ 冲刷 + 刷新检查点 → 清单 → 取数循环 →
//   规划 → 确认 → 媒体协商与双向传输 → 响应方写入 → 发起方写入 → 照做改键 →
//   完成。响应方只按收到的请求应答，顺序由发起方驱动。
//
// 等待与超时：等对方消息时衡量的是“对方多久没声音”（[LanSyncSessionTimeouts
// .silence]），任何消息、ping 或数据块的数据都会重置计时；本机做耗时工作
// （刷新、构建记录、写入、等用户确认）时每 [LanSyncSessionTimeouts.keepAlive]
// 发一次 `sync.ping`，对方因此不会误判超时。等用户确认另有总上限。
//
// 取消（[LanSyncSession.cancel]，任一方）：立即发 `sync.abort{cancelled}` 并
// 关闭信道，正在进行的网络等待随之报错退出；正在执行的本机步骤（刷新检查点、
// 写入事务）不能中途打断，执行完才结束——[run] 的 future 在那之后才完成，
// 调用方据此保证同一个 [SyncLocalState] 不会被两次会话并发使用。
//
// 各失败点两边已写入的内容（写入本身按设计可部分进行，§4 末段）：
// - 写入之前（hello、清单、取数、规划、确认、媒体传输）：两边都没有写库；
//   只刷新了各自的检查点（下次照常比较），收到一半的媒体在暂存区，随会话
//   结束删除；
// - 响应方写入中 / 写入后、发起方写入前：响应方的写入是一个事务，要么整份
//   生效要么回滚；生效后发起方还没写——下次同步重新规划，只剩发起方一侧的
//   差异；
// - 发起方写入后、照做改键前：两边都写了，只差媒体改键的引用改写（只在同键
//   不同文件这种巧合下才有），下次同步把它判成普通差异处理；
// - 自动同步遇到需要确认的情况、用户取消确认、撤销提示一直不关（推迟）：
//   在任何写入之前中止，两边都不写。
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'lan_sync_channel.dart';
import 'lan_sync_crypto.dart';
import 'lan_sync_failure.dart';
import 'lan_sync_messages.dart';
import 'lan_sync_session_context.dart';
import 'lan_sync_session_plan_wire.dart';
import 'lan_sync_session_protocol.dart';
import 'lan_sync_session_types.dart';
import 'sync/sync_apply.dart';
import 'sync/sync_local_plan_side.dart';
import 'sync/sync_local_state.dart';
import 'sync/sync_media.dart';
import 'sync/sync_media_index.dart';
import 'sync/sync_media_refs.dart';
import 'sync/sync_model.dart';
import 'sync/sync_plan.dart';
import 'sync/sync_plan_side.dart';
import 'sync/sync_planner.dart';
import 'sync/sync_state_json.dart';
import 'sync/sync_state_model.dart';

export 'lan_sync_failure.dart';
export 'lan_sync_session_context.dart';
export 'lan_sync_session_types.dart';

part 'lan_sync_session_inbox.dart';
part 'lan_sync_session_initiator.dart';
part 'lan_sync_session_media.dart';
part 'lan_sync_session_planning.dart';
part 'lan_sync_session_responder.dart';

class LanSyncSession {
  /// 发起方：本机规划，[onConfirmation] 收到需要用户确认的请求（只在手动
  /// 同步时调用；自动同步遇到即中止）。冲突副本标题后缀由界面层本地化好：
  /// [localLoserTitleSuffix] 用于本机版本的副本（写本机设备名），
  /// [remoteLoserTitleSuffix] 用于对方版本的副本（写对方的显示名）。
  LanSyncSession.initiator({
    required LanSyncChannel channel,
    required this._context,
    required this.peer,
    required this._automatic,
    required this._syncSettings,
    required this._localLoserTitleSuffix,
    required this._remoteLoserTitleSuffix,
    required this._onConfirmation,
    this._timeouts = const LanSyncSessionTimeouts(),
  }) : role = LanSyncRole.initiator,
       _channel = channel,
       _acceptAutomatic = false,
       _busy = false {
    _inbox = _SessionInbox(channel);
  }

  /// 响应方：按发起方的请求应答。[acceptAutomatic] 为 false 时拒绝自动同步
  /// （`declined`）；[busy] 为 true（正与别的设备同步）或本机有编辑页时回
  /// `busy`。
  LanSyncSession.responder({
    required LanSyncChannel channel,
    required this._context,
    required this.peer,
    required this._syncSettings,
    required this._acceptAutomatic,
    this._busy = false,
    this._timeouts = const LanSyncSessionTimeouts(),
  }) : role = LanSyncRole.responder,
       _channel = channel,
       _automatic = false,
       _localLoserTitleSuffix = '',
       _remoteLoserTitleSuffix = '',
       _onConfirmation = _neverAsked {
    _inbox = _SessionInbox(channel);
  }

  final LanSyncRole role;
  final LanSyncSessionPeer peer;
  final LanSyncChannel _channel;
  final LanSyncSessionContext _context;
  final LanSyncSessionTimeouts _timeouts;
  final bool _syncSettings;
  final String _localLoserTitleSuffix;
  final String _remoteLoserTitleSuffix;
  final void Function(LanSyncConfirmationRequest request) _onConfirmation;
  final bool _acceptAutomatic;
  final bool _busy;
  late final _SessionInbox _inbox;

  final ValueNotifier<LanSyncProgress> _progress =
      ValueNotifier<LanSyncProgress>(const LanSyncProgress());
  Future<LanSyncSessionResult>? _run;
  bool _automatic;
  bool _cancelled = false;
  bool _abortSent = false;
  bool _helloDone = false;
  bool _settingsIncluded = false;
  LanSyncConfirmationRequest? _pendingConfirmation;
  SyncMediaStaging? _staging;
  LanSyncChangeTally _received = LanSyncChangeTally.zero;
  LanSyncChangeTally _sent = LanSyncChangeTally.zero;
  List<LanSyncCopyInfo> _copies = const <LanSyncCopyInfo>[];
  int _nextBlobId = 1;
  int _bytesDone = 0;
  final _SpeedMeter _speed = _SpeedMeter();
  DateTime? _lastProgressAt;

  /// 会话进度。
  ValueListenable<LanSyncProgress> get progress => _progress;

  /// 是否为自动同步（响应方在收到 hello 之后才知道）。
  bool get automatic => _automatic;

  /// 正在等用户应答的确认请求（“查看”时再交给界面一次）。
  LanSyncConfirmationRequest? get pendingConfirmation => _pendingConfirmation;

  /// 运行会话；重复调用返回同一个结果。
  Future<LanSyncSessionResult> run() => _run ??= _execute();

  /// 取消：告诉对方并关闭信道（见文件头“取消”）。
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _pendingConfirmation?.expire();
    _inbox.fail(const _SessionStop(LanSyncFailure.cancelled));
    unawaited(
      _sendAbort(LanSyncFailure.cancelled.name).whenComplete(_channel.close),
    );
  }

  Future<LanSyncSessionResult> _execute() async {
    final startedAt = _context.clock();
    LanSyncFailure? failure;
    try {
      if (role == LanSyncRole.initiator) {
        await _runInitiator();
      } else {
        await _runResponder();
      }
    } catch (error, stack) {
      failure = _failureOf(error);
      if (failure == LanSyncFailure.unknown) {
        debugPrint('LAN sync session failed: $error\n$stack');
      }
      // 对方中止、对方拒绝、连接已断时不必（也无法）再告诉对方。
      final wire = error is _SessionStop ? error.wire : null;
      if (error is! _HelloRejected &&
          _inbox.peerStop == null &&
          failure != LanSyncFailure.connectionLost) {
        await _sendAbort(wire ?? failure.name);
      }
    } finally {
      _pendingConfirmation?.expire();
      await _staging?.dispose();
      _staging = null;
      await _channel.close();
      _inbox.dispose();
    }
    return LanSyncSessionResult(
      peerId: peer.deviceId,
      role: role,
      automatic: _automatic,
      startedAt: startedAt,
      duration: _context.clock().difference(startedAt),
      failure: failure,
      received: _received,
      sent: _sent,
      conflictCopies: _copies,
      settingsIncluded: _settingsIncluded,
      started: _helloDone,
      transferredFiles: _progress.value.filesDone,
      transferredBytes: _bytesDone,
    );
  }

  LanSyncFailure _failureOf(Object error) {
    if (_cancelled) return LanSyncFailure.cancelled;
    final fromPeer = _inbox.peerStop;
    if (fromPeer != null) return fromPeer.failure;
    return switch (error) {
      _SessionStop(:final failure) => failure,
      TimeoutException() => LanSyncFailure.timedOut,
      LanSyncChannelException(error: LanSyncChannelError.protocolError) =>
        LanSyncFailure.protocolError,
      LanSyncChannelException() => LanSyncFailure.connectionLost,
      SyncMediaVerificationException() => LanSyncFailure.transferFailed,
      FormatException() ||
      ArgumentError() ||
      StateError() => LanSyncFailure.protocolError,
      _ => LanSyncFailure.unknown,
    };
  }

  /// 告诉对方中止原因；对方已断开或信道已关闭时忽略。
  Future<void> _sendAbort(String reason) async {
    if (_abortSent || _channel.isClosed) return;
    _abortSent = true;
    try {
      await _channel.send(
        LanSyncMessage(LanSyncSessionMessages.abort, {'reason': reason}),
      );
    } on Object {
      // 中止只是告知，送不到不改变本机的结果。
    }
  }

  Future<void> _send(String type, [Map<String, Object?> fields = const {}]) {
    _checkpoint();
    return _write(() => _channel.send(LanSyncMessage(type, fields)));
  }

  /// 信道写入。套接字在本机被销毁、信道还没察觉时，底层 IOSink 会抛
  /// StateError——那就是连接断了，按断线处理而不是协议错误。
  Future<void> _write(Future<void> Function() write) async {
    try {
      await write();
    } on StateError catch (error) {
      throw LanSyncChannelException(
        LanSyncChannelError.connectionLost,
        '$error',
      );
    }
  }

  /// 等下一条消息，类型必须在 [types] 里（不然是协议错误）。
  Future<LanSyncMessage> _expect(Set<String> types) async {
    final message = await _inbox.next(_timeouts.silence);
    if (!types.contains(message.type)) {
      throw FormatException('unexpected ${message.type}, wanted $types');
    }
    return message;
  }

  /// 取消、对方中止或断开之后不再往下走（本机步骤之间调用）。
  void _checkpoint() {
    if (_cancelled) throw const _SessionStop(LanSyncFailure.cancelled);
    _inbox.throwIfStopped();
  }

  /// 执行本机耗时步骤，期间定时发 ping，让对方知道本机还在。
  Future<T> _keepAlive<T>(Future<T> Function() body) async {
    final timer = Timer.periodic(_timeouts.keepAlive, (_) {
      if (_channel.isClosed) return;
      _channel.send(LanSyncMessage(LanSyncSessionMessages.ping)).ignore();
    });
    try {
      return await body();
    } finally {
      timer.cancel();
    }
  }

  void _setStage(LanSyncStage stage) {
    if (_progress.value.stage.index >= stage.index) return;
    _progress.value = _progress.value.copyWith(stage: stage, bytesPerSecond: 0);
  }

  void _setProgress(LanSyncProgress Function(LanSyncProgress p) change) {
    _progress.value = change(_progress.value);
  }

  String _newStagingId() {
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '${_context.clock().millisecondsSinceEpoch}-$random';
  }
}

/// 响应方从不问用户（只有发起方规划）。
void _neverAsked(LanSyncConfirmationRequest request) => request.expire();

/// 会话内部的中止：[failure] 是本机的失败原因，[wire] 是发给对方的原因
/// （默认同名；本机取消确认时告诉对方的是 `declined`）。
class _SessionStop implements Exception {
  const _SessionStop(this.failure, {this.wire});

  final LanSyncFailure failure;
  final String? wire;

  @override
  String toString() => '_SessionStop(${failure.name})';
}

/// hello 阶段的拒绝（任一方发出 `sync.reject`）：拒绝本身就是告知，不再发
/// 中止。
class _HelloRejected extends _SessionStop {
  const _HelloRejected(super.failure);
}
