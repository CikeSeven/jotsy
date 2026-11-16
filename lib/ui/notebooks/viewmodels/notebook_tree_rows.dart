import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import 'notebook_tree.dart';
import 'notebook_view.dart';

/// 树形列表（管理页、选本面板、上级选择面板、画廊筛选等）的一行：日记本与
/// 它在列表里的缩进级数（0 为不缩进）。纯数据，层级口径只来自 [NotebookTree]。
@immutable
class NotebookTreeRow {
  const NotebookTreeRow(this.notebook, this.indent);

  final NotebookView notebook;
  final int indent;

  @override
  bool operator ==(Object other) =>
      other is NotebookTreeRow &&
      other.notebook == notebook &&
      other.indent == indent;

  @override
  int get hashCode => Object.hash(notebook, indent);
}

/// 把整棵树按树序展开（子本紧跟在上级后面），只留下 [include] 认可的本子。
///
/// 缩进按“列出来的上级”计数：上级没列出（合上了、被排除）时子本往外提一级，
/// 不会挂在一个看不见的上级下面、看起来像是前一本的子本。
List<NotebookTreeRow> notebookTreeRows(
  NotebookTree tree, {
  bool Function(NotebookView notebook)? include,
}) {
  final listed = <String>{};
  final rows = <NotebookTreeRow>[];
  for (final notebook in tree.depthFirst) {
    if (include != null && !include(notebook)) continue;
    listed.add(notebook.id);
    final indent = tree
        .ancestorsOf(notebook.id)
        .where((ancestor) => listed.contains(ancestor.id))
        .length;
    rows.add(NotebookTreeRow(notebook, indent));
  }
  return rows;
}

/// 管理页一个分组的行：分组里的每本顶层本子，后面紧跟它的全部子孙（不论
/// 子本自己是否合上、是什么类型——子本跟着上级走，不再单独分组），缩进
/// 按相对层数。
List<NotebookTreeRow> notebookSubtreeRows(
  NotebookTree tree,
  Iterable<NotebookView> roots,
) => <NotebookTreeRow>[
  for (final root in roots) ...<NotebookTreeRow>[
    NotebookTreeRow(root, 0),
    for (final descendant in tree.descendantsOf(root.id))
      NotebookTreeRow(descendant, descendant.depth - root.depth),
  ],
];

/// 可收起的树形列表（选本面板、上级选择面板、画廊筛选等，见
/// `NotebookFoldableRows`）这一帧的折叠情况，只看列出来的行：
///
/// - [parents]：下面有列出来的子孙的行，行尾给展开 / 收起；
/// - [folded]：列出来的上级里有一本在 [collapsed] 里的行，收到 0 高度。
///
/// 只按缩进推算：[notebookTreeRows] 按树序列出、缩进按列出来的上级计数，
/// 所以一行列出来的上级就是它前面缩进依次变浅的那几行，紧跟在一行后面、
/// 缩进比它深的连续几行正好是它列出来的子孙。上级没列出（被排除）而往外
/// 提了一级的子本跟着列出来的那一级走。
({Set<String> parents, Set<String> folded}) notebookRowsFold(
  List<NotebookTreeRow> rows,
  Set<String> collapsed,
) {
  final parents = <String>{};
  final folded = <String>{};
  final chain = <NotebookTreeRow>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    while (chain.isNotEmpty && chain.last.indent >= row.indent) {
      chain.removeLast();
    }
    if (chain.any((ancestor) => collapsed.contains(ancestor.notebook.id))) {
      folded.add(row.notebook.id);
    }
    if (i + 1 < rows.length && rows[i + 1].indent > row.indent) {
      parents.add(row.notebook.id);
    }
    chain.add(row);
  }
  return (parents: parents, folded: folded);
}

/// [id] 在列出来的行里的上级（从顶层往下，口径同 [notebookRowsFold]）；
/// 不在列表里或在顶层时为空。
List<String> notebookRowAncestors(List<NotebookTreeRow> rows, String id) {
  final chain = <NotebookTreeRow>[];
  for (final row in rows) {
    while (chain.isNotEmpty && chain.last.indent >= row.indent) {
      chain.removeLast();
    }
    if (row.notebook.id == id) {
      return <String>[for (final ancestor in chain) ancestor.notebook.id];
    }
    chain.add(row);
  }
  return const <String>[];
}

/// 管理页里收起后藏起来的本子：上级（任一层）在 [collapsed] 里的。被收起的
/// 那本自己照常显示，只藏它下面的子孙。
Set<String> notebookFoldedIds(NotebookTree tree, Set<String> collapsed) {
  if (collapsed.isEmpty) return const <String>{};
  return <String>{
    for (final notebook in tree.notebooks)
      if (tree
          .ancestorsOf(notebook.id)
          .any((ancestor) => collapsed.contains(ancestor.id)))
        notebook.id,
  };
}

/// 管理页拖动排序后，被拖的那本在同一上级的兄弟之间的新顺序。
///
/// [ids] 为拖动前分组里各行的业务 id（树序），[parentOf] 给出每本的上级；
/// 把第 [oldIndex] 行挪到 [newIndex]（`onReorderItem` 语义，已按移除旧位置
/// 修正）之后，按兄弟们在新列表里的先后排出它们的顺序。拖到别的上级的子本
/// 中间也不改上级，只按落点换算成兄弟之间的位置：落在某个兄弟（或它的子本）
/// 之后，就排在那个兄弟之后。
///
/// 返回的兄弟顺序交给 `notebookOrderAfterReorder`：它只在这些兄弟原本占着的
/// 全局位置之间重新分配，其他本子的相对顺序不变。
List<String> notebookSiblingOrderAfterDrag(
  List<String> ids,
  int oldIndex,
  int newIndex,
  String? Function(String id) parentOf,
) {
  if (oldIndex < 0 || oldIndex >= ids.length) return const <String>[];
  final moved = ids.toList();
  final dragged = moved.removeAt(oldIndex);
  moved.insert(newIndex.clamp(0, moved.length), dragged);
  final parent = parentOf(dragged);
  return <String>[
    for (final id in moved)
      if (parentOf(id) == parent) id,
  ];
}

/// 上级私密时，这本随之继承的可见性与给出它的那本上级（编辑页的提示）：
/// [parent] 的生效可见性比这本自己的 [own] 更严格时返回（取离这本最近、
/// 自己就设了这一档的上级），否则为 null。
({NotebookView source, NotebookVisibility visibility})?
notebookInheritedPrivacy(
  NotebookTree tree,
  NotebookView? parent,
  NotebookVisibility own,
) {
  if (parent == null) return null;
  final inherited = parent.effectiveVisibility;
  if (inherited.index <= own.index) return null;
  final chain = <NotebookView>[...tree.ancestorsOf(parent.id), parent];
  for (final candidate in chain.reversed) {
    if (candidate.isManual && candidate.visibility == inherited) {
      return (source: candidate, visibility: inherited);
    }
  }
  return (source: parent, visibility: inherited);
}

/// 树形列表每深一层的缩进（管理页、选本面板、上级选择面板等共用）。
const double notebookTreeIndentStep = 20;
