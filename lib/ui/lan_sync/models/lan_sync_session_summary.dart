// 一次手动同步结束后的摘要（不可变、按值比较），随
// `LanSyncSessionFinishedEvent` 交给完成 / 失败面板。

import 'package:flutter/foundation.dart';

import 'lan_sync_item_counts.dart';
import 'lan_sync_session_view.dart';

/// 一个方向上的变化计数（完成摘要的“收到 / 发出”两列）。
@immutable
class LanSyncChangeCounts {
  const LanSyncChangeCounts({
    this.added = 0,
    this.updated = 0,
    this.deleted = 0,
    this.others = LanSyncItemCounts.empty,
    this.mediaCount = 0,
    this.mediaBytes = 0,
  });

  static const LanSyncChangeCounts zero = LanSyncChangeCounts();

  /// 新增 / 更新 / 删除的日记篇数。
  final int added;
  final int updated;
  final int deleted;

  /// 日记以外的变化（不含日记一项）。
  final LanSyncItemCounts others;

  /// 媒体文件个数与字节数。
  final int mediaCount;
  final int mediaBytes;

  /// 这个方向的日记篇数合计（摘要卡片的大号数字）。
  int get diaries => added + updated + deleted;

  bool get isEmpty => diaries == 0 && others.isEmpty && mediaCount == 0;

  @override
  bool operator ==(Object other) =>
      other is LanSyncChangeCounts &&
      other.added == added &&
      other.updated == updated &&
      other.deleted == deleted &&
      other.others == others &&
      other.mediaCount == mediaCount &&
      other.mediaBytes == mediaBytes;

  @override
  int get hashCode =>
      Object.hash(added, updated, deleted, others, mediaCount, mediaBytes);
}

/// 一篇冲突副本：两边都改过的日记，较新的留在原日记，另一份存为副本。
@immutable
class LanSyncConflictCopy {
  const LanSyncConflictCopy({required this.diaryId, required this.title});

  /// 副本的日记业务 id（点按经 `openDiaryPage` 打开）。
  final String diaryId;

  /// 副本标题；没写标题时为空串（界面显示“无标题”）。
  final String title;

  @override
  bool operator ==(Object other) =>
      other is LanSyncConflictCopy &&
      other.diaryId == diaryId &&
      other.title == title;

  @override
  int get hashCode => Object.hash(diaryId, title);
}

/// 一次手动同步结束后的摘要（完成 / 失败面板）。
@immutable
class LanSyncSessionSummary {
  const LanSyncSessionSummary({
    required this.peerName,
    required this.duration,
    this.received = LanSyncChangeCounts.zero,
    this.sent = LanSyncChangeCounts.zero,
    this.conflictCopies = const <LanSyncConflictCopy>[],
    this.failureReason,
  });

  /// 对方的显示名（备注名优先）。
  final String peerName;
  final Duration duration;
  final LanSyncChangeCounts received;
  final LanSyncChangeCounts sent;
  final List<LanSyncConflictCopy> conflictCopies;

  /// 失败原因；成功为 null。
  final LanSyncFailureReason? failureReason;

  bool get succeeded => failureReason == null;

  /// 成功且两边都没有任何变化（面板只显示“已经是最新的了”）。
  bool get upToDate =>
      succeeded && received.isEmpty && sent.isEmpty && conflictCopies.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is LanSyncSessionSummary &&
      other.peerName == peerName &&
      other.duration == duration &&
      other.received == received &&
      other.sent == sent &&
      listEquals(other.conflictCopies, conflictCopies) &&
      other.failureReason == failureReason;

  @override
  int get hashCode => Object.hash(
    peerName,
    duration,
    received,
    sent,
    Object.hashAll(conflictCopies),
    failureReason,
  );
}
