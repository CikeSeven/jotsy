// 同步页顶部的英雄卡（本机，DESIGN.md §5.27）。
//
// 三种形态：
// - 竖排（卡片宽 < 600）：上方 184 高雷达区，下方居中的名称、平台、胶囊、
//   （首次使用时）“正在寻找附近的 Jotsy…”与操作按钮；
// - 横排（卡片宽 ≥ 600）：左侧 184 × 184 雷达区，右侧同样内容左对齐；
// - 收起（[collapsed]，有设备正在同步）：一行图标块 + 名称地址 + 状态胶囊。
// 收起 / 展开之间高度经 AnimatedSize（`medium`）补间、内容交叉淡入；宽度一律
// 按卡片实际可用宽度（LayoutBuilder）判断。

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../models/lan_sync_view_state.dart';
import '../widgets/lan_sync_labels.dart';
import '../widgets/lan_sync_radar.dart';
import '../widgets/lan_sync_status_chips.dart';
import 'lan_sync_hero_parts.dart';

class LanSyncHeroCard extends StatelessWidget {
  const LanSyncHeroCard({
    super.key,
    required this.local,
    required this.collapsed,
    required this.searchingFirstUse,
    required this.animateRadar,
    required this.onRename,
    required this.onCopyAddress,
    required this.onToggleDiscoverable,
    required this.onShowQr,
    required this.onManualAddress,
    this.onScanQr,
  });

  /// 横排的最小卡片宽度。
  static const double horizontalBreakpoint = 600;

  final LanSyncLocalDeviceView local;

  /// 是否有设备正在同步（收成一行）。
  final bool collapsed;

  /// 首次使用（没有已配对设备）且正在寻找：显示“正在寻找附近的 Jotsy…”。
  final bool searchingFirstUse;

  /// 雷达是否播放（可被发现且页面可见）。
  final bool animateRadar;
  final VoidCallback onRename;
  final VoidCallback onCopyAddress;
  final VoidCallback onToggleDiscoverable;
  final VoidCallback onShowQr;
  final VoidCallback onManualAddress;

  /// 扫码连接；null 时不显示扫码按钮（不能扫码的平台），见 [LanSyncHeroActions]。
  final VoidCallback? onScanQr;

  @override
  Widget build(BuildContext context) {
    final Widget content = collapsed
        ? LanSyncHeroCollapsedRow(
            key: const ValueKey<String>('lanSyncHeroCollapsed'),
            local: local,
            onToggleDiscoverable: onToggleDiscoverable,
          )
        : LayoutBuilder(
            key: const ValueKey<String>('lanSyncHeroExpanded'),
            builder: (BuildContext context, BoxConstraints constraints) {
              return constraints.maxWidth >= horizontalBreakpoint
                  ? _buildHorizontal(context)
                  : _buildVertical(context);
            },
          );
    return AppCardSurface(
      child: AnimatedSize(
        duration: ExpressiveMotion.durationNonZero(
          context,
          ExpressiveMotion.medium,
        ),
        curve: ExpressiveMotion.effects,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[...previous, ?current],
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _radar() =>
      LanSyncRadar(platform: local.platform, animate: animateRadar);

  /// 名称、平台、胶囊、寻找提示与按钮；[center] 为竖排居中，否则左对齐。
  List<Widget> _details(BuildContext context, {required bool center}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final align = center ? TextAlign.center : TextAlign.start;
    return <Widget>[
      LanSyncHeroName(
        name: lanSyncLocalName(l10n, local.name),
        onRename: onRename,
        center: center,
      ),
      Text(
        l10n.lanSyncLocalPlatform(lanSyncPlatformLabel(l10n, local.platform)),
        textAlign: align,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 13,
          color: colors.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: center ? WrapAlignment.center : WrapAlignment.start,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          LanSyncAddressChip(
            address: local.primaryAddress,
            onCopy: onCopyAddress,
          ),
          LanSyncDiscoverableChip(
            discoverable: local.discoverable,
            onToggle: onToggleDiscoverable,
          ),
        ],
      ),
      if (searchingFirstUse) ...<Widget>[
        const SizedBox(height: 12),
        Text(
          l10n.lanSyncSearchingNearbyJotsy,
          textAlign: align,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.primary,
          ),
        ),
      ],
      const SizedBox(height: 16),
      LanSyncHeroActions(
        onShowQr: onShowQr,
        onManualAddress: onManualAddress,
        onScanQr: onScanQr,
      ),
    ];
  }

  Widget _buildVertical(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _radar(),
          for (final child in _details(context, center: true))
            child is LanSyncHeroName ? Center(child: child) : child,
        ],
      ),
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 24, 12),
      child: Row(
        children: <Widget>[
          SizedBox(width: LanSyncRadar.extent, child: _radar()),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: _details(context, center: false),
            ),
          ),
        ],
      ),
    );
  }
}
