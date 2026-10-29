// 设备详情页的英雄卡（DESIGN.md §5.27“设备详情页”）：88dp 九瓣饼干形设备
// 图标、名称 24 / w800、在线 / 离线与平台胶囊、三格信息（上次同步 / 配对于 /
// 地址），底部整宽“立即同步”（52 高；离线时不可点并显示“设备不在线”）。
//
// 正在同步时按钮位置换成与同步页同一个会话面板，下面一枚灰色文本“取消”
// （同步页设备行的“取消”在这里没有行可挂）；两种内容交叉淡入，卡片高度
// 以 `medium` 补间。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../models/lan_sync_platform.dart';
import '../models/lan_sync_view_state.dart';
import '../widgets/lan_sync_device_glyph.dart';
import '../widgets/lan_sync_labels.dart';
import '../widgets/lan_sync_session_panel.dart';
import '../widgets/lan_sync_status_chips.dart';
import '../widgets/lan_sync_well_color.dart';

class LanSyncDeviceHero extends StatelessWidget {
  const LanSyncDeviceHero({
    super.key,
    required this.peer,
    required this.localPlatform,
    required this.now,
    required this.onSyncNow,
    required this.onCancel,
  });

  final LanSyncPeerView peer;
  final LanSyncPlatform localPlatform;

  /// 换算“X 前”的当前时间。
  final DateTime now;
  final VoidCallback onSyncNow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final lastSync = peer.lastSyncAt;
    final session = peer.session;
    final Widget action;
    if (session != null) {
      action = Column(
        key: const ValueKey<String>('lanSyncDeviceSession'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LanSyncSessionPanel(
            session: session,
            localPlatform: localPlatform,
            peerPlatform: peer.platform,
            peerName: peer.displayName,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
              ),
              onPressed: onCancel,
              child: Text(l10n.commonCancel),
            ),
          ),
        ],
      );
    } else {
      action = FilledButton(
        key: const ValueKey<String>('lanSyncDeviceSyncButton'),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
        onPressed: peer.online ? onSyncNow : null,
        child: Text(
          peer.online ? l10n.lanSyncPairSyncNow : l10n.lanSyncDeviceOffline,
        ),
      );
    }
    return AppCardSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(child: LanSyncDeviceGlyph(platform: peer.platform)),
            const SizedBox(height: 14),
            Text(
              peer.displayName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                LanSyncOnlineChip(online: peer.online),
                LanSyncChip(
                  background: lanSyncNeutralChipFill(context),
                  foreground: colors.onSurface,
                  label: lanSyncPlatformLabel(l10n, peer.platform),
                ),
              ],
            ),
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _InfoCell(
                      label: l10n.lanSyncInfoLastSync,
                      value: lastSync == null
                          ? l10n.lanSyncInfoNever
                          : lanSyncRelativeTime(l10n, lastSync, now),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoCell(
                      label: l10n.lanSyncInfoPairedAt,
                      value: DateFormat.yMMMd(
                        l10n.localeName,
                      ).format(peer.pairedAt.toLocal()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoCell(
                      label: l10n.lanSyncInfoAddress,
                      value: peer.address ?? l10n.lanSyncInfoNoAddress,
                      tabular: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSize(
              duration: ExpressiveMotion.durationNonZero(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.effects,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.medium,
                ),
                switchInCurve: ExpressiveMotion.effects,
                switchOutCurve: ExpressiveMotion.exit,
                layoutBuilder: (Widget? current, List<Widget> previous) =>
                    // passthrough：按钮与面板都要占满整宽（Stack 默认放松约束）。
                    Stack(
                      alignment: Alignment.topCenter,
                      fit: StackFit.passthrough,
                      children: <Widget>[...previous, ?current],
                    ),
                child: action,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一格信息：凹槽底（[lanSyncWellColor]）16 圆角，12 灰字标签 + 14 / w600 值。
/// 值放不下时整体缩小而不是省略（地址、日期截掉一半就没用了）。
class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.label,
    required this.value,
    this.tabular = false,
  });

  final String label;
  final String value;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: lanSyncWellColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
                fontFeatures: tabular
                    ? const <FontFeature>[FontFeature.tabularFigures()]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
