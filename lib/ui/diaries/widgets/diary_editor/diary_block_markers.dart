import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/diary_blocks/diary_list_style.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../controllers/diary_list_style_editing.dart';
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

/// 无序列表标记：形状取这段列表选的样式（`diary_list_style.dart`），没选过
/// 时按所在无序列表的嵌套层级轮换实心圆、空心圆、小方块。各形状的中心都在
/// 距起始边 11dp 处；尺寸按视觉重量对齐（星形、箭头这类镂空多的形状画得
/// 略大）。
class DiaryBulletMarker extends StatelessWidget {
  const DiaryBulletMarker({
    super.key,
    required this.node,
    required this.metrics,
  });

  final af.Node node;
  final DiaryMarkerMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final style = diaryBulletListStyleOf(node);
    return _MarkerCell(
      metrics: metrics,
      size: metrics.dp(designExtent(style)),
      start: metrics.dp(11 - designExtent(style) / 2),
      child: DiaryBulletShape(
        style: style,
        color: Theme.of(context).colorScheme.primary,
        scale: metrics.em / 16,
      ),
    );
  }

  /// 16sp 正文下各形状占的边长（列表面板的样式预览按比例缩小沿用）。
  static double designExtent(DiaryBulletListStyle style) => switch (style) {
    DiaryBulletListStyle.disc || DiaryBulletListStyle.circle => 6,
    DiaryBulletListStyle.square => 5,
    DiaryBulletListStyle.diamond => 7,
    DiaryBulletListStyle.star || DiaryBulletListStyle.arrow => 10,
    DiaryBulletListStyle.dash => 8,
  };
}

/// 一个无序列表标记形状，铺满父级给的方块。编辑器标记与工具栏列表面板的
/// 样式预览共用；[scale] 为相对 16sp 设计尺寸的比例（描边粗细随之变化）。
class DiaryBulletShape extends StatelessWidget {
  const DiaryBulletShape({
    super.key,
    required this.style,
    required this.color,
    this.scale = 1,
  });

  final DiaryBulletListStyle style;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) => switch (style) {
    DiaryBulletListStyle.disc => DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
    DiaryBulletListStyle.circle => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.4 * scale),
      ),
    ),
    DiaryBulletListStyle.square => DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(scale),
      ),
    ),
    // 旋转 45° 的方块：外接边长为 7 时方块边长约 5。
    DiaryBulletListStyle.diamond => Center(
      child: FractionallySizedBox(
        widthFactor: 0.7,
        heightFactor: 0.7,
        child: Transform.rotate(
          angle: math.pi / 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(0.6 * scale),
            ),
          ),
        ),
      ),
    ),
    // 图标字形本身留有边距，按方块边长取字号即与其他形状等大。
    DiaryBulletListStyle.star || DiaryBulletListStyle.arrow => LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => Center(
        child: FaIcon(
          style == DiaryBulletListStyle.star
              ? FontAwesomeIcons.solidStar
              : FontAwesomeIcons.arrowRight,
          size: constraints.biggest.shortestSide,
          color: color,
        ),
      ),
    ),
    DiaryBulletListStyle.dash => Center(
      child: SizedBox(
        height: 1.6 * scale,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(0.8 * scale),
          ),
        ),
      ),
    ),
  };
}

/// 有序列表序号：格式取这段列表选的样式（`diary_list_style.dart`），没选过
/// 时按层级轮换 1. / a. / i.；连续的同级有序列表接着编号（首项可带
/// `number` 起始号）。数字等宽，宽度不够时向右延伸、不折行。序号与正文
/// 同样式、同缩放、同行高规则排版，放在格子顶部即与正文基线对齐。
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
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: metrics.width),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: metrics.dp(2),
          end: metrics.dp(6),
        ),
        child: Text(
          diaryOrderedListStyleOf(node).label(_index),
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
