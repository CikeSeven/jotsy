import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_rich_text.dart';
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
    this.highlight,
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

  /// 整条文字的高亮底色；null 为没有。不放进 [textStyle]：标签胶囊与贴纸
  /// 也从它派生，不该跟着铺底色。文字片段经 [textStyleWithHighlight] 取用。
  final Color? highlight;

  /// 主题文字本身的样式（含整条高亮）。
  TextStyle get textStyleWithHighlight => highlight == null
      ? textStyle
      : textStyle.copyWith(backgroundColor: highlight);

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
    // 自定义底色存的是种子色，与主题一样按明暗换算：底色取它的容器色、
    // 文字取容器上的文字色。
    if (style.fill case final custom? when shape.boxed) {
      final colors = palette.custom(custom);
      fill = colors.container;
      textColor = colors.onContainer;
      border = null;
    }
    // 文字颜色与高亮是内容配色，与正文同一套（预设、色系、自定义、我的
    // 颜色），按原色显示。高亮叠在节点底色（或画布）上后原来的文字看不清、
    // 又没单独设文字色时，文字换成对比更强的墨色（[readableInk]）。
    final highlight = style.highlight;
    if (style.color case final custom?) {
      textColor = custom;
    } else if (highlight != null) {
      textColor = readableInk(textColor, highlight, fill ?? palette.surface);
    }

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
        decoration: _decoration(
          underline: style.underline == true,
          strike: style.strike == true,
        ),
        decorationColor: textColor,
        letterSpacing: 0,
      ),
      highlight: highlight,
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

  /// 节点文字的排版片段：整条样式（[MindMapNodeVisual.textStyle]）为根，
  /// 局部样式逐段经 [runStyle] 覆盖；完成的待办整段变淡并划掉（局部设了
  /// 颜色的字也一样）。没有局部样式时就是一段纯文字。
  TextSpan textSpanOf(
    MindMapNodeVisual visual,
    List<InlineTextRun> runs, {
    bool taskDone = false,
  }) {
    var base = visual.textStyleWithHighlight;
    final ink = base.color;
    final backdrop = visual.fill ?? palette.surface;
    if (taskDone) {
      final color = base.color;
      base = base.copyWith(
        color: color?.withValues(alpha: (color.a) * 0.55),
        decoration: TextDecoration.combine(<TextDecoration>[
          base.decoration ?? TextDecoration.none,
          TextDecoration.lineThrough,
        ]),
        decorationColor: color?.withValues(alpha: 0.55),
      );
    }
    final text = inlineRunsText(runs);
    if (runs.every((run) => run.marks.isEmpty)) {
      return TextSpan(text: text, style: base);
    }
    return TextSpan(
      style: base,
      children: <InlineSpan>[
        for (final run in runs)
          TextSpan(
            text: run.text,
            style: runStyle(
              run.marks,
              base: base.decoration,
              ink: ink,
              backdrop: backdrop,
              taskDone: taskDone,
            ),
          ),
      ],
    );
  }

  /// 一段样式在底下那层样式之上要覆盖的部分（只含粗细、斜体、装饰线、
  /// 颜色与高亮，不含字号：编辑框按视口缩放字号、大纲按层级定字号，这里
  /// 的覆盖照样适用）。[base] 为底下那层的装饰线（只改下划线时保留删除线，
  /// 反之亦然）。没有可覆盖的为 null。
  ///
  /// 文字颜色与高亮按原色显示（与正文同一套）；只设了高亮的字，若底下那层
  /// 的文字色 [ink] 叠在高亮（再叠在 [backdrop] 上）上看不清，换成对比更强
  /// 的墨色（[readableInk]）。整条样式（`style`）也可经
  /// [MindMapNodeStyle.textMarks] 走这里（大纲视图）。
  TextStyle? runStyle(
    InlineTextMarks marks, {
    TextDecoration? base,
    Color? ink,
    Color? backdrop,
    bool taskDone = false,
  }) {
    if (marks.isEmpty) return null;
    final below = base ?? TextDecoration.none;
    TextDecoration? decoration;
    if (marks.underline != null || marks.strike != null) {
      decoration = _decoration(
        underline: marks.underline ?? below.contains(TextDecoration.underline),
        strike:
            taskDone ||
            (marks.strike ?? below.contains(TextDecoration.lineThrough)),
      );
    }
    var color = MindMapNodeStyle.parseColor(marks.color);
    final background = MindMapNodeStyle.parseColor(marks.highlight);
    if (color == null && background != null && ink != null) {
      final readable = readableInk(
        ink,
        background,
        backdrop ?? palette.surface,
      );
      if (readable != ink) color = readable;
    }
    if (taskDone && color != null) {
      color = color.withValues(alpha: color.a * 0.55);
    }
    final bold = marks.bold;
    final italic = marks.italic;
    if (bold == null &&
        italic == null &&
        decoration == null &&
        color == null &&
        background == null) {
      return null;
    }
    return TextStyle(
      fontWeight: bold == null
          ? null
          : (bold ? FontWeight.w700 : FontWeight.w400),
      fontStyle: italic == null
          ? null
          : (italic ? FontStyle.italic : FontStyle.normal),
      decoration: decoration,
      color: color,
      decorationColor: color,
      backgroundColor: background,
    );
  }

  /// 叠在 [highlight]（再叠在 [backdrop] 上）上的文字色：[ink] 的对比够
  /// （3:1）就用它，不够时在导图的墨色与表面色里取对比更强的一个（亮暗主题
  /// 下都是一深一浅）。
  Color readableInk(Color ink, Color highlight, Color backdrop) {
    final behind = Color.alphaBlend(highlight, backdrop);
    if (_contrast(ink, behind) >= 3) return ink;
    final dark = palette.onSurface;
    final light = palette.surface;
    return _contrast(dark, behind) >= _contrast(light, behind) ? dark : light;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  static TextDecoration _decoration({
    required bool underline,
    required bool strike,
  }) => TextDecoration.combine(<TextDecoration>[
    if (underline) TextDecoration.underline,
    if (strike) TextDecoration.lineThrough,
  ]);

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
  bool? get underline => raw[kMindMapStyleUnderlineKey] == true ? true : null;
  Color? get highlight => _color(raw[kMindMapStyleHighlightKey]);

  /// 整条样式里与文字有关的几项，按局部样式的形状读出（大纲视图经
  /// [MindMapStyleResolver.runStyle] 画整条样式时用）。
  InlineTextMarks get textMarks => InlineTextMarks(
    bold: bold,
    italic: italic,
    underline: underline,
    strike: strike,
    color: _string(raw[kMindMapStyleColorKey]),
    highlight: _string(raw[kMindMapStyleHighlightKey]),
  );

  static String? _string(Object? value) =>
      value is String && _color(value) != null ? value : null;
  MindMapTextSize get size =>
      MindMapTextSize.resolve(raw[kMindMapStyleSizeKey]);

  /// 解析 `#AARRGGBB` / `#RRGGBB`；坏值为 null。
  static Color? parseColor(Object? value) => _color(value);

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
