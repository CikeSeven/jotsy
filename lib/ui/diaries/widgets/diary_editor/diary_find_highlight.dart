import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../controllers/diary_find_replace.dart';
import '../../models/diary_find_query.dart';
import 'diary_block_selection_painter.dart';

/// 正文查找的高亮：包在每个顶层块外面（`AppFlowyEditor.blockWrapper`），
/// 画出这一块（含子块）里的全部匹配，当前那一处颜色更深并带描边。
///
/// 为什么画在块里而不是整个正文上叠一层：高亮按块自己的坐标画，滚动时随
/// 块一起移动、不必重画；块里的文字重新排版（打字、图片加载撑开）时块
/// 本身会重画，高亮跟着按新的排版取几何。匹配或当前项变化时
/// （[DiaryFindReplace] 通知）只重画、不重建。
///
/// 几何在绘制时才读：每处匹配经所在文字块的 `getRectsInSelection`（与
/// 选中文字的底色同一口径，首行缩进、表格格子各自的块组件已经处理）换成
/// 全局矩形，再换回本块的坐标。只含文字的块画在文字下面（字迹清晰），
/// 代码块、提示块、表格里的文字画在上面（它们自带不透明的底，衬在下面
/// 看不见），与段落选择的选中色同一规则（[diaryBlockTypePaintsOwnSurface]）。
/// 收起的折叠块里的内容没有组件，不画。
class DiaryFindHighlight extends SingleChildRenderObjectWidget {
  const DiaryFindHighlight({
    super.key,
    required this.find,
    required this.block,
    required this.colors,
    super.child,
  });

  final DiaryFindReplace find;

  /// 包着的顶层块。
  final af.Node block;
  final DiaryFindHighlightColors colors;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderDiaryFindHighlight(find: find, block: block, colors: colors);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderDiaryFindHighlight renderObject,
  ) {
    renderObject
      ..find = find
      ..block = block
      ..colors = colors;
  }
}

/// 高亮的颜色：取主题的第三色（与选中文字的主色、段落选择的主色区分开），
/// 半透明，背景图与玻璃上也透得出来；暗色主题的第三色偏亮，要多一些才看得清。
@immutable
class DiaryFindHighlightColors {
  const DiaryFindHighlightColors({
    required this.match,
    required this.current,
    required this.currentBorder,
  });

  factory DiaryFindHighlightColors.of(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    final tertiary = theme.colorScheme.tertiary;
    return DiaryFindHighlightColors(
      match: tertiary.withValues(alpha: dark ? 0.30 : 0.20),
      current: tertiary.withValues(alpha: dark ? 0.50 : 0.40),
      currentBorder: tertiary,
    );
  }

  final Color match;
  final Color current;
  final Color currentBorder;

  @override
  bool operator ==(Object other) =>
      other is DiaryFindHighlightColors &&
      other.match == match &&
      other.current == current &&
      other.currentBorder == currentBorder;

  @override
  int get hashCode => Object.hash(match, current, currentBorder);
}

/// [match] 此刻在屏幕上的矩形（全局坐标，可能折成几行）；所在的块没有
/// 组件（滚出了虚拟列表、在收起的折叠块里）或文字已经变短时为空。
List<Rect> diaryFindMatchGlobalRects(DiaryFindMatch match) {
  final node = match.node;
  final length = node.delta?.length;
  final selectable = node.selectable;
  if (node.parent == null ||
      length == null ||
      match.end > length ||
      selectable == null) {
    return const [];
  }
  final path = node.path;
  final List<Rect> local;
  if (match.isEmpty) {
    final caret = selectable.getCursorRectInPosition(
      af.Position(path: path, offset: match.start),
      shiftWithBaseOffset: true,
    );
    local = caret == null
        ? const []
        : [Rect.fromLTWH(caret.left - 1, caret.top, 2, caret.height)];
  } else {
    local = selectable.getRectsInSelection(
      af.Selection(
        start: af.Position(path: path, offset: match.start),
        end: af.Position(path: path, offset: match.end),
      ),
      shiftWithBaseOffset: true,
    );
  }
  return [
    for (final rect in local)
      if (rect.width > 0 || match.isEmpty)
        selectable.transformRectToGlobal(rect, shiftWithBaseOffset: true),
  ];
}

/// [DiaryFindHighlight] 的渲染对象：先画文字下面的高亮，再画块，最后画
/// 盖在块上面的高亮。
class RenderDiaryFindHighlight extends RenderProxyBox {
  RenderDiaryFindHighlight({
    required this._find,
    required this._block,
    required this._colors,
  });

  DiaryFindReplace _find;
  set find(DiaryFindReplace value) {
    if (identical(value, _find)) return;
    if (attached) _find.removeListener(markNeedsPaint);
    _find = value;
    if (attached) _find.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  af.Node _block;
  set block(af.Node value) {
    if (identical(value, _block)) return;
    _block = value;
    markNeedsPaint();
  }

  DiaryFindHighlightColors _colors;
  set colors(DiaryFindHighlightColors value) {
    if (value == _colors) return;
    _colors = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _find.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _find.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final matches = _find.isOpen
        ? _find.matchesInBlock(_block)
        : const <DiaryFindMatch>[];
    if (matches.isEmpty) {
      super.paint(context, offset);
      return;
    }
    final current = _find.current;
    final under = <(Rect, bool)>[];
    final over = <(Rect, bool)>[];
    af.Node? lastNode;
    var lastOver = false;
    for (final match in matches) {
      if (!identical(match.node, lastNode)) {
        lastNode = match.node;
        lastOver = _insideOwnSurface(match.node);
      }
      final isCurrent = identical(match, current);
      for (final rect in diaryFindMatchGlobalRects(match)) {
        final topLeft = globalToLocal(rect.topLeft);
        final local = (topLeft + offset) & rect.size;
        (lastOver ? over : under).add((local, isCurrent));
      }
    }
    _paintRects(context.canvas, under);
    super.paint(context, offset);
    _paintRects(context.canvas, over);
  }

  /// [node] 或它到顶层块之间的某一层自带不透明的底（代码块、提示块、
  /// 表格）：高亮要盖在文字上面才看得见。
  bool _insideOwnSurface(af.Node node) {
    for (af.Node? at = node; at != null; at = at.parent) {
      if (diaryBlockTypePaintsOwnSurface(at.type)) return true;
      if (identical(at, _block)) break;
    }
    return false;
  }

  void _paintRects(Canvas canvas, List<(Rect, bool)> rects) {
    if (rects.isEmpty) return;
    final fill = Paint()..color = _colors.match;
    final currentFill = Paint()..color = _colors.current;
    final border = Paint()
      ..color = _colors.currentBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final (rect, isCurrent) in rects) {
      // 左右各多出 1，字不贴着色块的边；零宽匹配本来就是一道 2 宽的竖线。
      final box = RRect.fromRectAndRadius(
        rect.width <= 2 ? rect : rect.inflate(1).deflateVertical(1),
        const Radius.circular(4),
      );
      canvas.drawRRect(box, isCurrent ? currentFill : fill);
      if (isCurrent) canvas.drawRRect(box, border);
    }
  }
}

extension on Rect {
  Rect deflateVertical(double delta) =>
      Rect.fromLTRB(left, top + delta, right, bottom - delta);
}
