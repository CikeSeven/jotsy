import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../models/diary_card_style/diary_card_style_enums.dart';

/// 日记卡片内的标签展示区，仅负责展示，不处理标签交互。
///
/// 规则：
/// - 展示数量由调用方配置，默认展示前 2 个，传入 0 时隐藏整个区域；
/// - 超出部分使用 `+N` 汇总；
/// - 每个标签保持单行省略，标签集合则根据卡片可用宽度自动换行；
/// - [style] 决定单个标签的形态（彩色 `#` 微胶囊 / 纯文字 / 圆点），[scale]
///   缩放字号与内边距；默认值即改版前的外观。
class DiaryItemTagRow extends StatelessWidget {
  const DiaryItemTagRow({
    super.key,
    required this.tags,
    this.maxVisibleTags = 2,
    this.style = DiaryCardTagStyle.chip,
    this.scale = 1,
    this.alignment = WrapAlignment.start,
    this.textColor,
    this.overflowFill,
    this.overflowBorder,
  });

  final List<Tag> tags;
  final int maxVisibleTags;
  final DiaryCardTagStyle style;
  final double scale;
  final WrapAlignment alignment;

  /// 标签名颜色；默认 onSurfaceVariant。
  final Color? textColor;

  /// `+N` 汇总胶囊的底色与描边；卡片底色与主题相反时由调用方传入。
  final Color? overflowFill;
  final Color? overflowBorder;

  @override
  Widget build(BuildContext context) {
    final effectiveLimit = maxVisibleTags < 0
        ? 0
        : maxVisibleTags > tags.length
        ? tags.length
        : maxVisibleTags;
    if (tags.isEmpty || effectiveLimit == 0) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = textColor ?? colorScheme.onSurfaceVariant;
    final visibleTags = tags.take(effectiveLimit).toList(growable: false);
    final hiddenCount = tags.length - effectiveLimit;

    // 较高展示上限会让标签超过一行，瀑布流窄卡片尤其明显；按可用宽度换行
    // 可避免横向 RenderFlex 溢出，同时保留每个标签自身的单行省略行为。
    return Wrap(
      spacing: (style == DiaryCardTagStyle.chip ? 6 : 10) * scale,
      runSpacing: 4 * scale,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final tag in visibleTags)
          _DiaryTagText(
            label: tag.name,
            hashColor: Color(tag.color),
            textColor: labelColor,
            style: style,
            scale: scale,
          ),
        if (hiddenCount > 0)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 6 * scale,
              vertical: 2 * scale,
            ),
            decoration: BoxDecoration(
              color:
                  overflowFill ??
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    overflowBorder ??
                    colorScheme.outlineVariant.withValues(alpha: 0.25),
                width: 0.65,
              ),
            ),
            child: Text(
              '+$hiddenCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
                fontSize: 10.5 * scale,
              ),
            ),
          ),
      ],
    );
  }
}

/// 单个标签：彩色 `#` + 标签名。胶囊形态带柔和的标签色微底与细描边；
/// 纯文字形态只有彩色 `#`；圆点形态以标签色圆点代替 `#`。
class _DiaryTagText extends StatelessWidget {
  const _DiaryTagText({
    required this.label,
    required this.hashColor,
    required this.textColor,
    required this.style,
    required this.scale,
  });

  final String label;
  final Color hashColor;
  final Color textColor;
  final DiaryCardTagStyle style;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.labelSmall?.copyWith(
      color: textColor,
      fontWeight: FontWeight.w600,
      fontSize: 11 * scale,
    );
    if (style == DiaryCardTagStyle.dot) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6 * scale,
            height: 6 * scale,
            decoration: BoxDecoration(color: hashColor, shape: BoxShape.circle),
          ),
          SizedBox(width: 4 * scale),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ],
      );
    }
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '# ',
            style: textTheme.labelSmall?.copyWith(
              color: hashColor,
              fontWeight: FontWeight.w800,
              fontSize: 10.5 * scale,
            ),
          ),
          TextSpan(text: label, style: labelStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (style == DiaryCardTagStyle.plain) {
      return text;
    }
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: hashColor.withValues(alpha: isLight ? 0.08 : 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hashColor.withValues(alpha: isLight ? 0.22 : 0.32),
          width: 0.65,
        ),
      ),
      child: text,
    );
  }
}
