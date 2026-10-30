// 英雄卡的组成部分：名称行、胶囊行、操作按钮与同步中收起的一行。
// 只负责画与转发点按，状态与动作由 [LanSyncHeroCard] 的调用方给出。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_glass_field.dart';
import '../models/lan_sync_view_state.dart';
import '../widgets/lan_sync_labels.dart';
import '../widgets/lan_sync_status_chips.dart';

/// 设备名（22 / w800）+ 16dp 铅笔按钮。
class LanSyncHeroName extends StatelessWidget {
  const LanSyncHeroName({
    super.key,
    required this.name,
    required this.onRename,
    required this.center,
  });

  final String name;
  final VoidCallback onRename;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
      children: <Widget>[
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.lanSyncRenameTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onRename,
          icon: FaIcon(
            FontAwesomeIcons.pen,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 英雄卡底部的操作按钮（48 高、全圆角、等宽）。
///
/// 能扫码的平台（[onScanQr] 非空）为“扫码连接 + 显示二维码”两枚色调按钮；
/// 否则为色调“显示二维码”+ 文本按钮“手动输入地址”（DESIGN §5.28 桌面）。
class LanSyncHeroActions extends StatelessWidget {
  const LanSyncHeroActions({
    super.key,
    required this.onShowQr,
    required this.onManualAddress,
    this.onScanQr,
  });

  final VoidCallback onShowQr;
  final VoidCallback onManualAddress;
  final VoidCallback? onScanQr;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final base = FilledButton.styleFrom(minimumSize: const Size(0, 48));
    final tonal = AppGlassField.tonalButtonStyle(context)?.merge(base) ?? base;
    final onScanQr = this.onScanQr;
    return Row(
      children: <Widget>[
        if (onScanQr != null) ...<Widget>[
          Expanded(
            child: FilledButton.tonal(
              style: tonal,
              onPressed: onScanQr,
              child: Text(l10n.lanSyncScanQr),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: FilledButton.tonal(
            style: tonal,
            onPressed: onShowQr,
            child: Text(l10n.lanSyncShowQr),
          ),
        ),
        if (onScanQr == null) ...<Widget>[
          const SizedBox(width: 12),
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: onManualAddress,
              child: Text(l10n.lanSyncManualAddress),
            ),
          ),
        ],
      ],
    );
  }
}

/// 正在与某台设备同步时英雄卡收成的一行：56dp 20 圆角 `primaryContainer`
/// 图标块 + 名称（18 / w800）与地址 + 发现状态胶囊。
class LanSyncHeroCollapsedRow extends StatelessWidget {
  const LanSyncHeroCollapsedRow({
    super.key,
    required this.local,
    required this.onToggleDiscoverable,
  });

  final LanSyncLocalDeviceView local;
  final VoidCallback onToggleDiscoverable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: FaIcon(
                lanSyncPlatformIcon(local.platform),
                size: 24,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  lanSyncLocalName(l10n, local.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  local.displayAddress ?? l10n.lanSyncNoNetwork,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          LanSyncDiscoverableChip(
            discoverable: local.discoverable,
            onToggle: onToggleDiscoverable,
          ),
        ],
      ),
    );
  }
}
