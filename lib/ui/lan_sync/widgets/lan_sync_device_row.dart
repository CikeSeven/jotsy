import 'package:flutter/material.dart';

import '../../app_surface/widgets/app_glass_field.dart';
import 'lan_sync_device_tile.dart';

/// 设备卡片里的一行：图标块 + 标题 / 副标题 + 尾部控件（DESIGN.md §5.27）。
///
/// 内边距 14 × 16、图标与文字间距 14，与 `SettingsCardGroup` 的行同规格；
/// 分组卡片里行间分割线的起点为 [textStart]（文字起点）。
class LanSyncDeviceRow extends StatelessWidget {
  const LanSyncDeviceRow({
    super.key,
    required this.tile,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  /// 行间分割线的起点：左内边距 + 图标块 + 间距。
  static const double textStart = 16 + LanSyncDeviceTile.size + 14;

  final Widget tile;
  final String title;

  /// 副标题（13 灰字；在线、阶段、需要确认等着色片段由调用方给出）。
  final InlineSpan subtitle;
  final Widget? trailing;

  /// 点按整行；null 时整行不可点。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final trailing = this.trailing;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          tile,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing,
          ],
        ],
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// 设备行尾部的 40dp 小按钮（“同步”“查看”为色调，“配对”为填充）。
class LanSyncRowButton extends StatelessWidget {
  const LanSyncRowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  /// true 为填充按钮（附近设备的“配对”），否则为色调按钮。
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final base = FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (filled) {
      return FilledButton(
        style: base,
        onPressed: onPressed,
        child: Text(label),
      );
    }
    final style = AppGlassField.tonalButtonStyle(context)?.merge(base) ?? base;
    final icon = this.icon;
    if (icon == null) {
      return FilledButton.tonal(
        style: style,
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return FilledButton.tonalIcon(
      style: style,
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
    );
  }
}
