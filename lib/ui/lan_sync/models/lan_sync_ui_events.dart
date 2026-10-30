// 同步控制器推给界面的一次性事件（`LanSyncUiController.events`）。
//
// 视图状态（`LanSyncViewState`）描述“现在是什么样”；这里是“刚发生了什么、
// 需要界面做出反应”：弹配对面板、弹确认对话框、弹完成面板、显示自动同步
// 提示。事件不重放：没有监听者时发出的事件即丢弃，等待确认的同步改由
// `LanSyncPeerView.needsAttention` 留在状态里，用户点“查看”时再发一次。

import 'package:flutter/foundation.dart';

import 'lan_sync_item_counts.dart';
import 'lan_sync_platform.dart';
import 'lan_sync_session_summary.dart';
import 'lan_sync_session_view.dart';

/// 所有界面事件的基类。
@immutable
sealed class LanSyncUiEvent {
  const LanSyncUiEvent();
}

/// 配对由哪一方发起。
enum LanSyncPairingDirection {
  /// 本机发起（点了附近设备的“配对”、手动输入地址或扫码）。
  outgoing,

  /// 对方发起，本机被请求（面板标题为“「X」请求配对”）。
  incoming,
}

/// 配对的进展；配对面板按它切换内容。
@immutable
sealed class LanSyncPairingPhase {
  const LanSyncPairingPhase();
}

/// 正在连接对方、建立加密信道（面板显示“正在连接 X…”）。
final class LanSyncPairingConnecting extends LanSyncPairingPhase {
  const LanSyncPairingConnecting();

  @override
  bool operator ==(Object other) => other is LanSyncPairingConnecting;

  @override
  int get hashCode => (LanSyncPairingConnecting).hashCode;
}

/// 核对码已算出，等本机用户确认两边数字一致。
final class LanSyncPairingAwaitingUser extends LanSyncPairingPhase {
  const LanSyncPairingAwaitingUser(this.code);

  /// 6 位十进制核对码（显示为 3 + 3）。
  final String code;

  @override
  bool operator ==(Object other) =>
      other is LanSyncPairingAwaitingUser && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// 本机已确认，等对方确认（按钮区换成“等待对方确认…”）。
final class LanSyncPairingAwaitingPeer extends LanSyncPairingPhase {
  const LanSyncPairingAwaitingPeer(this.code);

  final String code;

  @override
  bool operator ==(Object other) =>
      other is LanSyncPairingAwaitingPeer && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// 双方都已确认（或扫码令牌校验通过），对方已记为已配对设备。
final class LanSyncPairingSucceeded extends LanSyncPairingPhase {
  const LanSyncPairingSucceeded(this.peerId);

  /// 新配对设备的 id：成功态的“立即同步”经 `syncNow(peerId)`。
  final String peerId;

  @override
  bool operator ==(Object other) =>
      other is LanSyncPairingSucceeded && other.peerId == peerId;

  @override
  int get hashCode => peerId.hashCode;
}

/// 配对没有完成：任一方拒绝、超时或连接失败；什么都不会保存。
final class LanSyncPairingFailed extends LanSyncPairingPhase {
  const LanSyncPairingFailed(this.reason);

  final LanSyncFailureReason reason;

  @override
  bool operator ==(Object other) =>
      other is LanSyncPairingFailed && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

/// 一次配对开始：界面弹出配对面板，并随 [phase] 更新。
///
/// 同一次配对只发一次本事件；之后的进展都经 [phase]。面板关闭（含用户下滑
/// 关掉）时须调用 `respond(false)`，控制器据此放弃这次配对。
final class LanSyncPairingEvent extends LanSyncUiEvent {
  const LanSyncPairingEvent({
    required this.direction,
    required this.peerName,
    required this.platform,
    required this.phase,
    required this.respond,
  });

  final LanSyncPairingDirection direction;

  /// 对方的设备名（连接前取自信标或二维码，可能随握手更新到 [phase] 之前）。
  final String peerName;
  final LanSyncPlatform platform;

