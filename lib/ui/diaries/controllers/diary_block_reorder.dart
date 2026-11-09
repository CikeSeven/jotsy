import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import 'diary_editor_controller.dart';
import 'diary_toggle_state.dart';

/// 段落移动：缝（落脚处）的计算、整组移动的事务与拖动的实时预览会话。
///
/// 移动的单位是“一组块”：段落把手拖动一块时是一块，段落选择模式里是选中
/// 的那几块（各自连同子树，见 `DiaryBlockSelection`）。一组块移动后按文档
/// 先后紧挨着排成同级——不连续的几块移动时聚到一起。
///
/// 输入：编辑控制器与要移动的块；输出：移动事务（可选进撤销栈）；没有其他
/// 副作用。

/// 移动后正文选区怎么处理。
enum DiaryBlockMoveSelection {
  /// 光标落在最后一块被移动的块末尾（媒体块为块本身），可以接着写；不选中
  /// 整块——块选区会弹出系统选区菜单，打断书写。段落把手的拖动用它。
  caretAtEnd,

  /// 选区原样跟着块走（偏移不变）：Alt + Shift + ↑ / ↓ 移动时文字选区不丢。
  follow,

  /// 不动选区：段落选择模式里正文没有选区，移动也不该落下光标、弹出键盘。
  none,
}

/// 把 [nodes]（各自连同子树）整组移到 [destination]，按文档先后紧挨着排成
/// 同级。目标路径按移动前的树解释（可以恰好是某个被移动块现在的位置，即
/// “排在它前面那块之后”）。禁止移进被移动块自己的子树；位置没变时返回
/// false。
///
/// 一个事务：先自下而上逐块删除，再一次插入到目标处。路径都按每一步之后
/// 的树手算、不交给上游变换——上游的路径变换在“插入点恰为被删块原位置”时
/// 会把插入点再减一，块就落到前一个位置。
///
/// [selection] 为 [DiaryBlockMoveSelection.follow] 时跟着走的是 [follow]
/// （缺省为当前选区）。
///
/// [recordUndo] 为 false 时是拖动中的预览（见 [DiaryBlockDragSession]）：
/// 不进撤销栈，选区以 remote 原因更新，上游不会因此自动滚向光标——手指
/// 下的落点会随滚动继续变化。
bool moveDiaryEditorBlocks(
  DiaryEditorController controller,
  Iterable<af.Node> nodes,
  af.Path destination, {
  bool recordUndo = true,
  DiaryBlockMoveSelection selection = DiaryBlockMoveSelection.caretAtEnd,
  af.Selection? follow,
}) {
  if (controller.readOnly) return false;
  final plan = _DiaryBlockMovePlan.of(nodes, destination);
  if (plan == null) return false;
  final transaction = controller.state.transaction;
  plan.addTo(transaction);
  switch (selection) {
    case DiaryBlockMoveSelection.caretAtEnd:
      final last = plan.nodes.last;
      transaction.afterSelection = af.Selection.collapsed(
        af.Position(
          path: plan.finalPath(plan.nodes.length - 1),
          offset: last.delta?.length ?? 0,
        ),
      );
    case DiaryBlockMoveSelection.follow:
      final current = follow ?? controller.state.selection;
      transaction.afterSelection = current == null
          ? null
          : af.Selection(
              start: plan.mapPosition(current.start),
              end: plan.mapPosition(current.end),
            );
    case DiaryBlockMoveSelection.none:
      break;
  }
  if (!recordUndo) transaction.reason = af.SelectionUpdateReason.remote;
  controller.apply(
    transaction,
    recordUndo: recordUndo,
    updateSelection: selection != DiaryBlockMoveSelection.none,
  );
  return true;
}

/// [nodes] 移到 [destination] 会不会改变文档（目标在被移动块的子树里也算
/// 不会）。拖动按它跳过等于没动的落点。
bool diaryBlocksMoveChanges(Iterable<af.Node> nodes, af.Path destination) =>
    _DiaryBlockMovePlan.of(nodes, destination) != null;

/// 规整一组块：去掉不在文档里的块与被组里别的块包含的后代（后代随祖先一起
/// 走），按文档先后（先序）排好。
List<af.Node> diaryBlockRoots(Iterable<af.Node> nodes) {
  final attached = {
    for (final node in nodes)
      if (node.parent != null) node,
  };
  final roots = [
    for (final node in attached)
      if (!attached.any((other) => other != node && other.isParentOf(node)))
        node,
  ]..sort((a, b) => a.path < b.path ? -1 : 1);
  return roots;
}

