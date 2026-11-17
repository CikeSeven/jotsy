import 'package:flutter/foundation.dart';

import 'notebook_tree.dart';
import 'notebook_tree_rows.dart';
import 'notebook_view.dart';

/// 日记本卡组里一项的种类。
enum NotebookDeckEntryKind {
  /// 全部日记。
  all,

  /// 未收录（不在任何手动本里的日记）。
  unfiled,

  /// 某一本日记本。
  notebook,

  /// “已合上”分组的标题条（点它展开 / 收起这一叠）。
  closedHeader,
}

/// 卡组所在的分组（同一本可能既在置顶里、又作为子本出现在上级下面，
/// 分组前缀让两处的 [NotebookDeckEntry.key] 不冲突）。
enum NotebookDeckGroup { scope, pinned, mine, smart, closed }

/// 卡组里的一项。纯数据，由 [buildNotebookDeckEntries] 生成。
///
/// [key] 是这一项在卡组里的身份：分组前缀 + 从分组顶层到它的 id 路径。
/// 动画（展开、收起、重排时各卡片弹簧到新位置）按它对上前后两帧的同一张卡。
@immutable
class NotebookDeckEntry {
  const NotebookDeckEntry._({
    required this.kind,
    required this.key,
    required this.group,
    this.notebook,
    this.depth = 0,
    this.parentKey,
    this.childCount = 0,
    this.expanded = false,
    this.closedCount = 0,
  });

  const NotebookDeckEntry.all()
    : this._(
        kind: NotebookDeckEntryKind.all,
        key: allKey,
        group: NotebookDeckGroup.scope,
      );

  const NotebookDeckEntry.unfiled()
    : this._(
        kind: NotebookDeckEntryKind.unfiled,
        key: unfiledKey,
        group: NotebookDeckGroup.scope,
      );

  static const String allKey = ':all';
  static const String unfiledKey = ':unfiled';
  static const String closedHeaderKey = ':closed';

  final NotebookDeckEntryKind kind;
  final String key;
  final NotebookDeckGroup group;

  /// [NotebookDeckEntryKind.notebook] 时的日记本。
  final NotebookView? notebook;

  /// 相对分组顶层的层数（0 为顶层），子本卡按它缩进。
  final int depth;

  /// 上级那一项的 [key]（顶层为 null）：子本展开时从它底下抽出、收起时
  /// 收回它底下。
  final String? parentKey;

  /// 直接子本数（有子本的卡片才有展开角标与纸边）。
  final int childCount;

  /// 子本是否已在卡组里展开。
  final bool expanded;

  /// [NotebookDeckEntryKind.closedHeader] 时“已合上”的本数。
  final int closedCount;

  bool get isNotebook => kind == NotebookDeckEntryKind.notebook;

  /// 可以点选切换的一项（标题条不是）。
  bool get selectable => kind != NotebookDeckEntryKind.closedHeader;

  /// 在“已合上”分组里（含标题条）：收起时这一叠压成一摞。
  bool get inClosedGroup => group == NotebookDeckGroup.closed;

  @override
  bool operator ==(Object other) =>
      other is NotebookDeckEntry &&
      other.kind == kind &&
      other.key == key &&
      other.notebook == notebook &&
      other.depth == depth &&
      other.parentKey == parentKey &&
      other.childCount == childCount &&
      other.expanded == expanded &&
      other.closedCount == closedCount;

  @override
  int get hashCode => Object.hash(
    kind,
    key,
    notebook,
    depth,
    parentKey,
    childCount,
    expanded,
    closedCount,
  );
}

