// 局域网同步界面的文案换算（平台名、相对时间、会话阶段、失败原因、设备图标、
// 按数据种类的计数）。
// 纯函数，同步页、设备详情页与设置入口共用，说法一致。

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/lan_sync_item_counts.dart';
import '../models/lan_sync_platform.dart';
import '../models/lan_sync_session_view.dart';

/// 平台名（“本机 · Android”、附近设备的“Linux · 地址”）。
String lanSyncPlatformLabel(AppLocalizations l10n, LanSyncPlatform platform) {
  return switch (platform) {
    LanSyncPlatform.android => l10n.lanSyncPlatformAndroid,
    LanSyncPlatform.ios => l10n.lanSyncPlatformIos,
    LanSyncPlatform.linux => l10n.lanSyncPlatformLinux,
    LanSyncPlatform.windows => l10n.lanSyncPlatformWindows,
    LanSyncPlatform.macos => l10n.lanSyncPlatformMacos,
    LanSyncPlatform.unknown => l10n.lanSyncPlatformUnknown,
  };
}

/// 设备图标：手机为 `mobileScreen`，其余（含认不出的平台）为 `laptop`。
FaIconData lanSyncPlatformIcon(LanSyncPlatform platform) {
  return platform.isMobile
      ? FontAwesomeIcons.mobileScreen
      : FontAwesomeIcons.laptop;
}

/// 本机设备名：还没取到名字时显示默认名。
String lanSyncLocalName(AppLocalizations l10n, String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? l10n.lanSyncDefaultDeviceName : trimmed;
}

/// “刚刚 / N 分钟前 / N 小时前 / N 天前”，复用全应用的相对时间文案。
///
/// [at] 晚于 [now]（两台设备时钟不一致时可能出现）按“刚刚”处理。
String lanSyncRelativeTime(AppLocalizations l10n, DateTime at, DateTime now) {
  final elapsed = now.difference(at);
  if (elapsed.inMinutes < 1) return l10n.timeJustNow;
  if (elapsed.inHours < 1) return l10n.timeMinutesAgo(elapsed.inMinutes);
  if (elapsed.inDays < 1) return l10n.timeHoursAgo(elapsed.inHours);
  return l10n.timeDaysAgo(elapsed.inDays);
}

/// “X 前已同步”；从没同步过为“还没有同步过”。
String lanSyncLastSyncLabel(
  AppLocalizations l10n,
  DateTime? lastSyncAt,
  DateTime now,
) {
  if (lastSyncAt == null) return l10n.lanSyncNeverSynced;
  return l10n.lanSyncSyncedAgo(lanSyncRelativeTime(l10n, lastSyncAt, now));
}

/// 数据种类的名称（“以哪边为准”的明细、完成摘要的“其他变化”）。
String lanSyncItemKindLabel(AppLocalizations l10n, LanSyncItemKind kind) {
  return switch (kind) {
    LanSyncItemKind.diaries => l10n.lanSyncItemDiaries,
    LanSyncItemKind.tags => l10n.lanSyncItemTags,
    LanSyncItemKind.notebooks => l10n.lanSyncItemNotebooks,
    LanSyncItemKind.comments => l10n.lanSyncItemComments,
    LanSyncItemKind.templates => l10n.lanSyncItemTemplates,
    LanSyncItemKind.anniversaries => l10n.lanSyncItemAnniversaries,
    LanSyncItemKind.dayMoods => l10n.lanSyncItemDayMoods,
    LanSyncItemKind.settings => l10n.lanSyncItemSettings,
  };
}

/// “日记 2 · 标签 1”：按显示顺序列出非零的种类。
String lanSyncItemCountsText(AppLocalizations l10n, LanSyncItemCounts counts) {
  return [
    for (final entry in counts.entries)
      l10n.lanSyncItemCount(lanSyncItemKindLabel(l10n, entry.key), entry.value),
  ].join(' · ');
}

/// 用时（整秒，向上取整）：不足一秒按 1 秒写，不出现“用时 0 秒”。
int lanSyncDurationSeconds(Duration duration) {
  final value = (duration.inMilliseconds / 1000).ceil();
  return value < 1 ? 1 : value;
}

/// 会话阶段文字（设备行副标题、会话面板）。
String lanSyncStageLabel(AppLocalizations l10n, LanSyncSessionStage stage) {
  return switch (stage) {
    LanSyncSessionStage.connecting => l10n.lanSyncStageConnecting,
    LanSyncSessionStage.comparing => l10n.lanSyncStageComparing,
    LanSyncSessionStage.transferring => l10n.lanSyncStageTransferring,
    LanSyncSessionStage.merging => l10n.lanSyncStageMerging,
  };
}

