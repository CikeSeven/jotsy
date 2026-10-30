// 同步会话的公开类型：进度、结果、确认请求与超时（由 lan_sync_session.dart
// 导出，调用方只需导入那一个文件）。
//
// 纯数据与一个很小的“请求—应答”对象，无 I/O。会话层只认这些类型，界面适配
// 层把它们换算成界面模型（lan_sync_service.dart 顶部有对照）。
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'lan_sync_crypto.dart';
import 'lan_sync_failure.dart';
import 'sync/sync_model.dart';
import 'sync/sync_plan.dart';

/// 会话阶段，按发生顺序（界面的阶段条按下标判断）。
enum LanSyncStage { connecting, comparing, transferring, merging }

/// 会话进度（不可变快照）。
@immutable
class LanSyncProgress {
  const LanSyncProgress({
    this.stage = LanSyncStage.connecting,
    this.sentDiaries = 0,
    this.receivedDiaries = 0,
    this.filesDone = 0,
    this.filesTotal = 0,
    this.bytesDone = 0,
    this.bytesTotal = 0,
    this.bytesPerSecond = 0,
  });

  final LanSyncStage stage;

  /// 对方 / 本机这次要收到的日记篇数（规划后为计划数，写入后为实际数）。
  final int sentDiaries;
  final int receivedDiaries;

  /// 两个方向合计的媒体文件与字节进度；[filesTotal] 为 0 表示没有媒体要传。
  final int filesDone;
  final int filesTotal;
  final int bytesDone;
  final int bytesTotal;

  /// 最近约两秒的平均传输速度；不在传输时为 0。
  final double bytesPerSecond;

  LanSyncProgress copyWith({
    LanSyncStage? stage,
    int? sentDiaries,
    int? receivedDiaries,
    int? filesDone,
    int? filesTotal,
    int? bytesDone,
    int? bytesTotal,
    double? bytesPerSecond,
  }) => LanSyncProgress(
    stage: stage ?? this.stage,
    sentDiaries: sentDiaries ?? this.sentDiaries,
    receivedDiaries: receivedDiaries ?? this.receivedDiaries,
    filesDone: filesDone ?? this.filesDone,
    filesTotal: filesTotal ?? this.filesTotal,
    bytesDone: bytesDone ?? this.bytesDone,
    bytesTotal: bytesTotal ?? this.bytesTotal,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
  );

  @override
  bool operator ==(Object other) =>
      other is LanSyncProgress &&
      other.stage == stage &&
      other.sentDiaries == sentDiaries &&
      other.receivedDiaries == receivedDiaries &&
      other.filesDone == filesDone &&
      other.filesTotal == filesTotal &&
      other.bytesDone == bytesDone &&
      other.bytesTotal == bytesTotal &&
      other.bytesPerSecond == bytesPerSecond;

  @override
  int get hashCode => Object.hash(
    stage,
    sentDiaries,
    receivedDiaries,
    filesDone,
    filesTotal,
    bytesDone,
    bytesTotal,
    bytesPerSecond,
  );
}

/// 一个方向上实际写入的变化：日记的新增 / 更新 / 删除、其余数据的条数与
/// 新放进托管目录的媒体。
@immutable
class LanSyncChangeTally {
  const LanSyncChangeTally({
    this.added = 0,
    this.updated = 0,
    this.deleted = 0,
    this.others = const <SyncEntity, int>{},
    this.mediaFiles = 0,
    this.mediaBytes = 0,
  });

  static const LanSyncChangeTally zero = LanSyncChangeTally();

