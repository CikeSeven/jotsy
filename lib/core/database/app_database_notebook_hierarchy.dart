part of 'app_database.dart';

/// 日记本的层级（嵌套）结构：由一份完整的日记本行列表现算，纯数据、无副作用。
///
/// 数据库层（移动、删除、合并时的校验与修复）与界面层（书架、选本面板、
/// 私密继承）共用同一套口径：
/// - 有效上级：`parent_id` 指向的本子存在、是手动本（只有手动本能当上级，
///   只认列里的原始值），且沿上级链往上不会绕回自己；否则当作顶层。成环时
///   环上的每一本都当作顶层，挂在环下面的仍跟着各自的上级；
/// - 层数：顶层为第 1 层，最多 [kNotebookMaxDepth] 层。超出层数只会来自批量
///   写入（备份合并），由 [AppDatabase.repairNotebookHierarchy] 改回顶层；
///   这里照实计算层数，不替它改结构；
/// - 子本顺序：同一上级下的子本按输入列表的先后（调用方传书架顺序）；
/// - 私密继承：一本的生效可见性取它自己与全部有效上级里最严格的一档
///   （locked > hidden > normal），与 SQL 的私密日记本口径一致；智能本自己
///   的可见性一律按 normal 看（写入时也只存 normal）。
@immutable
class NotebookHierarchy {
  NotebookHierarchy(Iterable<NotebookRow> rows)
    : _rows = <String, NotebookRow>{
        for (final row in rows) row.notebookId: row,
      },
      _order = <String>[for (final row in rows) row.notebookId] {
    final parents = <String, String?>{};
    for (final id in _order) {
      parents[id] = _linkedParent(id);
    }
    // 成环检测：从每一本往上走，走回已在本次路径上的节点就是环，把环上的
    // 节点全部断开。visited 记全局已确认无环的节点，整体线性。
    final settled = <String>{};
    for (final start in _order) {
      final path = <String>[];
      final onPath = <String>{};
      String? current = start;
      while (current != null && !settled.contains(current)) {
        if (!onPath.add(current)) {
          final cycleStart = path.indexOf(current);
          for (final member in path.sublist(cycleStart)) {
            parents[member] = null;
          }
          break;
        }
        path.add(current);
        current = parents[current];
      }
      settled.addAll(path);
    }
    _parents = Map<String, String?>.unmodifiable(parents);
    final children = <String, List<String>>{};
    for (final id in _order) {
      final parent = _parents[id];
      if (parent != null) (children[parent] ??= <String>[]).add(id);
    }
    _children = <String, List<String>>{
      for (final entry in children.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    };
  }

  final Map<String, NotebookRow> _rows;
  final List<String> _order;
  late final Map<String, String?> _parents;
  late final Map<String, List<String>> _children;

  /// 原始 `parent_id` 指向存在的手动本时返回它（不查环）。
  String? _linkedParent(String id) {
    final parentId = _rows[id]?.parentId;
    if (parentId == null || parentId == id) return null;
    final parent = _rows[parentId];
    if (parent == null || !parent.acceptsManualEntries) return null;
    return parentId;
  }

  bool contains(String id) => _rows.containsKey(id);

  NotebookRow? rowOf(String id) => _rows[id];

  /// 有效上级；顶层（含坏链接被当作顶层的）为 null。
  String? parentOf(String id) => _parents[id];

  /// 直接子本，按输入顺序。
  List<String> childrenOf(String id) => _children[id] ?? const <String>[];

  bool hasChildren(String id) => _children.containsKey(id);

  /// 顶层的本子，按输入顺序。
  List<String> get roots => <String>[
    for (final id in _order)
      if (_parents[id] == null) id,
  ];

  /// 从顶层到它的上级链（不含自己）；顶层为空列表。
  List<String> ancestorsOf(String id) {
    final chain = <String>[];
    var current = _parents[id];
    while (current != null) {
      chain.add(current);
      current = _parents[current];
    }
    return chain.reversed.toList(growable: false);
  }

  /// 层数：顶层为 1。
  int depthOf(String id) => ancestorsOf(id).length + 1;

  /// 以它为根的子树有几层（没有子本为 1）。
  int heightOf(String id) {
    var height = 1;
    for (final child in childrenOf(id)) {
      height = max(height, heightOf(child) + 1);
    }
    return height;
  }

  /// 全部子孙，深度优先、按输入顺序（自己不在其中）。
  List<String> descendantsOf(String id) {
    final result = <String>[];
    void visit(String node) {
      for (final child in childrenOf(node)) {
        result.add(child);
        visit(child);
      }
    }

    visit(id);
    return result;
  }

  /// 整棵树深度优先展开（顶层按输入顺序，子本紧跟在上级后面）。
  List<String> get depthFirst => <String>[
    for (final root in roots) ...<String>[root, ...descendantsOf(root)],
  ];

  /// 生效可见性：自己与全部有效上级里最严格的一档。
  NotebookVisibility effectiveVisibilityOf(String id) {
    var result = NotebookVisibility.normal;
    for (final node in <String>[...ancestorsOf(id), id]) {
      final row = _rows[node];
      if (row == null || !row.acceptsManualEntries) continue;
      final visibility = row.notebookVisibility;
      if (visibility.index > result.index) result = visibility;
    }
    return result;
  }

  /// 把 [childId]（null 表示一本新建的本子）放到 [parentId] 下（null 为
  /// 顶层）是否合法；不合法时返回原因，合法返回 null。
  ///
  /// 上级须存在、是手动本、不是它自己或它的子孙，且放过去之后整棵子树不超过
  /// [kNotebookMaxDepth] 层。
  NotebookParentProblem? problemFor(String? childId, String? parentId) {
    if (parentId == null) return null;
    final parent = _rows[parentId];
    if (parent == null) return NotebookParentProblem.missing;
    if (!parent.acceptsManualEntries) return NotebookParentProblem.notManual;
    if (childId != null &&
        (childId == parentId || descendantsOf(childId).contains(parentId))) {
      return NotebookParentProblem.cycle;
    }
    final height = childId == null || !contains(childId)
        ? 1
        : heightOf(childId);
    if (depthOf(parentId) + height > kNotebookMaxDepth) {
      return NotebookParentProblem.tooDeep;
    }
    return null;
  }

  /// 需要修复的本子 → 修复后的上级：原始 `parent_id` 不是有效上级（指向不存在
  /// 或非手动的本子、成环），或超出层数的，一律改回顶层（null）。
  Map<String, String?> get repairs {
    final result = <String, String?>{};
    for (final id in _order) {
      final raw = _rows[id]!.parentId;
      if (raw != null && _parents[id] != raw) result[id] = null;
    }
    // 超出层数：从上往下处理，上级改回顶层后下面的层数随之变浅，只断开
    // 真正放不下的那一层。
    final repaired = NotebookHierarchy(<NotebookRow>[
      for (final id in _order)
        result.containsKey(id)
            ? _rows[id]!.copyWith(parentId: const Value<String?>(null))
            : _rows[id]!,
    ]);
    for (final id in repaired.depthFirst) {
      if (repaired.depthOf(id) > kNotebookMaxDepth &&
          repaired.depthOf(repaired.parentOf(id)!) == kNotebookMaxDepth) {
        result[id] = null;
      }
    }
    return result;
  }
}

/// [NotebookHierarchy.problemFor] 的结果。
enum NotebookParentProblem { missing, notManual, cycle, tooDeep }