/// 配对失败的原因与下一步（配对面板的失败态）。
String lanSyncPairingFailureText(
  AppLocalizations l10n,
  LanSyncFailureReason reason,
) {
  return switch (reason) {
    LanSyncFailureReason.unreachable => l10n.lanSyncPairFailUnreachable,
    LanSyncFailureReason.connectionLost => l10n.lanSyncPairFailConnectionLost,
    LanSyncFailureReason.timedOut => l10n.lanSyncPairFailTimedOut,
    LanSyncFailureReason.declined => l10n.lanSyncPairFailDeclined,
    LanSyncFailureReason.cancelled => l10n.lanSyncPairFailCancelled,
    LanSyncFailureReason.incompatibleVersion =>
      l10n.lanSyncPairFailIncompatible,
    LanSyncFailureReason.untrusted => l10n.lanSyncPairFailUntrusted,
    LanSyncFailureReason.ticketExpired => l10n.lanSyncPairFailTicketExpired,
    LanSyncFailureReason.writeFailed => l10n.lanSyncPairFailWriteFailed,
    LanSyncFailureReason.busy => l10n.lanSyncPairFailBusy,
    // 下面三种只出现在同步会话里，配对不会走到；兜底按“没有完成”说明。
    LanSyncFailureReason.localEditing ||
    LanSyncFailureReason.deferred ||
    LanSyncFailureReason.needsConfirmation ||
    LanSyncFailureReason.unknown => l10n.lanSyncPairFailUnknown,
  };
}

/// 同步失败的原因与下一步（完成摘要面板的失败态）。
String lanSyncSyncFailureText(
  AppLocalizations l10n,
  LanSyncFailureReason reason,
) {
  return switch (reason) {
    LanSyncFailureReason.unreachable => l10n.lanSyncSyncFailUnreachable,
    LanSyncFailureReason.connectionLost => l10n.lanSyncSyncFailConnectionLost,
    LanSyncFailureReason.timedOut => l10n.lanSyncSyncFailTimedOut,
    LanSyncFailureReason.declined => l10n.lanSyncSyncFailDeclined,
    LanSyncFailureReason.cancelled => l10n.lanSyncSyncFailCancelled,
    LanSyncFailureReason.incompatibleVersion =>
      l10n.lanSyncSyncFailIncompatible,
    LanSyncFailureReason.untrusted => l10n.lanSyncSyncFailUntrusted,
    LanSyncFailureReason.ticketExpired => l10n.lanSyncSyncFailTicketExpired,
    LanSyncFailureReason.writeFailed => l10n.lanSyncSyncFailWriteFailed,
    LanSyncFailureReason.busy => l10n.lanSyncSyncFailBusy,
    LanSyncFailureReason.localEditing => l10n.lanSyncSyncFailLocalEditing,
    LanSyncFailureReason.deferred => l10n.lanSyncSyncFailDeferred,
    // 完成摘要只给手动同步，正常走不到；兜底说明怎么继续。
    LanSyncFailureReason.needsConfirmation =>
      l10n.lanSyncSyncFailNeedsConfirmation,
    LanSyncFailureReason.unknown => l10n.lanSyncSyncFailUnknown,
  };
}

/// 同步失败的短原因（设备详情页同步记录里的一行 `error` 色文字）。
String lanSyncSyncReasonText(
  AppLocalizations l10n,
  LanSyncFailureReason reason,
) {
  return switch (reason) {
    LanSyncFailureReason.unreachable => l10n.lanSyncSyncReasonUnreachable,
    LanSyncFailureReason.connectionLost => l10n.lanSyncSyncReasonConnectionLost,
    LanSyncFailureReason.timedOut => l10n.lanSyncSyncReasonTimedOut,
    LanSyncFailureReason.declined => l10n.lanSyncSyncReasonDeclined,
    LanSyncFailureReason.cancelled => l10n.lanSyncSyncReasonCancelled,
    LanSyncFailureReason.incompatibleVersion =>
      l10n.lanSyncSyncReasonIncompatible,
    LanSyncFailureReason.untrusted => l10n.lanSyncSyncReasonUntrusted,
    LanSyncFailureReason.ticketExpired => l10n.lanSyncSyncReasonTicketExpired,
    LanSyncFailureReason.writeFailed => l10n.lanSyncSyncReasonWriteFailed,
    LanSyncFailureReason.busy => l10n.lanSyncSyncReasonBusy,
    LanSyncFailureReason.localEditing => l10n.lanSyncSyncReasonLocalEditing,
    LanSyncFailureReason.deferred => l10n.lanSyncSyncReasonDeferred,
    LanSyncFailureReason.needsConfirmation =>
      l10n.lanSyncSyncReasonNeedsConfirmation,
    LanSyncFailureReason.unknown => l10n.lanSyncSyncReasonUnknown,
  };
}
