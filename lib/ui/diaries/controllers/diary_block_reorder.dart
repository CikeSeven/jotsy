import 'dart:math' as math;

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

/// 移动段落时可以落脚的“缝”，以及在缝里保持缩进层级的目标路径。
///
/// 缩进是真实的父子结构（工具栏缩进 = 成为上一块的子块），层级即路径
/// 长度（顶层为 1）。只按“落在哪一块之前 / 之后”取目标，块会变成那一块
/// 的同级：缩进的段落拖出父块就丢了缩进，顶层段落拖进列表又平白多出一级。
/// 这里把文档按阅读顺序（先序）排开、去掉被移动的块及其子块，相邻两块
/// 之间是一条缝；同一条缝能容纳的层级是一个区间——
/// - 下限是缝下面那块的层级：块落在它前面，只能与它同级或更浅；
/// - 上限是缝上面那块的层级，那块能收子块（上游可缩进的四种类型，也只有
///   它们会画出子块）时再加一级，成为它的第一个子块；
/// - 缝上面那块有子块时，缝下面就是它的第一个子块，两者相等，只能放进去。
/// 移动时先在区间里取最接近原层级的那一级：放得下就原样保持，放不下（如
/// 拖到标题后面）才取最近的一级，之后拖到放得下的地方又会恢复。
class DiaryBlockGaps {
  DiaryBlockGaps(af.Node root, this.source) {
    void visit(Iterable<af.Node> nodes) {
      for (final node in nodes) {
        if (node == source) {
          current = blocks.length;
          continue;
        }
        blocks.add(node);
        visit(node.children);
      }
    }

    visit(root.children);
  }

  final af.Node source;

  /// 阅读顺序，不含 [source] 及其子块。第 i 条缝在 `blocks[i]` 之前，
  /// 0 为文首、`blocks.length` 为文末。
  final List<af.Node> blocks = [];

  /// [source] 现在所在的缝。
  int current = 0;

  /// 第 [gap] 条缝能容纳的层级区间。
  (int, int) depths(int gap) {
    final above = gap > 0 ? blocks[gap - 1] : null;
    final below = gap < blocks.length ? blocks[gap] : null;
    final min = below?.path.length ?? 1;
    final max = above == null
        ? 1
        : above.path.length +
              (af.indentableBlockTypes.contains(above.type) ? 1 : 0);
    return (min, math.max(min, max));
  }

  /// 落到第 [gap] 条缝、层级尽量为 [depth] 的目标路径（按当前的树解释，
  /// 交给 [moveDiaryEditorBlock]）；文档里没有别的块时为 null。
  af.Path? destination(int gap, int depth) {
    if (blocks.isEmpty) return null;
    if (gap <= 0) return blocks.first.path;
    final (min, max) = depths(gap);
    final level = depth.clamp(min, max);
    final above = blocks[gap - 1];
    // 成为上面那块的第一个子块（它原有的子块，也就是缝下面的块，排在后面）。
    if (level > above.path.length) return [...above.path, 0];
    // 否则排在上面那块同一层级的祖先（或它自己）之后：上面那块是这棵子树
    // 在阅读顺序里的最后一块，紧随其后就是这条缝。
    var anchor = above;
    while (anchor.path.length > level) {
      anchor = anchor.parent!;
    }
    return anchor.path.next;
  }

  /// 上移 / 下移一格：朝那个方向找最近一条能原样容纳当前层级的缝，缩进
  /// 不变；子块可以移出父块，接到上一块（或下一块）的子块里。没有这样的
  /// 缝时为 null（菜单项禁用）。顶层块因此仍是越过一整个同级块（连同子块），
  /// 与同级之间交换位置一致。
  af.Path? step({required bool up}) {
    final depth = source.path.length;
    for (
      var gap = up ? current - 1 : current + 1;
      gap >= 0 && gap <= blocks.length;
      gap += up ? -1 : 1
    ) {
      final (min, max) = depths(gap);
      if (depth >= min && depth <= max) return destination(gap, depth);
    }
    return null;
  }
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

  /// 拖动开始时的缩进层级：落点按它取（[DiaryBlockGaps]）。预览中途被
  /// 迫改了层级（如经过标题后面），拖到放得下的地方会恢复，不以中途的
  /// 层级为准。
  int get depth => origin.length;
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
