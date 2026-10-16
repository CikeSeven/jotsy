import 'package:flutter/material.dart';

import '../energy_battery_indicator.dart';

/// 预览页信息栏胶囊的种类。
enum DiaryPreviewChipKind { tag, mood, energy }

/// 一枚信息栏胶囊的内容。
@immutable
class DiaryPreviewChipItem {
  const DiaryPreviewChipItem({
    required this.kind,
    required this.label,
    this.energyLevel,
    this.tagColor,
  });

  final DiaryPreviewChipKind kind;
  final String label;

  /// 归一化后的精力值（仅精力胶囊）。
  final double? energyLevel;

  /// 标签色 ARGB（仅标签胶囊）。
  final int? tagColor;
}

/// 信息栏胶囊：标签为“# 名称”并染标签色；心情与精力为中性底色，精力前带
/// 电池图标。文字最宽 260，超出省略。
class DiaryPreviewChip extends StatelessWidget {
  const DiaryPreviewChip({super.key, required this.item});

  final DiaryPreviewChipItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final energyLevel = item.kind == DiaryPreviewChipKind.energy
        ? item.energyLevel
        : null;
    final tagColorValue = item.kind == DiaryPreviewChipKind.tag
        ? item.tagColor
        : null;

    if (tagColorValue != null) {
      final tagColor = Color(tagColorValue);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: tagColor.withValues(alpha: isLight ? 0.08 : 0.16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: tagColor.withValues(alpha: isLight ? 0.22 : 0.32),
            width: 0.75,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '#',
              style: TextStyle(
                color: tagColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: isLight ? 0.45 : 0.65,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: isLight ? 0.35 : 0.25,
          ),
          width: 0.75,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (energyLevel != null) ...[
            EnergyBatteryIndicator(value: energyLevel, iconSize: 14),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              item.label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
