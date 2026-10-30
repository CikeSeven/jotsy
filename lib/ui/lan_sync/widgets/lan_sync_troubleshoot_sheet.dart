import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../models/lan_sync_platform.dart';

/// 排障面板里用户选的下一步。
enum LanSyncTroubleshootAction { manualAddress }

/// “找不到设备？”排障面板（只负责展示与挑选，DESIGN.md §5.28）。
///
/// 逐条说明：同一个 Wi-Fi、VPN / 代理、另一台也打开同步页、Windows / Linux
/// 防火墙、仍不行时手动输入地址或扫码。两种防火墙都列出（另一台可能是
/// 电脑），Linux 一条写本机实际的同步端口 [syncPort]（默认端口被占用时服务端
/// 会退到别的端口）。本机发现端口被占用（[discoveryListening] 为 false）时
/// 顶部另有说明块。返回用户点的操作，直接关闭为 null。
Future<LanSyncTroubleshootAction?> showLanSyncTroubleshootSheet(
  BuildContext context, {
  required bool discoveryListening,
  required int syncPort,
}) {
  return showAppModalBottomSheet<LanSyncTroubleshootAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => _TroubleshootSheet(
      discoveryListening: discoveryListening,
      syncPort: syncPort,
    ),
  );
}

class _TroubleshootSheet extends StatelessWidget {
  const _TroubleshootSheet({
    required this.discoveryListening,
    required this.syncPort,
  });

  final bool discoveryListening;
  final int syncPort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final manualStyle = AppGlassField.tonalButtonStyle(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: <Widget>[
        Text(
          l10n.lanSyncTroubleshoot,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        if (!discoveryListening) ...<Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: FaIcon(
                      FontAwesomeIcons.circleInfo,
                      size: 16,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Text(
                      l10n.lanSyncPortBusyNotice(LanSyncPorts.discovery),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSecondaryContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
        ],
        _Tip(
          icon: FontAwesomeIcons.wifi,
          title: l10n.lanSyncTipWifiTitle,
          body: l10n.lanSyncTipWifiBody,
        ),
        _Tip(
          icon: FontAwesomeIcons.shieldHalved,
          title: l10n.lanSyncTipVpnTitle,
          body: l10n.lanSyncTipVpnBody,
        ),
        _Tip(
          icon: FontAwesomeIcons.towerBroadcast,
          title: l10n.lanSyncTipOpenPageTitle,
          body: l10n.lanSyncTipOpenPageBody,
        ),
        _Tip(
          icon: FontAwesomeIcons.windows,
          title: l10n.lanSyncTipWindowsTitle,
          body: l10n.lanSyncTipWindowsBody,
        ),
        _Tip(
          icon: FontAwesomeIcons.linux,
          title: l10n.lanSyncTipLinuxTitle,
          body: l10n.lanSyncTipLinuxBody(LanSyncPorts.discovery, syncPort),
        ),
        _Tip(
          icon: FontAwesomeIcons.keyboard,
          title: l10n.lanSyncTipFallbackTitle,
          body: l10n.lanSyncTipFallbackBody,
          action: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonal(
              style: manualStyle,
              onPressed: () => Navigator.of(
                context,
              ).pop(LanSyncTroubleshootAction.manualAddress),
              child: Text(l10n.lanSyncManualAddress),
            ),
          ),
        ),
      ],
    );
  }
}

/// 一条排障说明：主色图标 + 标题 + 说明，可带一个操作。
class _Tip extends StatelessWidget {
  const _Tip({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final FaIconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox.square(
            dimension: 24,
            child: Center(child: FaIcon(icon, size: 16, color: colors.primary)),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.s),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
