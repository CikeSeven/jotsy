// 服务的会话记账：正在进行的会话、结束后的配对记录 / 同步记录 / 事件、
// 确认请求的转交，以及覆盖恢复的钩子（lan_sync_service.dart 的一部分）。
part of 'lan_sync_service.dart';

/// 正在进行（或正在连接）的一次会话。服务同一时刻最多一个，它在的时候
/// 新的出站同步不开始、传入的同步回 busy。
class _ActiveSession {
  _ActiveSession(this.peerId, {required this.role, required this.automatic});

  final String peerId;
  final LanSyncRole role;
  final bool automatic;
  final ValueNotifier<LanSyncProgress> progress =
      ValueNotifier<LanSyncProgress>(const LanSyncProgress());
  final Completer<void> _finished = Completer<void>();
  LanSyncSession? session;
  bool cancelRequested = false;

  /// 连接或握手阶段取消时调用（销毁套接字）；进入会话后为 null。
  void Function()? abortConnect;

  /// 会话完全结束（含本机写入步骤）后完成。
  Future<void> get finished => _finished.future;

  /// 传入的会话在 hello 之前（可能马上被拒绝）不显示进度。
  bool get visible =>
      role == LanSyncRole.initiator ||
      progress.value.stage != LanSyncStage.connecting;

  void attach(LanSyncSession next, VoidCallback onProgress) {
    session = next;
    abortConnect = null;
    next.progress.addListener(() {
      progress.value = next.progress.value;
      onProgress();
    });
    if (cancelRequested) next.cancel();
  }

  void cancel() {
    if (cancelRequested) return;
    cancelRequested = true;
    session?.cancel();
    abortConnect?.call();
  }

  void finish() {
    if (!_finished.isCompleted) _finished.complete();
  }
}

extension _Sessions on LanSyncService {
  LanSyncSessionContext _sessionContext() => LanSyncSessionContext(
    deviceId: _identity.deviceId,
    state: _syncState,
    applier: _applier,
    media: _mediaLibrary,
    mediaIndex: _mediaIndex,
    dataRoot: dataRoot,
    flushAll: editing.flushAll,
    isEditing: editing.isEditing,
    clock: hooks.clock,
    appVersion: appVersion,
  );

  LanSyncHandshake _handshake() => LanSyncHandshake(
    identity: _identity,
    local: LanSyncLocalInfo(
      name: _deviceName,
      platform: hooks.platformId(),
      formatVersion: kSyncFormatVersion,
    ),
    stepTimeout: timings.handshakeStep,
    sasTimeout: timings.sasTimeout,
    lingerTimeout: timings.handshakeLinger,
  );

  bool _isTrusted(String deviceId, List<int> publicKey) =>
      _store.peer(deviceId)?.matches(deviceId, publicKey) ?? false;

  /// 是否同步设置：开关开着且有设置服务（测试与早期装配可能不给）。
  bool get _syncSettings => _store.prefs.syncSettings && settings != null;

  /// 手动同步要用户确认：转交界面，等待期间与应答之后各刷新一次状态
  /// （“需要确认”标记跟着变）。
  void _onConfirmation(LanSyncConfirmationRequest request) {
    _publish();
    request.answer.whenComplete(_publish).ignore();
    _emit(LanSyncConfirmationRequested(request));
  }

  /// 握手里看到的对方名字、平台变了就更新配对记录。
  Future<void> _notePeerHello(LanSyncPeerHello hello) async {
    final device = _store.peer(hello.deviceId);
    if (device == null ||
        (device.name == hello.name && device.platform == hello.platform)) {
      return;
    }
    await _store.updatePeer(
      hello.deviceId,
      (d) => d.copyWith(name: hello.name, platform: hello.platform),
    );
  }

