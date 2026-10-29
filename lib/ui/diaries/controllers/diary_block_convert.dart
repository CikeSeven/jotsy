import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import 'diary_table_editing.dart';

/// 把 [nodes] 换成 [type]（各块的新属性由 [attributesFor] 给出），写进
/// [transaction]，返回换类型后与 [selection] 对应的选区。
///
/// 编辑器只为段落、列表与待办（[kDiaryContainerBlockTypes]）画子块。换成
/// 标题、引用、代码块这类不画子块的类型时，带子块的块不能原地换类型——
/// 子块（缩进在它下面的段落）会留在树里却看不见，看起来就是丢了。这里与
/// 上游 Markdown 快捷输入（`# `、`> `）的做法一致：把这样的块连同子树换成
/// 一串副本，换了类型的块在前，子块依次提到它后面成为同级；子树里同样被
/// 选中、同样带子块的块逐级照此处理。阅读顺序不变，只少一级缩进；整次在
/// 同一个事务里，一步撤销。
///
/// 为什么用副本而不是挪原来的节点：上游原地换类型会换掉节点对象并把子块
/// 摘过去，同一事务里再引用旧节点挪子块，撤销时会把丢了子块的旧对象放回去。
/// 整棵替换时删除操作持有未改动的原节点，撤销原样放回。
///
/// 不带子块的块、或换成能画子块的类型时原地换类型，节点保留。
///
/// 表格格子里的段落不换类型（格子只能放段落，换了读取时会被改回来）：
/// [nodes] 里在格子中的块一律跳过，工具栏、`/` 菜单与各面板共用这一条。
af.Selection? addDiaryBlockTypeChange(
  af.Transaction transaction, {
  required af.Node root,
  required List<af.Node> nodes,
  required String type,
  required Map<String, Object?> Function(af.Node node) attributesFor,
  required af.Selection? selection,
}) {
  nodes = [
    for (final node in nodes)
      if (!diaryNodeInTableCell(node)) node,
  ];
  final selected = nodes.toSet();
  final hidesChildren = !kDiaryContainerBlockTypes.contains(type);
  final parents = hidesChildren
      ? {
          for (final node in nodes)
            if (node.children.isNotEmpty) node,
        }
      : const <af.Node>{};
  // 只替换最上层的：更深的已在它的副本里一并处理。
  final replaced = [
    for (final node in nodes)
      if (parents.contains(node) && !_hasAncestorIn(node, parents)) node,
  ];
  final replacedSet = replaced.toSet();
  bool inReplaced(af.Node node) =>
      replacedSet.contains(node) || _hasAncestorIn(node, replacedSet);

  // 原地换类型的先加：它们不改结构，用的都是换类型前的路径。
  for (final node in nodes) {
    if (!inReplaced(node)) {
      transaction.updateNodeType(node, type, attributesFor(node));
    }
  }
  if (replaced.isEmpty) return selection;

  List<af.Node> rebuild(af.Node node) {
    final converted = selected.contains(node);
    final nodeType = converted ? type : node.type;
    final children = [for (final child in node.children) ...rebuild(child)];
    final container = kDiaryContainerBlockTypes.contains(nodeType);
    return [
      node.copyWith(
        type: nodeType,
        attributes: converted ? {...attributesFor(node)} : {...node.attributes},
        children: container ? children : const [],
      ),
      if (!container) ...children,
    ];
  }

  final replacements = {for (final node in replaced) node: rebuild(node)};
  // 从后往前替换：后面的替换不影响前面块的路径；先插入副本再删除原块，
  // 删除的路径由事务按插入换算。
  for (final node in replaced.reversed) {
    transaction
      ..insertNodes(node.path, replacements[node]!, deepCopy: false)
      ..deleteNode(node);
  }
  if (selection == null) return null;
  return _mapSelection(root, selection, replacements);
}

bool _hasAncestorIn(af.Node node, Set<af.Node> nodes) {
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    if (nodes.contains(parent)) return true;
  }
  return false;
}

/// 替换只把子块提到后面，阅读顺序（先序）里的第 k 块仍是第 k 块：按序号
/// 在替换后的树形里找回选区两端的路径，偏移不变。
af.Selection? _mapSelection(
  af.Node root,
  af.Selection selection,
  Map<af.Node, List<af.Node>> replacements,
) {
  Iterable<af.Node> before(af.Node parent) => parent.children;
  Iterable<af.Node> after(af.Node parent) sync* {
    for (final child in parent.children) {
      final replacement = replacements[child];
      if (replacement != null) {
        yield* replacement;
      } else {
        yield child;
      }
    }
  }

  // 先序遍历 [children] 给出的树形，[visit] 返回非 null 时停下。
  T? walk<T>(
    Iterable<af.Node> Function(af.Node) children,
    T? Function(af.Node node, af.Path path, int index) visit,
  ) {
    var index = 0;
    T? descend(af.Node parent, af.Path prefix) {
      var i = 0;
      for (final child in children(parent)) {
        final path = [...prefix, i++];
        final result = visit(child, path, index++) ?? descend(child, path);
        if (result != null) return result;
      }
      return null;
    }

    return descend(root, const []);
  }

  af.Position? map(af.Position position) {
    final index = walk<int>(
      before,
      (_, path, index) => path.equals(position.path) ? index : null,
    );
    if (index == null) return null;
    final path = walk<af.Path>(
      after,
      (_, path, at) => at == index ? path : null,
    );
    return path == null ? null : position.copyWith(path: path);
  }

  final start = map(selection.start);
  final end = map(selection.end);
  return start == null || end == null
      ? null
      : af.Selection(start: start, end: end);
}
