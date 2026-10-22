import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../widgets/expressive_state_blend.dart';

/// 列表、待办与引用的行首标记。
///
/// 为什么不用编辑器自带的标记：上游的无序列表用 `●◯□` 字符（正文字体缺
/// `◯`，二级圆点画不出来）、引用竖条写死亮青色 `#00BCF0`、待办图标交给
/// IconButton 时会被撑成 48dp 触控尺寸，复选框掉到首行下方并把行距撑开。
/// 这里的标记一律自己绘制：标记列宽固定（[kDiaryMarkerWidth]），高度等于
/// 首行行高（[diaryMarkerLineExtent]），标记在首行内垂直居中，与文字一起
/// 随正文字号、行距和系统字体缩放变化；颜色只取主题语义色。

/// 行首标记列宽：无序、有序与待办共用，三种列表的正文起点对齐。
const double kDiaryMarkerWidth = 28;

/// 首行行高：正文字号 × 行距 × 系统字体缩放。
double diaryMarkerLineExtent(
  BuildContext context, {
  required double fontSize,
  required double lineHeight,
}) => MediaQuery.textScalerOf(context).scale(fontSize) * lineHeight;

/// 固定宽、首行高的标记格。
class _MarkerCell extends StatelessWidget {
  const _MarkerCell({required this.lineExtent, required this.child});

  final double lineExtent;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: kDiaryMarkerWidth,
    height: lineExtent,
    child: Align(alignment: AlignmentDirectional.centerStart, child: child),
  );
}

/// 无序列表圆点：按所在无序列表的嵌套层级轮换实心圆、空心圆、小方块。
class DiaryBulletMarker extends StatelessWidget {
  const DiaryBulletMarker({
    super.key,
    required this.node,
    required this.lineExtent,
  });

  final af.Node node;
  final double lineExtent;

  int get _level {
    var level = 0;
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      if (parent.type == af.BulletedListBlockKeys.type) level++;
    }
    return level;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final Widget mark = switch (_level % 3) {
      0 => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      1 => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.4),
        ),
      ),
      _ => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    };
    return _MarkerCell(
      lineExtent: lineExtent,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8),
        child: mark,
      ),
    );
  }
}

/// 有序列表序号：层级轮换 1. / a. / i.，连续的同级有序列表接着编号（首项
/// 可带 `number` 起始号）。数字等宽，宽度不够时向右延伸、不折行。
class DiaryNumberMarker extends StatelessWidget {
  const DiaryNumberMarker({
    super.key,
    required this.node,
    required this.lineExtent,
    required this.textStyle,
  });

  final af.Node node;
  final double lineExtent;

  /// 正文样式（字体、字号、行距），颜色与字重在这里覆盖。
  final TextStyle textStyle;

  int get _level {
    var level = 0;
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      if (parent.type == af.NumberedListBlockKeys.type) level++;
    }
    return level;
  }

  int get _index {
    int? start(af.Node item) {
      final number = item.attributes[af.NumberedListBlockKeys.number];
      return number is num ? number.toInt() : null;
    }

    var count = 1;
    var first = node;
    for (
      var previous = node.previous;
      previous != null && previous.type == af.NumberedListBlockKeys.type;
      previous = previous.previous
    ) {
      count++;
      first = previous;
    }
    return (start(first) ?? 1) + count - 1;
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    final label = switch (_level % 3) {
      1 => _latin(index),
      2 => _roman(index),
      _ => '$index',
    };
    return SizedBox(
      height: lineExtent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: kDiaryMarkerWidth),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, end: 6),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: Text(
              '$label.',
              maxLines: 1,
              softWrap: false,
              textScaler: TextScaler.noScaling,
              style: textStyle.copyWith(
                fontSize: MediaQuery.textScalerOf(
                  context,
                ).scale(textStyle.fontSize ?? 16),
                height: 1,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _latin(int number) {
    var value = number;
    final buffer = StringBuffer();
    while (value > 0) {
      final remainder = (value - 1) % 26;
      buffer.write(String.fromCharCode(remainder + 97));
      value = (value - 1) ~/ 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  static String _roman(int number) {
    if (number <= 0 || number >= 4000) return '$number';
    const values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const symbols = [
      'm',
      'cm',
      'd',
      'cd',
      'c',
      'xc',
      'l',
      'xl',
      'x',
      'ix',
      'v',
      'iv',
      'i',
    ];
    var value = number;
    final buffer = StringBuffer();
    for (var i = 0; i < values.length; i++) {
      while (value >= values[i]) {
        buffer.write(symbols[i]);
        value -= values[i];
      }
    }
    return buffer.toString();
  }
}

/// 待办复选框：18dp 圆角方块，未勾选为 `outline` 描边，勾选后以 `primary`
/// 填充并显示对勾，状态切换经 [ExpressiveStateBlend] 补间颜色。点按区域是
/// 整个标记格（28dp × 首行行高），而不只是方块本身。
class DiaryTodoCheckbox extends StatelessWidget {
  const DiaryTodoCheckbox({
    super.key,
    required this.checked,
    required this.lineExtent,
    required this.semanticLabel,
    this.onToggle,
  });

  final bool checked;
  final double lineExtent;
  final String semanticLabel;

  /// 为 null 时只读（阅读页未开启勾选保存）。
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      checked: checked,
      enabled: onToggle != null,
      label: semanticLabel,
      onTap: onToggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: _MarkerCell(
          lineExtent: lineExtent,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 2),
            child: ExpressiveStateBlend(
              active: checked,
              builder: (context, t, _) => Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: t),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Color.lerp(colors.outline, colors.primary, t)!,
                    width: 1.6,
                  ),
                ),
                child: Opacity(
                  opacity: t,
                  child: FaIcon(
                    FontAwesomeIcons.check,
                    size: 11,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 引用竖条：3dp 圆头竖线，`primary` 55% 透明度，贯穿整个引用块的高度。
class DiaryQuoteBar extends StatelessWidget {
  const DiaryQuoteBar({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 2, end: 12),
    child: Container(
      width: 3,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(1.5),
      ),
    ),
  );
}
