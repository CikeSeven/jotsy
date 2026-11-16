import 'package:flutter/material.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_schema.dart';
import '../models/mind_map_options.dart';
import '../models/mind_map_themes.dart';
import 'mind_map_palette.dart';

/// 一个节点解析后的外观：形状、颜色、文字样式与内边距。
@immutable
final class MindMapNodeVisual {
  const MindMapNodeVisual({
    required this.shape,
    required this.fill,
    required this.border,
    required this.borderWidth,
    required this.textStyle,
    required this.padding,
    required this.branchColor,
    required this.lineWidth,
    required this.maxTextWidth,
    required this.textAlign,
  });

  final MindMapNodeShape shape;

  /// 底色；null 为不画底。
  final Color? fill;

  /// 描边色；null 为不描边。
  final Color? border;
  final double borderWidth;

  /// 文字样式（含颜色）。
  final TextStyle textStyle;
  final EdgeInsets padding;

  /// 所在分支的颜色：连到这个节点的线与它的下划线都用它。
  final Color branchColor;

  /// 连到这个节点的线宽（下划线同宽）。
  final double lineWidth;
  final double maxTextWidth;
  final TextAlign textAlign;

  bool get underline => shape == MindMapNodeShape.underline;

  /// 圆角半径（按节点高度换算）。
  double radiusFor(Size size) => switch (shape) {
    MindMapNodeShape.pill => size.height / 2,
    MindMapNodeShape.rounded => (size.height * 0.32).clamp(8.0, 16.0),
    MindMapNodeShape.rect => 5,
    _ => 0,
  };
}

/// 按主题、配色与节点自己的样式覆盖解析每个节点的外观。
///
/// 输入：主题 [spec]、配色 [palette]、是否分支彩虹 [rainbow]、基础文字样式
/// [baseText]（字体随应用）。输出 [MindMapNodeVisual]。纯计算，无副作用；
/// 布局与缩略图共用，同一份导图在画布、卡片与导出里外观一致。
final class MindMapStyleResolver {
  MindMapStyleResolver({
    required this.spec,
    required this.palette,
    required this.rainbow,
    required this.baseText,
  });

  final MindMapThemeSpec spec;
  final MindMapPalette palette;
  final bool rainbow;
  final TextStyle baseText;

  /// 线宽：根到一级、一级到二级、更深层级；结构装饰线（时间轴、鱼骨主骨）
  /// 用 [rootLineWidth]。曲线时根部的连线画成锥形（起点加粗，见
  /// mind_map_painter.dart）。
  static const double rootLineWidth = 3.2;
  static const double primaryLineWidth = 2.6;
  static const double secondaryLineWidth = 2;
  static const double leafLineWidth = 1.5;

