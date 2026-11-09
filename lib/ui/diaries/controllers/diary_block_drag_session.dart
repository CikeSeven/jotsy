import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;

import 'diary_block_reorder.dart';
import 'diary_editor_controller.dart';

/// 拖动段落的实时预览会话。
///
/// 拖动中每换一次落点就经 [preview] 把整组块真的挪过去，排版、缩进与前后
/// 段落的位置都是松手后的样子；这些移动不进撤销栈。松手经 [commit] 先放回
/// 原处、再以一次可撤销的移动落到最终位置——整次拖动只占一步撤销，撤销
/// 时光标回到拖动前的位置。[cancel]（指针被系统取消、页面被移除）只放回
/// 原处。会话期间 [DiaryEditorController.draggingBlock] 为 true。
///
/// 预览只改变这几块的位置、不动其余的树：放回原处时按各块原来的路径依次
/// 插回；最终位置记成（缝，层级）——缝的编号与组里各块在哪无关，放回原处
/// 后仍指同一个地方。
class DiaryBlockDragSession {
  DiaryBlockDragSession(
    this.controller,
    Iterable<af.Node> nodes, {
    this.selection = DiaryBlockMoveSelection.caretAtEnd,
  }) : nodes = diaryBlockRoots(nodes),
       _selection = controller.state.selection {
    origin = [for (final node in this.nodes) node.path];
    controller.draggingBlock = true;
  }

  final DiaryEditorController controller;

  /// 被拖的块（规整后，文档先后）。
  final List<af.Node> nodes;

  /// 移动后的选区：段落把手为光标落在块末尾，段落选择模式为不动。
  final DiaryBlockMoveSelection selection;

  /// 拖动开始时各块的路径。
  late final List<af.Path> origin;

  /// 拖动开始时的缩进层级（组里最浅的一级）：落点按它取（[DiaryBlockGaps]）。
  /// 预览中途被迫改了层级（如经过标题后面），拖到放得下的地方会恢复，不以
  /// 中途的层级为准。
  int get depth =>
      origin.isEmpty ? 1 : origin.map((path) => path.length).reduce(math.min);
  final af.Selection? _selection;
  bool _closed = false;

  /// 把整组挪到 [destination]（按当前的树解释）；位置没变时返回 false。
  bool preview(af.Path destination) =>
      !_closed &&
      moveDiaryEditorBlocks(
        controller,
        nodes,
        destination,
        recordUndo: false,
        selection: selection,
      );

  /// 结束会话并留在当前位置；位置变了才记一步撤销并返回 true。
  bool commit() {
    if (!_close() || _atOrigin) return false;
    // 预览过就聚成了连续的一组：第一块所在的缝与它的层级就是最终位置。
    final gap = DiaryBlockGaps(
      controller.document.root,
      nodes,
    ).gapOf(nodes.first);
    final level = nodes.first.path.length;
    _restore();
    if (gap == null) return false;
    final destination = DiaryBlockGaps(
      controller.document.root,
      nodes,
    ).destination(gap, level);
    return destination != null &&
        moveDiaryEditorBlocks(
          controller,
          nodes,
          destination,
          selection: selection,
        );
  }

  /// 结束会话并放回原处。
  void cancel() {
    if (_close() && !_atOrigin) _restore();
  }

  bool get _atOrigin {
    for (var i = 0; i < nodes.length; i++) {
      if (!nodes[i].path.equals(origin[i])) return false;
    }
    return true;
  }

  bool _close() {
    if (_closed) return false;
    _closed = true;
    controller.draggingBlock = false;
    return !controller.isDisposed &&
        nodes.isNotEmpty &&
        nodes.every((node) => node.parent != null);
  }

  /// 放回原处：按现在的位置自下而上删除，再按原来的路径自上而下插回——
  /// 其余的块没动过，插回时前面的块已经就位，原来的路径即是正确的插入点。
  void _restore() {
    final current = [
      for (var i = 0; i < nodes.length; i++) (nodes[i], nodes[i].path),
    ]..sort((a, b) => a.$2 < b.$2 ? 1 : -1);
    final transaction = controller.state.transaction;
    for (final (node, path) in current) {
      transaction.add(af.DeleteOperation(path, [node]), transform: false);
    }
    for (var i = 0; i < nodes.length; i++) {
      transaction.add(
        af.InsertOperation(origin[i], [nodes[i]]),
        transform: false,
      );
    }
    final restoreSelection = selection != DiaryBlockMoveSelection.none;
    if (restoreSelection) {
      transaction.afterSelection =
          _selection ??
          af.Selection.collapsed(
            af.Position(
              path: origin.last,
              offset: nodes.last.delta?.length ?? 0,
            ),
          );
    }
    transaction.reason = af.SelectionUpdateReason.remote;
    controller.apply(
      transaction,
      recordUndo: false,
      updateSelection: restoreSelection,
    );
  }
}