  /// 配对成功：保存对方的公钥。重新配对同一个身份时保留同步记忆（上次同步、
  /// 标记）；对方换了身份（重装、身份损坏重建）则从头当作首次同步。
  Future<void> _savePairedPeer(
    LanSyncPeerHello hello, {
    String? host,
    int? port,
  }) async {
    final existing = _store.peer(hello.deviceId);
    final sameKey =
        existing != null &&
        lanSyncBytesEqual(existing.publicKey, hello.publicKey);
    await _store.upsertPeer(
      LanSyncPairedDevice(
        deviceId: hello.deviceId,
        name: hello.name,
        platform: hello.platform,
        publicKey: hello.publicKey,
        pairedAt: _now().toUtc(),
        lastSyncAt: sameKey ? existing.lastSyncAt : null,
        lastHost: host ?? existing?.lastHost,
        lastPort: port ?? existing?.lastPort,
        autoSync: existing?.autoSync ?? true,
        alias: existing?.alias,
        needsAttention: sameKey && existing.needsAttention,
        restoredPending: sameKey && existing.restoredPending,
      ),
    );
  }

  /// 会话结束后的记账：
  /// - 成功：上次同步时间、清除“需要确认”与“覆盖恢复待确认”；
  /// - 自动同步遇到需要确认：标记这台设备；
  /// - 同步记录：hello 之后的会话都记；之前就失败的只记本机手动发起的
  ///   （连不上、对方拒绝等，界面的时间线据此说明原因），本机在编辑而没
  ///   开始的不记；
  /// - 事件：会话结束；自动同步写入了本机日记 / 需要确认时各再发一个。
  Future<void> _finishSession(
    LanSyncSessionResult result, {
    required bool firstSync,
  }) async {
    final device = _store.peer(result.peerId);
    if (device != null) {
      if (result.succeeded) {
        await _store.updatePeer(
          result.peerId,
          (d) => d.copyWith(
            lastSyncAt: () => _now().toUtc(),
            needsAttention: false,
            restoredPending: false,
          ),
        );
      } else if (result.failure == LanSyncFailure.needsConfirmation) {
        await _store.updatePeer(
          result.peerId,
          (d) => d.copyWith(needsAttention: true),
        );
      }
      final manualAttempt =
          result.role == LanSyncRole.initiator &&
          !result.automatic &&
          result.failure != LanSyncFailure.localEditing;
      if (result.started || manualAttempt) {
        await _store.addSession(
          LanSyncSessionRecord(
            peerId: result.peerId,
            at: result.startedAt.toUtc(),
            duration: result.succeeded ? result.duration : null,
            automatic: result.automatic,
            receivedDiaries: result.received.diaries,
            sentDiaries: result.sent.diaries,
            mediaBytes: result.transferredBytes,
            conflictCopies: result.conflictCopies.length,
            firstSync: firstSync,
            failure: result.failure,
          ),
        );
      }
    }
    if (result.automatic && result.role == LanSyncRole.responder) {
      _auto.autoSessionRan(result.peerId, result.startedAt);
    }
    _emit(LanSyncSessionEnded(result, firstSync: firstSync));
    if (result.automatic && result.succeeded && result.received.diaries > 0) {
      _emit(
        LanSyncAutoSyncApplied(
          peerId: result.peerId,
          diaries: result.received.diaries,
        ),
      );
    }
    if (result.failure == LanSyncFailure.needsConfirmation) {
      _emit(LanSyncAttentionNeeded(result.peerId));
    }
  }

  /// “查看”：正在等确认的手动同步把同一个请求再交给界面一次；没有正在等的、
  /// 而自动同步留下了“需要确认”标记时，发起一次手动同步（重新规划、问用户）。
  void _review(String peerId) {
    final active = _active;
    final pending = active?.session?.pendingConfirmation;
    if (active != null && active.peerId == peerId) {
      if (pending != null && pending.isPending) {
        _emit(LanSyncConfirmationRequested(pending));
      }
      return;
    }
    if (_store.peer(peerId)?.needsAttention ?? false) {
      unawaited(_syncWith(peerId, automatic: false));
    }
  }

  LanSyncSessionResult _failedResult(
    String peerId,
    DateTime startedAt,
    LanSyncFailure failure, {
    required bool automatic,
  }) => LanSyncSessionResult(
    peerId: peerId,
    role: LanSyncRole.initiator,
    automatic: automatic,
    startedAt: startedAt,
    duration: _now().difference(startedAt),
    failure: failure,
  );
}