/// 一次整组移动的路径计算（见 [moveDiaryEditorBlocks]）。
class _DiaryBlockMovePlan {
  _DiaryBlockMovePlan(this.nodes, this.from, this.insert);

  /// 规整后的块，文档先后。
  final List<af.Node> nodes;

  /// 各块移动前的路径。
  final List<af.Path> from;

  /// 删除全部块之后的树里的插入路径；也是第一块移动后的路径。
  final af.Path insert;

  static _DiaryBlockMovePlan? of(Iterable<af.Node> nodes, af.Path destination) {
    if (destination.isEmpty) return null;
    final roots = diaryBlockRoots(nodes);
    if (roots.isEmpty) return null;
    final from = [for (final node in roots) node.path];
    for (final path in from) {
      if (destination.length > path.length &&
          destination.sublist(0, path.length).equals(path)) {
        return null;
      }
    }
    final plan = _DiaryBlockMovePlan(
      roots,
      from,
      _withoutRemoved(destination, from),
    );
    for (var i = 0; i < roots.length; i++) {
      if (!plan.finalPath(i).equals(from[i])) return plan;
    }
    return null;
  }

  /// 第 [index] 块移动后的路径。
  af.Path finalPath(int index) => [...insert.parent, insert.last + index];

  void addTo(af.Transaction transaction) {
    // 自下而上删除：后面的块先删，前面块的路径不受影响。
    for (var i = nodes.length - 1; i >= 0; i--) {
      transaction.add(
        af.DeleteOperation(from[i], [nodes[i]]),
        transform: false,
      );
    }
    transaction.add(af.InsertOperation(insert, nodes), transform: false);
  }

  /// 移动前的位置在移动后的位置：在被移动块里的跟着块走，其余的按删除与
  /// 插入平移。
  af.Position mapPosition(af.Position position) {
    final path = position.path;
    for (var i = 0; i < nodes.length; i++) {
      final source = from[i];
      if (path.length >= source.length &&
          path.sublist(0, source.length).equals(source)) {
        return af.Position(
          path: [...finalPath(i), ...path.sublist(source.length)],
          offset: position.offset,
        );
      }
    }
    final shifted = _withoutRemoved(path, from);
    final level = insert.length - 1;
    if (shifted.length > level &&
        shifted.sublist(0, level).equals(insert.parent) &&
        shifted[level] >= insert.last) {
      shifted[level] += nodes.length;
    }
    return af.Position(path: shifted, offset: position.offset);
  }
}

/// [path]（不在被删的子树里）在删掉 [removed] 这些块之后的路径：每一层
/// 减去排在它前面的被删兄弟数。被删块恰好在 [path] 处时不减——插入点仍在
/// 它前面那块之后。
af.Path _withoutRemoved(af.Path path, List<af.Path> removed) {
  final result = List<int>.of(path);
  for (var level = 0; level < path.length; level++) {
    var count = 0;
    for (final r in removed) {
      if (r.length == level + 1 &&
          r.sublist(0, level).equals(path.sublist(0, level)) &&
          r[level] < path[level]) {
        count++;
      }
    }
    result[level] -= count;
  }
  return result;
}