  MindMapNodeVisual visualOf(MindMapIndex index, MindMapNode node) {
    final depth = index.depthOf(node.id);
    final level = spec.level(depth);
    final style = MindMapNodeStyle(node.style);
    final branch = _branchColors(index, node, depth);
    final shape = style.shape ?? level.shape;
    final size = style.size.scale;
    final weight = style.bold == null
        ? level.weight
        : (style.bold! ? FontWeight.w700 : FontWeight.w400);

    Color? fill;
    Color? border;
    var borderWidth = 0.0;
    Color textColor;
    final mode = shape.boxed ? level.fill : MindMapFill.none;
    if (depth == 0) {
      switch (level.fill) {
        case MindMapFill.inverse:
          fill = palette.inverse.accent;
          textColor = palette.inverse.onAccent;
        case MindMapFill.container:
          fill = palette.root.container;
          textColor = palette.root.onContainer;
        case MindMapFill.outline:
          fill = palette.surface;
          border = palette.root.accent;
          borderWidth = 2;
          textColor = palette.onSurface;
        case MindMapFill.none:
          textColor = palette.onSurface;
        case MindMapFill.solid:
          fill = palette.root.accent;
          textColor = palette.root.onAccent;
      }
      if (!shape.boxed) {
        fill = null;
        border = null;
        textColor = palette.onSurface;
      }
    } else {
      switch (mode) {
        case MindMapFill.solid || MindMapFill.inverse:
          fill = branch.accent;
          textColor = branch.onAccent;
        case MindMapFill.container:
          fill = branch.container;
          textColor = branch.onContainer;
        case MindMapFill.outline:
          fill = palette.surface;
          border = branch.accent;
          borderWidth = 1.6;
          textColor = palette.onSurface;
        case MindMapFill.none:
          textColor = palette.onSurface;
      }
    }
    // 自定义底色：文字取与底色对比更强的一侧（画布文字色或卡片底色）。
    if (style.fill case final custom? when shape.boxed) {
      fill = custom;
      textColor = _contrastOn(custom);
    }
    if (style.color case final custom?) textColor = custom;

    final fontSize = level.fontSize * size;
    return MindMapNodeVisual(
      shape: shape,
      fill: fill,
      border: border,
      borderWidth: borderWidth,
      textStyle: baseText.copyWith(
        color: textColor,
        fontSize: fontSize,
        fontWeight: weight,
        height: 1.3,
        fontStyle: style.italic == true ? FontStyle.italic : FontStyle.normal,
        decoration: style.strike == true
            ? TextDecoration.lineThrough
            : TextDecoration.none,
        decorationColor: textColor,
        letterSpacing: 0,
      ),
      padding: level.padding * (0.5 + size / 2),
      branchColor: depth == 0 ? (fill ?? palette.root.accent) : branch.accent,
      lineWidth: switch (depth) {
        0 || 1 => primaryLineWidth,
        2 => secondaryLineWidth,
        _ => leafLineWidth,
      },
      maxTextWidth: switch (depth) {
        0 => 300,
        1 => 260,
        _ => 240,
      },
      textAlign: shape.boxed ? TextAlign.center : TextAlign.start,
    );
  }

  /// 占位文字的颜色（节点还没写字时）。
  Color placeholderColor(MindMapNodeVisual visual) =>
      (visual.textStyle.color ?? palette.onSurface).withValues(alpha: 0.45);

  MindMapBranchColors _branchColors(
    MindMapIndex index,
    MindMapNode node,
    int depth,
  ) {
    // 自定义分支色作用于整条分支：取自己或最近的祖先上设的那个。
    String? current = node.id;
    while (current != null) {
      final branch = MindMapNodeStyle(index[current]!.style).branch;
      if (branch != null) return palette.custom(branch);
      current = index.parentOf(current);
    }
    return palette.branch(index.branchOf(node.id), rainbow: rainbow);
  }

  Color _contrastOn(Color background) {
    final lum = background.computeLuminance();
    final a = palette.onSurface;
    final b = palette.surface;
    double ratio(Color c) {
      final l = c.computeLuminance();
      final hi = l > lum ? l : lum;
      final lo = l > lum ? lum : l;
      return (hi + 0.05) / (lo + 0.05);
    }

    return ratio(a) >= ratio(b) ? a : b;
  }
}

/// 节点 `style` 的类型化读取（坏值按没设处理）。
@immutable
final class MindMapNodeStyle {
  const MindMapNodeStyle(this.raw);

  final Map<String, Object?> raw;

  Color? get fill => _color(raw[kMindMapStyleFillKey]);
  Color? get color => _color(raw[kMindMapStyleColorKey]);
  Color? get branch => _color(raw[kMindMapStyleBranchKey]);
  MindMapNodeShape? get shape =>
      MindMapNodeShape.tryResolve(raw[kMindMapStyleShapeKey]);
  bool? get bold => raw[kMindMapStyleBoldKey] is bool
      ? raw[kMindMapStyleBoldKey] as bool
      : null;
  bool? get italic => raw[kMindMapStyleItalicKey] == true ? true : null;
  bool? get strike => raw[kMindMapStyleStrikeKey] == true ? true : null;
  MindMapTextSize get size =>
      MindMapTextSize.resolve(raw[kMindMapStyleSizeKey]);

  static Color? _color(Object? value) {
    if (value is! String) return null;
    final hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length != 8 && hex.length != 6) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  /// 颜色写成 `#AARRGGBB`。
  static String encodeColor(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}
