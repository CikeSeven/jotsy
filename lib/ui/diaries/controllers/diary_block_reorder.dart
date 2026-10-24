import 'package:appflowy_editor/appflowy_editor.dart' as af;

import 'diary_editor_controller.dart';

/// 移动整棵子树。目标路径按移动前的树解释，原生事务负责删除后的路径变换；
/// 同时换算新选区，避免光标仍指向被挤走的相邻段落。禁止把块拖进自己的子树。
///
/// 移动后光标落在被移动块的末尾（媒体块为块本身），可以接着写；不选中
/// 整块——块选区会弹出系统选区菜单，打断书写。
///
/// [recordUndo] 为 false 时是拖动中的预览（见 [DiaryBlockDragSession]）：
/// 不进撤销栈，选区以 remote 原因更新，上游不会因此自动滚向光标——手指
/// 下的落点会随滚动继续变化。
bool moveDiaryEditorBlock(
  DiaryEditorController controller,
  af.Node node,
  af.Path destination, {
  bool recordUndo = true,
}) {
  if (controller.readOnly || node.parent == null || destination.isEmpty) {
    return false;
  }
  final source = node.path;
  if (destination.length > source.length &&
      destination.sublist(0, source.length).equals(source)) {
    return false;
  }
  final after = List<int>.of(destination);
  if (after.length >= source.length &&
      after.sublist(0, source.length - 1).equals(source.parent) &&
      after[source.length - 1] > source.last) {
    after[source.length - 1]--;
  }
  if (source.equals(after)) return false;
  final transaction = controller.state.transaction
    ..moveNode(destination, node)
    ..afterSelection = af.Selection.collapsed(
      af.Position(path: after, offset: node.delta?.length ?? 0),
    );
  if (!recordUndo) transaction.reason = af.SelectionUpdateReason.remote;
  controller.apply(transaction, recordUndo: recordUndo);
  return true;
}

/// [moveDiaryEditorBlock] 的反算：块现在在 [from]，要让它移动后落在 [to]
/// （两者都按当前的树解释），目标路径该传什么。移动先删后插，插入点在
/// 原位之后的同级（及其子树）会被前移一位，这里先补回来。
af.Path _destinationFor(af.Path from, af.Path to) {
  final depth = from.length - 1;
  if (to.length <= depth ||
      !to.sublist(0, depth).equals(from.parent) ||
      to[depth] < from.last) {
    return to;
  }
  return List<int>.of(to)..[depth] = to[depth] + 1;
}

/// 拖动段落的实时预览会话。
///
/// 拖动中每换一次落点就经 [preview] 把块真的挪过去，排版、缩进与前后段落
/// 的位置都是松手后的样子；这些移动不进撤销栈。松手经 [commit] 先放回
/// 原处、再以一次可撤销的移动落到最终位置——整次拖动只占一步撤销，撤销
/// 时光标回到拖动前的位置。[cancel]（指针被系统取消、页面被移除）只放回
/// 原处。会话期间 [DiaryEditorController.draggingBlock] 为 true。
///
/// 预览只改变这一块的位置、不动其余的树，所以块在任何时刻的路径都能直接
/// 换算回“从原位移过去”的目标路径。
class DiaryBlockDragSession {
  DiaryBlockDragSession(this.controller, this.node)
    : origin = node.path,
      _selection = controller.state.selection {
    controller.draggingBlock = true;
  }

  final DiaryEditorController controller;
  final af.Node node;

  /// 拖动开始时块的路径。
  final af.Path origin;
  final af.Selection? _selection;
  bool _closed = false;

  /// 把块挪到 [destination]（按当前的树解释）；位置没变时返回 false。
  bool preview(af.Path destination) =>
      !_closed &&
      moveDiaryEditorBlock(controller, node, destination, recordUndo: false);

  /// 结束会话并留在当前位置；位置变了才记一步撤销并返回 true。
  bool commit() {
    if (!_close()) return false;
    final target = node.path;
    if (target.equals(origin)) return false;
    _restore();
    return moveDiaryEditorBlock(
      controller,
      node,
      _destinationFor(origin, target),
    );
  }

  /// 结束会话并放回原处。
  void cancel() {
    if (_close() && !node.path.equals(origin)) _restore();
  }

  bool _close() {
    if (_closed) return false;
    _closed = true;
    controller.draggingBlock = false;
    return !controller.isDisposed && node.parent != null;
  }

  void _restore() {
    final transaction = controller.state.transaction
      ..moveNode(_destinationFor(node.path, origin), node)
      ..afterSelection =
          _selection ??
          af.Selection.collapsed(
            af.Position(path: origin, offset: node.delta?.length ?? 0),
          )
      ..reason = af.SelectionUpdateReason.remote;
    controller.apply(transaction, recordUndo: false);
  }
}
