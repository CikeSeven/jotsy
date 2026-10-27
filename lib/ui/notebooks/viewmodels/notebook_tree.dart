import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import 'notebook_view.dart';

/// 书架上全部日记本的嵌套结构：每本的 [NotebookView]（带好上级、层数与生效
/// 可见性）以及上下级之间的查找。
///
/// 层级口径只在数据库层的 [NotebookHierarchy]，这里只是把它的结论换成界面
/// 用的 [NotebookView]。输入为书架顺序的行，子本顺序随之。纯数据，无副作用。
@immutable
class NotebookTree {
  factory NotebookTree(Iterable<NotebookRow> rows) {
    final list = rows.toList(growable: false);
    final hierarchy = NotebookHierarchy(list);
    final views = <NotebookView>[
      for (final row in list)
        NotebookView(
          row,
          parentId: hierarchy.parentOf(row.notebookId),
          depth: hierarchy.depthOf(row.notebookId),
          hasChildren: hierarchy.hasChildren(row.notebookId),
          effectiveVisibility: hierarchy.effectiveVisibilityOf(row.notebookId),
        ),
    ];
    return NotebookTree._(hierarchy, views);
  }

  /// 由书架列表重建（列表里的视图可能来自单独构造、不带层级信息）。
  factory NotebookTree.fromViews(Iterable<NotebookView> notebooks) =>
      NotebookTree(notebooks.map((notebook) => notebook.row));

  NotebookTree._(this.hierarchy, List<NotebookView> notebooks)
    : notebooks = List<NotebookView>.unmodifiable(notebooks),
      _byId = <String, NotebookView>{
        for (final notebook in notebooks) notebook.id: notebook,
      };

  static final NotebookTree empty = NotebookTree(const <NotebookRow>[]);

  final NotebookHierarchy hierarchy;

  /// 全部日记本，书架顺序（置顶在前，再按手动顺序）。
  final List<NotebookView> notebooks;
  final Map<String, NotebookView> _byId;

  NotebookView? operator [](String id) => _byId[id];

  List<NotebookView> _views(Iterable<String> ids) => <NotebookView>[
    for (final id in ids) ?_byId[id],
  ];

  /// 顶层的本子，书架顺序。
  List<NotebookView> get roots => _views(hierarchy.roots);

  /// 直接子本，书架顺序。
  List<NotebookView> childrenOf(String id) => _views(hierarchy.childrenOf(id));

  /// 从顶层到它的上级（不含自己），面包屑用。
  List<NotebookView> ancestorsOf(String id) =>
      _views(hierarchy.ancestorsOf(id));

  /// 全部子孙，深度优先。
  List<NotebookView> descendantsOf(String id) =>
      _views(hierarchy.descendantsOf(id));

  /// 整棵树深度优先展开（子本紧跟在上级后面），管理页与选本面板的树序。
  List<NotebookView> get depthFirst => _views(hierarchy.depthFirst);

  /// 父本列表里汇总的子孙：比它更私密的子本（以及它们下面的）不汇总——
  /// 进了一本普通的父本，不该不经验证就看到其中上锁子本的日记。
  List<NotebookView> aggregatedDescendantsOf(String id) {
    final root = _byId[id];
    if (root == null) return const <NotebookView>[];
    final limit = root.effectiveVisibility.index;
    final result = <NotebookView>[];
    void visit(String node) {
      for (final child in childrenOf(node)) {
        if (child.effectiveVisibility.index > limit) continue;
        result.add(child);
        visit(child.id);
      }
    }

    visit(id);
    return result;
  }

  /// 能当 [childId]（null 为新建的本子）上级的本子，树序；不合法的（见
  /// [NotebookHierarchy.problemFor]）不在其中。
  List<NotebookView> parentCandidatesFor(String? childId) => <NotebookView>[
    for (final notebook in depthFirst)
      if (hierarchy.problemFor(childId, notebook.id) == null) notebook,
  ];

  /// 上锁范围的根：自己或上级里最靠上的那本自己上了锁的本子；没有上锁时
  /// 为 null。同一个根下的本子之间来回切换不必重新验证。
  String? lockRootOf(String id) {
    for (final node in <String>[...hierarchy.ancestorsOf(id), id]) {
      final notebook = _byId[node];
      if (notebook != null &&
          notebook.isManual &&
          notebook.visibility == NotebookVisibility.locked) {
        return node;
      }
    }
    return null;
  }
}