/// 移动段落时可以落脚的“缝”，以及在缝里保持缩进层级的目标路径。
///
/// 缩进是真实的父子结构（工具栏缩进 = 成为上一块的子块），层级即路径
/// 长度（顶层为 1）。只按“落在哪一块之前 / 之后”取目标，块会变成那一块
/// 的同级：缩进的段落拖出父块就丢了缩进，顶层段落拖进列表又平白多出一级。
/// 这里把文档按阅读顺序（先序）排开、去掉被移动的块及其子块，相邻两块
/// 之间是一条缝；同一条缝能容纳的层级是一个区间——
/// - 下限是缝下面那块的层级：块落在它前面，只能与它同级或更浅；
/// - 上限是缝上面那块的层级，那块能收子块（[kDiaryContainerBlockTypes]，
///   也只有它们会画出子块；收起的折叠块不算）时再加一级，成为它的第一个
///   子块；
/// - 收起的折叠块里的内容不在阅读顺序里（看不见），里面没有缝；
/// - 缝上面那块有子块时，缝下面就是它的第一个子块，两者相等，只能放进去。
/// 移动时先在区间里取最接近原层级的那一级：放得下就原样保持，放不下（如
/// 拖到标题后面）才取最近的一级，之后拖到放得下的地方又会恢复。
///
/// 一组块（[sources]）一起移动时，阅读顺序去掉的是它们全部；缝的编号与
/// 组里各块现在在哪无关，拖动预览可以按缝号反复挪动整组。整组的层级取
/// 其中最浅的一级（[depth]）。
class DiaryBlockGaps {
  DiaryBlockGaps(af.Node root, Iterable<af.Node> sources)
    : sources = sources.toSet() {
    void visit(Iterable<af.Node> nodes) {
      for (final node in nodes) {
        if (this.sources.contains(node)) {
          _gapOf[node] = blocks.length;
          continue;
        }
        blocks.add(node);
        // 收起的折叠块里的内容看不见、没有几何：不排进阅读顺序，块既不会
        // 落进去，上移 / 下移也把收起的折叠块连同内容当作一格越过。
        // 表格整个是一块：格子与格内段落之间没有缝。
        if (!isDiaryToggleCollapsed(node) && node.type != kDiaryBlockTable) {
          visit(node.children);
        }
      }
    }

    visit(root.children);
  }

  /// 要移动的块。
  final Set<af.Node> sources;

  /// 阅读顺序，不含 [sources] 及其子块。第 i 条缝在 `blocks[i]` 之前，
  /// 0 为文首、`blocks.length` 为文末。
  final List<af.Node> blocks = [];

  final Map<af.Node, int> _gapOf = {};

  /// [node]（组里的一块）现在所在的缝。
  int? gapOf(af.Node node) => _gapOf[node];

  /// 组里最前面那块所在的缝（单块时即它所在的缝）。
  int get current => _gapOf.isEmpty ? 0 : _gapOf.values.reduce(math.min);

  /// 组里最后面那块所在的缝。
  int get last => _gapOf.isEmpty ? 0 : _gapOf.values.reduce(math.max);

  /// 整组的层级：组里最浅的一级。
  int get depth => sources.isEmpty
      ? 1
      : sources.map((node) => node.path.length).reduce(math.min);

  /// 第 [gap] 条缝能容纳的层级区间。
  (int, int) depths(int gap) {
    final above = gap > 0 ? blocks[gap - 1] : null;
    final below = gap < blocks.length ? blocks[gap] : null;
    final min = below?.path.length ?? 1;
    final max = above == null
        ? 1
        : above.path.length + (_acceptsChildren(above) ? 1 : 0);
    return (min, math.max(min, max));
  }

  /// 块能不能收下拖来的子块：能挂子块的类型，收起的折叠块除外（放进去
  /// 就看不见了）。
  static bool _acceptsChildren(af.Node node) =>
      kDiaryContainerBlockTypes.contains(node.type) &&
      !isDiaryToggleCollapsed(node);

  /// 落到第 [gap] 条缝、层级尽量为 [depth] 的目标路径（按当前的树解释，
  /// 交给 [moveDiaryEditorBlocks]）；文档里没有别的块时为 null。
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

  /// 上移 / 下移一格：从组里最前（上移）/ 最后（下移）那块所在的缝起，朝
  /// 那个方向找最近一条能原样容纳 [depth] 的缝，缩进不变；子块可以移出
  /// 父块，接到上一块（或下一块）的子块里。没有这样的缝时为 null（按钮
  /// 停用）。顶层块因此仍是越过一整个同级块（连同子块），与同级之间交换
  /// 位置一致；不连续的几块移动后聚在那条缝里。
  af.Path? step({required bool up}) {
    final depth = this.depth;
    for (
      var gap = up ? current - 1 : last + 1;
      gap >= 0 && gap <= blocks.length;
      gap += up ? -1 : 1
    ) {
      final (min, max) = depths(gap);
      if (depth >= min && depth <= max) return destination(gap, depth);
    }
    return null;
  }

  /// 移到文首 / 文末，成为顶层块。
  af.Path? edge({required bool top}) => destination(top ? 0 : blocks.length, 1);
}