/// 生成卡组的条目：全部日记、未收录，然后置顶 / 我的 / 智能三组顶层本子，
/// 最后是“已合上”标题条与合上的本子（分组口径同 [NotebookShelfGroups]）。
///
/// 每组顶层本子后面按 [notebookSubtreeRows] 的树序跟着子孙，只列出上级都
/// 已展开的那些：展开状态按“分组前缀:本子 id”记在 [expanded] 里（只在内存）。
/// [currentNotebookId] 不在顶层时，它所在分组里的上级链视为展开（打开卡组
/// 时能直接看到当前的那本），合上的分组也随之展开。
List<NotebookDeckEntry> buildNotebookDeckEntries({
  required List<NotebookView> notebooks,
  required NotebookTree tree,
  required Set<String> expanded,
  required bool closedExpanded,
  String? currentNotebookId,
}) {
  final groups = NotebookShelfGroups(notebooks);
  final revealed = _currentAncestorKeys(groups, tree, currentNotebookId);
  final entries = <NotebookDeckEntry>[
    const NotebookDeckEntry.all(),
    const NotebookDeckEntry.unfiled(),
  ];

  // 每本顶层单独展开：置顶组里上级与子本可能都置顶，同一本在一组里出现
  // 两次，按 id 折叠会把两处一起藏掉。
  void addSubtree(NotebookDeckGroup group, NotebookView root) {
    final prefix = deckGroupPrefix(group);
    final rows = notebookSubtreeRows(tree, <NotebookView>[root]);
    // 展开状态只看这一组：不在展开集合里的上级都算收起。
    final collapsed = <String>{
      for (final row in rows)
        if (row.notebook.hasChildren &&
            !expanded.contains('$prefix:${row.notebook.id}') &&
            !revealed.contains('$prefix:${row.notebook.id}'))
          row.notebook.id,
    };
    final fold = notebookRowsFold(rows, collapsed);
    // 从分组顶层到当前行的 key 链，给子本拼出唯一的路径 key。
    final chain = <({int indent, String key})>[];
    for (final row in rows) {
      while (chain.isNotEmpty && chain.last.indent >= row.indent) {
        chain.removeLast();
      }
      final parentKey = chain.isEmpty ? null : chain.last.key;
      final key = parentKey == null
          ? '$prefix:${row.notebook.id}'
          : '$parentKey/${row.notebook.id}';
      chain.add((indent: row.indent, key: key));
      if (fold.folded.contains(row.notebook.id)) continue;
      final childCount = fold.parents.contains(row.notebook.id)
          ? tree.childrenOf(row.notebook.id).length
          : 0;
      entries.add(
        NotebookDeckEntry._(
          kind: NotebookDeckEntryKind.notebook,
          key: key,
          group: group,
          notebook: row.notebook,
          depth: row.indent,
          parentKey: parentKey,
          childCount: childCount,
          expanded: childCount > 0 && !collapsed.contains(row.notebook.id),
        ),
      );
    }
  }

  void addGroup(NotebookDeckGroup group, List<NotebookView> roots) {
    for (final root in roots) {
      addSubtree(group, root);
    }
  }

  addGroup(NotebookDeckGroup.pinned, groups.pinned);
  addGroup(NotebookDeckGroup.mine, groups.shelfManual);
  addGroup(NotebookDeckGroup.smart, groups.shelfSmart);
  if (groups.closed.isNotEmpty) {
    final open =
        closedExpanded ||
        revealed.contains(deckGroupPrefix(NotebookDeckGroup.closed));
    entries.add(
      NotebookDeckEntry._(
        kind: NotebookDeckEntryKind.closedHeader,
        key: NotebookDeckEntry.closedHeaderKey,
        group: NotebookDeckGroup.closed,
        expanded: open,
        closedCount: groups.closed.length,
      ),
    );
    addGroup(NotebookDeckGroup.closed, groups.closed);
  }
  return entries;
}

/// 分组的 key 前缀。
String deckGroupPrefix(NotebookDeckGroup group) => switch (group) {
  NotebookDeckGroup.scope => '',
  NotebookDeckGroup.pinned => 'p',
  NotebookDeckGroup.mine => 'm',
  NotebookDeckGroup.smart => 's',
  NotebookDeckGroup.closed => 'c',
};

/// 当前日记本不在顶层时要展开的上级（“分组前缀:id”），合上的分组时再加上
/// 分组前缀本身。当前本子置顶时它已在置顶组里单列，不用展开别处。
Set<String> _currentAncestorKeys(
  NotebookShelfGroups groups,
  NotebookTree tree,
  String? currentNotebookId,
) {
  if (currentNotebookId == null) return const <String>{};
  final current = tree[currentNotebookId];
  if (current == null || current.parentId == null) return const <String>{};
  if (groups.pinned.any((n) => n.id == currentNotebookId)) {
    return const <String>{};
  }
  final ancestors = tree.ancestorsOf(currentNotebookId);
  if (ancestors.isEmpty) return const <String>{};
  // 从下往上找第一个在置顶组里的上级：子本跟着它显示在置顶组里；都不在
  // 置顶组时按顶层本子所在的分组。
  var group = NotebookDeckGroup.mine;
  var startIndex = 0;
  final pinnedIndex = ancestors.lastIndexWhere(
    (a) => groups.pinned.any((p) => p.id == a.id),
  );
  if (pinnedIndex >= 0) {
    group = NotebookDeckGroup.pinned;
    startIndex = pinnedIndex;
  } else {
    final root = ancestors.first;
    if (root.isClosed) {
      group = NotebookDeckGroup.closed;
    } else if (root.isSmart) {
      group = NotebookDeckGroup.smart;
    }
  }
  final prefix = deckGroupPrefix(group);
  return <String>{
    if (group == NotebookDeckGroup.closed) prefix,
    for (final ancestor in ancestors.sublist(startIndex))
      '$prefix:${ancestor.id}',
  };
}
