import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

/// 独占一行、没有文字的块（媒体、日记链接卡片）共用的块级选区：整块只有
/// 开头与结尾两个位置，光标盖住整块（`cover`），选中时画整块的底色。
mixin DiaryEmbedSelectable<T extends af.BlockComponentStatefulWidget>
    on State<T>, af.SelectableMixin<T> {
  af.Node get node => widget.node;
  RenderBox? get box => context.findRenderObject() as RenderBox?;

  /// 包住块内容：上游据此绘制选区与光标。
  Widget buildEmbedSelection(af.EditorState state, Widget child) {
    return af.BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: state.selectionNotifier,
      remoteSelection: state.remoteSelections,
      blockColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      supportTypes: const [
        af.BlockSelectionType.block,
        af.BlockSelectionType.selection,
        af.BlockSelectionType.cursor,
      ],
      child: child,
    );
  }

  @override
  af.Position start() => af.Position(path: node.path);
  @override
  af.Position end() => af.Position(path: node.path, offset: 1);
  @override
  af.Position getPositionInOffset(Offset start) => end();
  @override
  bool get shouldCursorBlink => false;
  @override
  af.CursorStyle get cursorStyle => af.CursorStyle.cover;
  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) =>
      Offset.zero & (box?.size ?? Size.zero);
  @override
  Rect? getCursorRectInPosition(
    af.Position position, {
    bool shiftWithBaseOffset = false,
  }) => getBlockRect();
  @override
  List<Rect> getRectsInSelection(
    af.Selection selection, {
    bool shiftWithBaseOffset = false,
  }) => [getBlockRect()];
  @override
  af.Selection getSelectionInRange(Offset start, Offset end) =>
      af.Selection.single(path: node.path, startOffset: 0, endOffset: 1);
  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      box?.localToGlobal(offset) ?? offset;
  @override
  TextDirection textDirection() => TextDirection.ltr;
}
