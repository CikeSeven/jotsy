import 'package:flutter/material.dart';

import '../../models/diary_preview_style/diary_preview_style.dart';
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

/// 信息栏胶囊。
///
/// - 标签：[DiaryCardTagStyle.chip] 为染标签色的“# 名称”胶囊（改版前的样子），
///   plain 为标签色的“#名称”文字，dot 为标签色圆点 + 名称；
/// - 心情与精力：[plain] 为 false 时是中性底色胶囊（改版前的样子），true 时
///   只留文字（精力保留电池图标）。
///
/// 文字最宽 260，放不下时（窄屏、信息卡里）按可用宽度省略。
class DiaryPreviewChip extends StatelessWidget {
  const DiaryPreviewChip({
    super.key,
    required this.item,
    this.tagStyle = DiaryCardTagStyle.chip,
    this.plain = false,
  });

  final DiaryPreviewChipItem item;
  final DiaryCardTagStyle tagStyle;
  final bool plain;

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
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 12.5,
    );
    Widget label(String text, Color color) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: labelStyle?.copyWith(color: color),
      ),
    );

    if (tagColorValue != null) {
      final tagColor = Color(tagColorValue);
      return switch (tagStyle) {
        DiaryCardTagStyle.plain => label('#${item.label}', tagColor),
        DiaryCardTagStyle.dot => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: tagColor,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 7),
            ),
            const SizedBox(width: 5),
            Flexible(child: label(item.label, colorScheme.onSurface)),
          ],
        ),
        DiaryCardTagStyle.chip => Container(
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
              Flexible(child: label(item.label, colorScheme.onSurface)),
            ],
          ),
        ),
      };
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (energyLevel != null) ...[
          EnergyBatteryIndicator(value: energyLevel, iconSize: 14),
          const SizedBox(width: 6),
        ],
        Flexible(child: label(item.label, colorScheme.onSurfaceVariant)),
      ],
    );
    if (plain) {
      return content;
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
      child: content,
    );
  }
}