  /// 解析对方报告的计数（`applied` / `finish`）；字段不对时按 0。
  factory LanSyncChangeTally.fromJson(Object? json) {
    int read(String key) {
      final value = json is Map ? json[key] : null;
      return value is int && value >= 0 ? value : 0;
    }

    final others = json is Map ? json['o'] : null;
    return LanSyncChangeTally(
      added: read('a'),
      updated: read('u'),
      deleted: read('d'),
      others: <SyncEntity, int>{
        if (others is Map)
          for (final entry in others.entries)
            if (SyncEntity.tryParse('${entry.key}') case final entity?)
              if (entity != SyncEntity.diary)
                if (entry.value case final int count when count > 0)
                  entity: count,
      },
      mediaFiles: read('mf'),
      mediaBytes: read('mb'),
    );
  }

  final int added;
  final int updated;
  final int deleted;

  /// 日记以外的变化条数，按 [syncSummaryEntityOf] 归到的实体（只含大于 0
  /// 的项，不含日记）。
  final Map<SyncEntity, int> others;
  final int mediaFiles;
  final int mediaBytes;

  int get diaries => added + updated + deleted;

  int get otherTotal => others.values.fold(0, (sum, count) => sum + count);

  bool get isEmpty => diaries == 0 && otherTotal == 0 && mediaFiles == 0;

  Map<String, Object?> toJson() => <String, Object?>{
    'a': added,
    'u': updated,
    'd': deleted,
    if (others.isNotEmpty)
      'o': <String, int>{
        for (final entry in others.entries) entry.key.name: entry.value,
      },
    'mf': mediaFiles,
    'mb': mediaBytes,
  };

  @override
  bool operator ==(Object other) =>
      other is LanSyncChangeTally &&
      other.added == added &&
      other.updated == updated &&
      other.deleted == deleted &&
      mapEquals(other.others, others) &&
      other.mediaFiles == mediaFiles &&
      other.mediaBytes == mediaBytes;

  @override
  int get hashCode => Object.hash(
    added,
    updated,
    deleted,
    Object.hashAllUnordered(
      others.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    mediaFiles,
    mediaBytes,
  );
}

/// 本次生成的一份冲突副本（摘要里可点开）。
@immutable
class LanSyncCopyInfo {
  const LanSyncCopyInfo({required this.diaryId, required this.title});

  final String diaryId;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is LanSyncCopyInfo &&
      other.diaryId == diaryId &&
      other.title == title;

  @override
  int get hashCode => Object.hash(diaryId, title);
}

/// 一次会话的结果（成功或失败都有）。
@immutable
class LanSyncSessionResult {
  LanSyncSessionResult({
    required this.peerId,
    required this.role,
    required this.automatic,
    required this.startedAt,
    required this.duration,
    this.failure,
    this.received = LanSyncChangeTally.zero,
    this.sent = LanSyncChangeTally.zero,
    List<LanSyncCopyInfo> conflictCopies = const <LanSyncCopyInfo>[],
    this.settingsIncluded = false,
    this.started = false,
    this.transferredFiles = 0,
    this.transferredBytes = 0,
  }) : conflictCopies = List<LanSyncCopyInfo>.unmodifiable(conflictCopies);

  final String peerId;
  final LanSyncRole role;
  final bool automatic;
  final DateTime startedAt;
  final Duration duration;

  /// 失败原因；成功为 null。失败时已写入的部分见各失败点的说明
  /// （lan_sync_session.dart 顶部）。
  final LanSyncFailure? failure;

  /// 本机实际写入的变化 / 对方报告的它实际写入的变化。会话中途失败时为
  /// 截至失败时已经知道的部分。
  final LanSyncChangeTally received;
  final LanSyncChangeTally sent;
  final List<LanSyncCopyInfo> conflictCopies;

  /// 这次是否同步了设置（两端都开启）。
  final bool settingsIncluded;

  /// hello 是否交换成功。之前就失败的（连不上、被拒绝）不算一次同步。
  final bool started;

  /// 两个方向实际经网络传输的媒体文件数与字节数（接收方已有的不传）。
  final int transferredFiles;
  final int transferredBytes;

  bool get succeeded => failure == null;
}

/// 删除保护的选择。
enum LanSyncDeletionDecision {
  /// 照常同步删除。
  syncDeletion,

