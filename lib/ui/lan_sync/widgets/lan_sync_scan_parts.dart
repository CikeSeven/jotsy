// 扫码页的小部件：半透明圆形按钮与相机不可用时的说明块。颜色取当前主题
// （扫码页整页为暗色主题），见 lan_sync_scan_view.dart。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import 'lan_sync_scan_view.dart';

/// 半透明圆形图标按钮（关闭 44dp、手电筒 60dp）；[selected] 时为主色底。
class LanSyncScanRoundButton extends StatelessWidget {
  const LanSyncScanRoundButton({
    super.key,
    required this.extent,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final double extent;
  final String tooltip;
  final FaIconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: extent,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        isSelected: selected,
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? colors.primary
              : colors.onSurface.withValues(alpha: 0.16),
          foregroundColor: selected ? colors.onPrimary : colors.onSurface,
          disabledBackgroundColor: colors.onSurface.withValues(alpha: 0.08),
          shape: const CircleBorder(),
        ),
        icon: FaIcon(icon, size: extent >= 60 ? 22 : 18),
      ),
    );
  }
}

/// 相机不可用：图标 + 标题 + 说明；权限被拒且能打开系统设置时带“去设置”。
class LanSyncScanFailureBody extends StatelessWidget {
  const LanSyncScanFailureBody({
    super.key,
    required this.failure,
    required this.onOpenSettings,
  });

  final LanSyncScanFailure failure;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final denied = failure == LanSyncScanFailure.permissionDenied;
    final onOpenSettings = denied ? this.onOpenSettings : null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 96, 32, 160),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FaIcon(
              FontAwesomeIcons.camera,
              size: 36,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 20),
            Text(
              denied
                  ? l10n.lanSyncScanDeniedTitle
                  : l10n.lanSyncScanUnavailableTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              denied
                  ? l10n.lanSyncScanDeniedBody
                  : l10n.lanSyncScanUnavailableBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
            if (onOpenSettings != null) ...<Widget>[
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: onOpenSettings,
                child: Text(l10n.lanSyncScanOpenSettings),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
