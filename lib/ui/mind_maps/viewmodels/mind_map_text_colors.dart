import 'dart:ui' show Color;

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_rich_text.dart';
import '../../diaries/models/diary_text_colors.dart';

/// 导图文字颜色与正文颜色面板之间的对应（纯计算）。
///
/// 导图的文字颜色（`color`）与高亮（`highlight`）与正文的文字色 / 背景色
/// 同一套：同样的预设、色系、自定义与我的颜色，按原色存 `#AARRGGBB`、按
/// 原色显示。这里把面板的两个目标对应到导图的两种颜色，并整理“这张导图
/// 里用过的颜色”给色板页的我的颜色一行。

/// 面板目标对应的导图颜色。
InlineColorMark mindMapColorMarkOf(DiaryColorTarget target) => switch (target) {
  DiaryColorTarget.text => InlineColorMark.color,
  DiaryColorTarget.background => InlineColorMark.highlight,
};

/// 这张导图里用过、但不是预设的 [target] 颜色（整条样式与局部样式都算，
/// 按先序去重，读不懂的值跳过）。只在面板打开、切换目标与回到色板时整理。
List<Color> mindMapDocumentColors(
  MindMapDocument document,
  DiaryColorTarget target,
) {
  final key = mindMapColorMarkOf(target);
  final seen = <int>{};
  final result = <Color>[];
  void add(Object? raw) {
    final color = raw is String ? parseDiaryColorValue(raw) : null;
    if (color == null || DiaryColorPreset.match(color, target) != null) return;
    if (seen.add(color.toARGB32())) result.add(color);
  }

  for (final id in document.index.preorder) {
    final node = document.index[id]!;
    add(node.style[key.key]);
    if (!mindMapHasRichText(node)) continue;
    for (final run in mindMapRunsOf(node)) {
      add(run.marks.colorOf(key));
    }
  }
  return result;
}
