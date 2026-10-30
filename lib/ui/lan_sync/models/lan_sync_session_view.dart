// 同步会话的进度与同步记录（不可变、按值比较）。
//
// 会话进度挂在 `LanSyncPeerView.session` 上，由设备卡片里的会话面板显示；
// 同步记录挂在 `LanSyncPeerView.history`，由设备详情页的时间线显示。结束
// 摘要见 lan_sync_session_summary.dart。

import 'package:flutter/foundation.dart';

/// 会话阶段，按发生顺序排列（阶段条按下标判断完成 / 当前 / 未到）。
enum LanSyncSessionStage { connecting, comparing, transferring, merging }

/// 同步失败（或配对失败）的原因；界面按它给出说明与下一步。
enum LanSyncFailureReason {
  /// 连不上对方（地址不对、对方不在线或防火墙拦截）。
  unreachable,

  /// 传输中途断开；已写入的部分下次会自动补齐。
  connectionLost,

  /// 对方长时间没有回应（含配对 60 秒内没有确认）。
  timedOut,

  /// 对方拒绝了配对或同步。
  declined,

  /// 用户自己取消。
  cancelled,

  /// 两边的同步格式版本不兼容，需要把旧的那台升级。
  incompatibleVersion,

  /// 对方不再认识本机（在那边取消了配对），需要重新配对。
  untrusted,

  /// 二维码已失效（过期或已用过）。
  ticketExpired,

  /// 本机写入失败（如存储空间不足）。
  writeFailed,

  /// 对方正在编辑日记（或正与另一台设备同步），拒绝了这次同步；配对时为
  /// 本机已有另一次配对在进行。
  busy,

  /// 本机有正在编辑的页面，手动同步没有开始。
  localEditing,

  /// 撤销提示还开着，这次什么都没有写入（写入推迟）。
  deferred,

  /// 自动同步遇到需要用户确认的情况，已中止。只出现在同步记录里：完成
  /// 摘要只给手动同步，自动同步改走“需要确认”的提示与“查看”。
  needsConfirmation,

  /// 其他原因。
  unknown,
}

/// 正在进行的一次同步。
@immutable
class LanSyncSessionView {
  const LanSyncSessionView({
    required this.peerId,
    required this.stage,
    this.sentDiaries = 0,
    this.receivedDiaries = 0,
    this.filesDone = 0,
    this.filesTotal = 0,
    this.bytesDone = 0,
    this.bytesTotal = 0,
    this.bytesPerSecond = 0,
  });

  final String peerId;
  final LanSyncSessionStage stage;

  /// 本次已发出 / 已收到的日记篇数（连线面板下方的计数）。
  final int sentDiaries;
  final int receivedDiaries;

  /// 媒体文件进度；[filesTotal] 为 0 表示没有媒体要传（进度区改为不定进度）。
  final int filesDone;
  final int filesTotal;
  final int bytesDone;
  final int bytesTotal;

  /// 最近的传输速度（字节 / 秒）；不在传输时为 0。
  final double bytesPerSecond;

  /// 是否有媒体要传。
  bool get hasMedia => filesTotal > 0;

  /// 媒体传输进度 0–1；没有媒体或总量未知时为 null（不定进度）。
  double? get mediaProgress {
    if (bytesTotal > 0) return (bytesDone / bytesTotal).clamp(0.0, 1.0);
    if (filesTotal > 0) return (filesDone / filesTotal).clamp(0.0, 1.0);
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is LanSyncSessionView &&
      other.peerId == peerId &&
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
    peerId,
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

/// 同步记录里的一条（设备详情页时间线）。
@immutable
class LanSyncHistoryEntryView {
  const LanSyncHistoryEntryView({
    required this.at,
    this.duration,
    this.automatic = false,
    this.receivedDiaries = 0,
    this.sentDiaries = 0,
    this.mediaBytes = 0,
    this.conflictCopies = 0,
    this.firstSync = false,
    this.failureReason,
  });

  /// 同步开始的时间。
  final DateTime at;

  /// 用时；失败或未知时为 null。
  final Duration? duration;

  /// 是否为自动同步（时间线右侧显示“自动”而不是用时）。
  final bool automatic;
  final int receivedDiaries;
  final int sentDiaries;

  /// 两个方向合计传输的媒体字节数。
  final int mediaBytes;

  /// 本次产生的冲突副本篇数。
  final int conflictCopies;

  /// 是否为配对后的第一次同步（节点为 `outline` 色）。
  final bool firstSync;

  /// 失败原因；成功为 null。
  final LanSyncFailureReason? failureReason;

  bool get succeeded => failureReason == null;

  @override
  bool operator ==(Object other) =>
      other is LanSyncHistoryEntryView &&
      other.at == at &&
      other.duration == duration &&
      other.automatic == automatic &&
      other.receivedDiaries == receivedDiaries &&
      other.sentDiaries == sentDiaries &&
      other.mediaBytes == mediaBytes &&
      other.conflictCopies == conflictCopies &&
      other.firstSync == firstSync &&
      other.failureReason == failureReason;

  @override
  int get hashCode => Object.hash(
    at,
    duration,
    automatic,
    receivedDiaries,
    sentDiaries,
    mediaBytes,
    conflictCopies,
    firstSync,
    failureReason,
  );
}
