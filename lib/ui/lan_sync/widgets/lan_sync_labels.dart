// 局域网同步界面的文案换算（平台名、相对时间、会话阶段、设备图标）。
// 纯函数，同步页、设备详情页与设置入口共用，说法一致。

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

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
    LanSyncFailureReason.unknown => l10n.lanSyncPairFailUnknown,
  };
}
