import 'package:flutter/foundation.dart';

import 'notebook_tree.dart';
import 'notebook_tree_rows.dart';
import 'notebook_view.dart';

/// 目录页“转移目录”可选的目标日记本：同一棵树里未合上的手动上级与手动子孙。
///
/// 上级与子孙分两组各自按 [notebookTreeRows] 树序缩进：混在一棵树里时当前本
/// 不列出，它的子本会按“列出来的上级”缩进，看起来就像挂在父本下面。
@immutable
class NotebookTransferTargets {
  const NotebookTransferTargets({
    required this.ancestors,
    required this.descendants,
  });

  factory NotebookTransferTargets.of(NotebookTree tree, String sourceId) {
    final ancestorIds = <String>{
      for (final ancestor in tree.ancestorsOf(sourceId)) ancestor.id,
    };
    final descendantIds = <String>{
      for (final descendant in tree.descendantsOf(sourceId)) descendant.id,
    };
    bool eligible(NotebookView notebook) =>
        notebook.isManual && !notebook.isClosed;
    return NotebookTransferTargets(
      ancestors: ancestorIds.isEmpty
          ? const <NotebookTreeRow>[]
          : notebookTreeRows(
              tree,
              include: (NotebookView notebook) =>
                  ancestorIds.contains(notebook.id) && eligible(notebook),
            ),
      descendants: descendantIds.isEmpty
          ? const <NotebookTreeRow>[]
          : notebookTreeRows(
              tree,
              include: (NotebookView notebook) =>
                  descendantIds.contains(notebook.id) && eligible(notebook),
            ),
    );
  }

  /// 上级，从顶层往下（父本在最后）。
  final List<NotebookTreeRow> ancestors;

  /// 子孙，直接子本缩进 0、孙子本缩进 1。
  final List<NotebookTreeRow> descendants;

  bool get isEmpty => ancestors.isEmpty && descendants.isEmpty;
}

/// 当前日记本是否在目录页提供“转移目录”：须是手动本，且还能新建子本或已经
/// 有可选的上级 / 子孙（第 3 层叶子本不能建子本，但能转回上级；上级都合上
/// 了时入口隐藏）。
bool canTransferNotebookContents(NotebookView notebook, NotebookTree? tree) {
  if (!notebook.isManual) return false;
  if (notebook.canHaveChildren) return true;
  if (tree == null) return false;
  return !NotebookTransferTargets.of(tree, notebook.id).isEmpty;
}