  /// 不删，把这些日记恢复到删掉它们的那一台。
  keepAndRestore,
}

/// 手动同步中需要用户确认的事项（规格 §4.5）。会话把请求交给调用方，等
/// [LanSyncSideChoiceRequest.respond] / [LanSyncDeletionGuardRequest.respond]
/// 的结果；会话在应答之前结束（取消、断开、超时）时请求作废，之后的应答
/// 不产生效果。
sealed class LanSyncConfirmationRequest {
  LanSyncConfirmationRequest({required this.peerId});

  final String peerId;

  /// 用户的应答（null 为取消或作废）。
  Future<Object?> get answer;

  /// 是否还在等应答。
  bool get isPending;

  /// 会话结束时作废（按“取消”处理）。
  void expire();
}

/// 以哪边为准：[counts] 里的记录两边都改过、且没有共同祖先。
final class LanSyncSideChoiceRequest extends LanSyncConfirmationRequest {
  LanSyncSideChoiceRequest({
    required super.peerId,
    required Map<SyncEntity, int> counts,
  }) : counts = Map<SyncEntity, int>.unmodifiable(counts);

  /// 按实体的记录数（`SyncPendingConfirmations.sideChoiceCounts`）。
  final Map<SyncEntity, int> counts;

  /// 合计。
  int get conflicts => counts.values.fold(0, (sum, count) => sum + count);
  final Completer<SyncSideChoice?> _answer = Completer<SyncSideChoice?>();

  @override
  Future<SyncSideChoice?> get answer => _answer.future;

  @override
  bool get isPending => !_answer.isCompleted;

  /// 用户的选择（本机 = 发起方 = [SyncSideChoice.preferLocal]）；null 为取消。
  void respond(SyncSideChoice? choice) {
    if (!_answer.isCompleted) _answer.complete(choice);
  }

  @override
  void expire() => respond(null);
}

/// 删除保护：这次同步会在 [onLocalSide] 为 true 的本机（否则对方）彻底删除
/// [count] 篇日记。
final class LanSyncDeletionGuardRequest extends LanSyncConfirmationRequest {
  LanSyncDeletionGuardRequest({
    required super.peerId,
    required this.count,
    required this.onLocalSide,
  });

  final int count;
  final bool onLocalSide;
  final Completer<LanSyncDeletionDecision?> _answer =
      Completer<LanSyncDeletionDecision?>();

  @override
  Future<LanSyncDeletionDecision?> get answer => _answer.future;

  @override
  bool get isPending => !_answer.isCompleted;

  /// 用户的选择；null 为取消（什么都不写）。
  void respond(LanSyncDeletionDecision? decision) {
    if (!_answer.isCompleted) _answer.complete(decision);
  }

  @override
  void expire() => respond(null);
}

/// 会话的计时（测试注入短时长）。
@immutable
class LanSyncSessionTimeouts {
  const LanSyncSessionTimeouts({
    this.silence = const Duration(seconds: 30),
    this.keepAlive = const Duration(seconds: 5),
    this.confirmation = const Duration(minutes: 10),
    this.progressInterval = const Duration(milliseconds: 100),
  });

  /// 等对方的消息时，最长多久没收到任何东西（含 `sync.ping` 与数据块的
  /// 数据）即判超时。对方做耗时的本机工作时每 [keepAlive] 发一次 ping，所以
  /// 这里衡量的是“对方没声音”，不是某一步的总时长。
  final Duration silence;

  /// 本机做耗时工作（刷新检查点、构建记录、写入、等用户确认）期间发 ping
  /// 的间隔；必须明显短于 [silence]。
  final Duration keepAlive;

  /// 手动同步等用户确认的上限：超过即按超时中止（对方一直在等）。
  final Duration confirmation;

  /// 传输中进度通知的最小间隔（每个文件结束时总会通知一次）。
  final Duration progressInterval;
}