  /// 配对进展；成功或失败之后不再变化。
  final ValueListenable<LanSyncPairingPhase> phase;

  /// 用户的决定：true 为“一致，配对”（核对码阶段）；false 为“不一致”、
  /// 取消或关闭面板。完成时表示决定已交给对方，不代表配对已成功（结果看
  /// [phase]）。在成功 / 失败之后调用不产生效果。
  final Future<void> Function(bool accept) respond;
}

/// 以哪边为准：两边都改过的日记该怎么合并。
enum LanSyncSideChoice {
  /// 保留两份（推荐，默认选中）：较新的留在原日记，另一份存为冲突副本。
  keepBoth,

  /// 以本机为准。
  preferLocal,

  /// 以对方为准。
  preferPeer,
}

/// 删除保护：这次同步会彻底删除日记时怎么处理。
enum LanSyncDeletionChoice {
  /// 同步删除。
  syncDeletion,

  /// 保留，并恢复到另一台。
  keepAndRestore,
}

/// 删除发生在哪一边。
enum LanSyncSide { local, peer }

/// 一次同步需要用户确认后才能继续（`showAppDialog` 的确认对话框）。
///
/// 自动同步遇到时不弹对话框，只发 [LanSyncAutoSyncNeedsAttentionEvent] 并在
/// 状态里标记 `needsAttention`；用户点“查看”后控制器再发本事件。
sealed class LanSyncConfirmationEvent extends LanSyncUiEvent {
  const LanSyncConfirmationEvent({
    required this.peerId,
    required this.peerName,
  });

  final String peerId;

  /// 对方的显示名（备注名优先）。
  final String peerName;
}

/// 以哪边为准：[items] 里的内容两边都改过、且无法自动判断。
final class LanSyncChooseSideEvent extends LanSyncConfirmationEvent {
  const LanSyncChooseSideEvent({
    required super.peerId,
    required super.peerName,
    required this.items,
    required this.respond,
  });

  /// 按数据种类的条数（日记为篇数）。
  final LanSyncItemCounts items;

  /// 用户的选择；null 为“取消”（这次同步放弃，什么都不写入）。
  final Future<void> Function(LanSyncSideChoice? choice) respond;
}

/// 删除保护：这次同步会在 [onSide] 那台设备上彻底删除 [deleteCount] 篇日记
/// （它们已在另一台的回收站里清空）。
final class LanSyncDeletionGuardEvent extends LanSyncConfirmationEvent {
  const LanSyncDeletionGuardEvent({
    required super.peerId,
    required super.peerName,
    required this.deleteCount,
    required this.onSide,
    required this.respond,
  });

  final int deleteCount;
  final LanSyncSide onSide;

  /// 用户的选择；null 为“取消”（这次同步放弃，什么都不写入）。
  final Future<void> Function(LanSyncDeletionChoice? choice) respond;
}

/// 一次手动同步结束（成功或失败）：界面弹出完成面板。
final class LanSyncSessionFinishedEvent extends LanSyncUiEvent {
  const LanSyncSessionFinishedEvent({
    required this.peerId,
    required this.summary,
  });

  /// 对方 id：失败面板的“重试”经 `syncNow(peerId)`。
  final String peerId;
  final LanSyncSessionSummary summary;
}

/// 前台自动同步写入了变化（没有变化时不发）。
final class LanSyncAutoSyncAppliedEvent extends LanSyncUiEvent {
  const LanSyncAutoSyncAppliedEvent({
    required this.peerId,
    required this.peerName,
    required this.diaries,
  });

  final String peerId;
  final String peerName;

  /// 本机收到（新增、更新或删除）的日记篇数。
  final int diaries;
}

/// 前台自动同步遇到需要用户确认的情况，已暂停等待。
final class LanSyncAutoSyncNeedsAttentionEvent extends LanSyncUiEvent {
  const LanSyncAutoSyncNeedsAttentionEvent({
    required this.peerId,
    required this.peerName,
  });

  final String peerId;
  final String peerName;
}
