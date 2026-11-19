import 'package:flutter/material.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../diaries/models/diary_text_style_options.dart';
import '../../diaries/viewmodels/diary_text_appearance.dart';
import 'mind_map_visuals.dart';

/// 大纲里一个主题的整条文字样式（局部样式由输入框与 [Text.rich] 逐段叠在
/// 上面）。
///
/// 输入：所在页面的正文样式 [base]（带墨色与主题字体）、正文排版
/// [appearance]（“编辑器设置 → 正文字体与排版”的字体、字号、行距、字间距）、
/// 主题解析器 [styles]、节点与层级。输出：
/// - 字体、行距、字间距随正文排版，与日记正文一样；
/// - 字号 = 正文字号 × 层级倍数（中心主题同正文二级标题、一级主题同四级
///   标题、其余同正文，见 [kDiaryHeadingScales]）× 主题自己的字号（小 / 中 /
///   大 / 特大，与画布同一档位）；
/// - 字重按层级（700 / 600 / 正文），整条的文字样式（粗斜体、装饰线、颜色、
///   高亮）经 [MindMapStyleResolver.runStyle] 叠在上面；
/// - 完成的待办整体变淡并划掉。
///
/// 纯计算。为什么不沿用导图主题的层级字号：大纲是一份可读的文档，与正文
/// 并排看时字号、行距应当一致；画布是图，字号由导图主题按层级定。
TextStyle mindMapOutlineTextStyle(
  TextStyle base, {
  required DiaryTextAppearance appearance,
  required MindMapStyleResolver styles,
  required MindMapNode node,
  required int depth,
}) {
  final typography = appearance.typography;
  final nodeStyle = MindMapNodeStyle(node.style);
  final (level, weight) = switch (depth) {
    0 => (kDiaryHeadingScales[1], FontWeight.w700),
    1 => (kDiaryHeadingScales[3], FontWeight.w600),
    _ => (1.0, FontWeight.normal),
  };
  var style = base.copyWith(
    fontFamily: appearance.fontFamily ?? base.fontFamily,
    fontSize: typography.fontSize * level * nodeStyle.size.scale,
    height: typography.lineHeight,
    letterSpacing: typography.letterSpacing,
    fontWeight: weight,
  );
  style = style.merge(styles.runStyle(nodeStyle.textMarks));
  if (node.taskDone) {
    final color = style.color ?? base.color ?? styles.palette.onSurface;
    style = style.copyWith(
      decoration: TextDecoration.combine(<TextDecoration>[
        style.decoration ?? TextDecoration.none,
        TextDecoration.lineThrough,
      ]),
      color: color.withValues(alpha: color.a * 0.55),
    );
  }
  return style;
}
