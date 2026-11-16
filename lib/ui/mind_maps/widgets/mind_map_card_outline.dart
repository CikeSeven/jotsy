import 'package:flutter/material.dart';

import '../../../core/database/mind_map/mind_map_text.dart';
import '../../../l10n/app_localizations.dart';

/// 日记卡片上导图日记的摘要：大纲。中心主题已经是卡片标题，大纲从一级主题
/// 排起，行的挑选口径见 [mindMapCardOutline]。
///
/// 和文字日记的摘要一样直接排在卡片上，不加底色与描边：每行一个主题（一行
/// 截断），按层级缩进一个项目符号的宽度，下一级的符号正好对齐上一级的文字；
/// 一级主题是强调色实心圆点、文字稍粗（w500），二级是摘要色空心小圆。
/// 颜色都取卡片样式算好的值（[textStyle] 为带颜色的摘要文字样式，
/// [accentColor] 为卡片的强调色），自定义卡片颜色、反色与玻璃下都与卡片
/// 协调。没写字的主题显示淡色的占位文字（同画布）。[centered] 时整块大纲
/// 居中，行仍靠起始边对齐，缩进不乱。
class MindMapCardOutline extends StatelessWidget {
  const MindMapCardOutline({
    super.key,
    required this.lines,
    required this.textStyle,
    required this.accentColor,
    this.centered = false,
  });

  /// 卡片上大纲的行数：一行只放得下一个主题，比文字摘要多几行，列表默认
  /// 6 行（摘要行数 + 4），瀑布流（[compact]）列窄、默认 5 行（摘要行数
  /// + 2）；随卡片样式的摘要行数增减，夹在 3–12。
  static int lineBudget(int previewMaxLines, {required bool compact}) =>
      (previewMaxLines + (compact ? 2 : 4)).clamp(3, 12);

  final List<MindMapOutlineLine> lines;
  final TextStyle? textStyle;
  final Color accentColor;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(textStyle);
    final fontSize = base.fontSize ?? 14;
    final color = base.color ?? accentColor;
    final placeholder = context.l10n.mindMapNodePlaceholder;
    // 符号格的宽度就是每级的缩进：下一级的符号落在上一级文字的起点。
    final step = fontSize * 1.1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final line in lines)
          Padding(
            padding: EdgeInsetsDirectional.only(start: step * (line.depth - 1)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: step,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _OutlineBullet(
                      topLevel: line.depth == 1,
                      size: fontSize,
                      accent: accentColor,
                      color: color,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    line.text.isEmpty ? placeholder : line.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: base.copyWith(
                      fontWeight: line.depth == 1 ? FontWeight.w500 : null,
                      color: line.text.isEmpty
                          ? color.withValues(alpha: color.a * 0.55)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 大纲行首的项目符号：一级为强调色实心圆点，更深为文字色空心小圆。
class _OutlineBullet extends StatelessWidget {
  const _OutlineBullet({
    required this.topLevel,
    required this.size,
    required this.accent,
    required this.color,
  });

  final bool topLevel;

  /// 所在行的字号，符号按它缩放。
  final double size;
  final Color accent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final diameter = size * (topLevel ? 0.4 : 0.34);
    return SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: topLevel
            ? BoxDecoration(color: accent, shape: BoxShape.circle)
            : BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: color.a * 0.7),
                  width: (size * 0.09).clamp(1.0, 2.0),
                ),
              ),
      ),
    );
  }
}
