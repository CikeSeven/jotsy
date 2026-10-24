import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../widgets/expressive_state_blend.dart';
import 'diary_block_marker_metrics.dart';
import 'diary_editor_styles.dart';

/// 列表、待办与引用的行首标记。
///
/// 为什么不用编辑器自带的标记：上游的无序列表用 `●◯□` 字符（正文字体缺
/// `◯`，二级圆点画不出来）、引用竖条写死亮青色 `#00BCF0`、待办图标交给
/// IconButton 时会被撑成 48dp 触控尺寸，复选框掉到首行下方并把行距撑开。
/// 这里的标记一律自己绘制，几何统一取自 [DiaryMarkerMetrics]
/// （`diary_block_marker_metrics.dart`）：标记格与文字
/// 首行等高，圆点与复选框的中心对齐首行字形的中心，序号与文字基线对齐；
/// 尺寸随正文字号与系统字体缩放等比变化；颜色只取主题语义色。

/// 固定宽、首行高的标记格：[size] 见方的标记距起始边 [start]，中心落在
/// 首行字形中心。字体上缘很浅时标记可能略超出格子顶部，照常绘制。
class _MarkerCell extends StatelessWidget {
  const _MarkerCell({
    required this.metrics,
    required this.size,
    required this.start,
    required this.child,
  });

  final DiaryMarkerMetrics metrics;
  final double size;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: metrics.width,
    height: metrics.lineExtent,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          start: start,
          top: metrics.glyphCenter - size / 2,
          width: size,
          height: size,
          child: child,
        ),
      ],
    ),
  );
}

/// 无序列表圆点：按所在无序列表的嵌套层级轮换实心圆、空心圆、小方块，
/// 三种标记的中心都在距起始边 11dp 处。
class DiaryBulletMarker extends StatelessWidget {
  const DiaryBulletMarker({
    super.key,
    required this.node,
    required this.metrics,
  });

  final af.Node node;
  final DiaryMarkerMetrics metrics;

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
    final level = _level % 3;
    final size = metrics.dp(level == 2 ? 5 : 6);
    final decoration = switch (level) {
      0 => BoxDecoration(color: color, shape: BoxShape.circle),
      1 => BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: metrics.dp(1.4)),
      ),
      _ => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(metrics.dp(1)),
      ),
    };
    return _MarkerCell(
      metrics: metrics,
      size: size,
      start: metrics.dp(11) - size / 2,
      child: DecoratedBox(decoration: decoration),
    );
  }
}

/// 有序列表序号：层级轮换 1. / a. / i.，连续的同级有序列表接着编号（首项
/// 可带 `number` 起始号）。数字等宽，宽度不够时向右延伸、不折行。序号与
/// 正文同样式、同缩放、同行高规则排版，放在格子顶部即与正文基线对齐。
class DiaryNumberMarker extends StatelessWidget {
  const DiaryNumberMarker({
    super.key,
    required this.node,
    required this.metrics,
    required this.textStyle,
  });

  final af.Node node;
  final DiaryMarkerMetrics metrics;

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
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: metrics.width),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: metrics.dp(2),
          end: metrics.dp(6),
        ),
        child: Text(
          '$label.',
          maxLines: 1,
          softWrap: false,
          textScaler: metrics.scaler,
          textHeightBehavior: kDiaryTextHeightBehavior,
          style: textStyle.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
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
/// 整个标记格（列宽 × 首行高度），而不只是方块本身。
class DiaryTodoCheckbox extends StatelessWidget {
  const DiaryTodoCheckbox({
    super.key,
    required this.checked,
    required this.metrics,
    required this.semanticLabel,
    this.onToggle,
  });

  final bool checked;
  final DiaryMarkerMetrics metrics;
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
          metrics: metrics,
          size: metrics.dp(18),
          start: metrics.dp(2),
          child: ExpressiveStateBlend(
            active: checked,
            builder: (context, t, _) => Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: t),
                borderRadius: BorderRadius.circular(metrics.dp(5)),
                border: Border.all(
                  color: Color.lerp(colors.outline, colors.primary, t)!,
                  width: metrics.dp(1.6),
                ),
              ),
              child: Opacity(
                opacity: t,
                child: FaIcon(
                  FontAwesomeIcons.check,
                  size: metrics.dp(11),
                  color: colors.onPrimary,
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
