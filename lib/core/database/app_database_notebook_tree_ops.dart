part of 'app_database.dart';

/// 日记本的嵌套：放到别的上级下、批量写入之后的层级修复，以及删除与合并
/// 时子本的去向。
///
/// 层级口径（有效上级、层数、成环）只在 [NotebookHierarchy] 里，这里只负责
/// 读出整张日记本表交给它、按它的结论写回 `parent_id`。所有写入都在调用方
/// 的事务里或自带事务。
mixin _AppDatabaseNotebookTreeOps on _$AppDatabase {
  /// 整张日记本表的层级，子本按书架顺序。
  Future<NotebookHierarchy> notebookHierarchy() async {
    final rows =
        await (select(notebooks)
              ..orderBy(<OrderClauseGenerator<$NotebooksTable>>[
                (t) => OrderingTerm.desc(t.isPinned),
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return NotebookHierarchy(rows);
  }

  /// 把 [notebookId] 放到 [parentId] 下（null 为顶层），排在书架最后，也就是
  /// 新上级的子本里的最后一本。上级没变时什么也不做。
  ///
  /// 不合法（上级不存在、不是手动本、是它自己或它的子孙、放过去会超过
  /// [kNotebookMaxDepth] 层）时抛 [ArgumentError]，不改动数据；界面只给出
  /// 合法的选项（同一个 [NotebookHierarchy.problemFor]）。
  Future<void> moveNotebook(String notebookId, String? parentId) {
    return transaction(() async {
      final hierarchy = await notebookHierarchy();
      final row = hierarchy.rowOf(notebookId);
      if (row == null) {
        throw ArgumentError.value(notebookId, 'notebookId', '日记本不存在');
      }
      if (row.parentId == parentId) return;
      _checkNotebookParent(hierarchy, notebookId, parentId);
      await (update(notebooks)..where((t) => t.id.equals(row.id))).write(
        NotebooksCompanion(
          parentId: Value(parentId),
          sortOrder: Value(await _nextNotebookSortOrder()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// 批量写入（备份恢复与合并、撤销删除）之后修复层级：指向不存在、非手动
  /// 的上级，成环，或超出层数的，改回顶层。返回改动的本数。
  Future<int> repairNotebookHierarchy() {
    return transaction(() async {
      final repairs = (await notebookHierarchy()).repairs;
      for (final id in repairs.keys) {
        await (update(notebooks)..where((t) => t.notebookId.equals(id))).write(
          const NotebooksCompanion(parentId: Value(null)),
        );
      }
      return repairs.length;
    });
  }

  /// [parentId] 能否当 [childId]（null 为新建的本子）的上级，不能时抛
  /// [ArgumentError]。
  void _checkNotebookParent(
    NotebookHierarchy hierarchy,
    String? childId,
    String? parentId,
  ) {
    final problem = hierarchy.problemFor(childId, parentId);
    if (problem != null) {
      throw ArgumentError.value(
        parentId,
        'parentId',
        '不能放在这本日记本下（${problem.name}）',
      );
    }
  }

  /// 删除 [row] 之前把它的直接子本挪到它的上级下（顶层的就挪到顶层），返回
  /// 挪动过的子本业务 id，撤销时据此挪回。子本整棵子树往上提一层，不会超出
  /// 层数；子本里的日记不动。
  Future<List<String>> _liftNotebookChildren(NotebookRow row) async {
    final children = await (select(
      notebooks,
    )..where((t) => t.parentId.equals(row.notebookId))).get();
    if (children.isEmpty) return const <String>[];
    await (update(notebooks)..where((t) => t.parentId.equals(row.notebookId)))
        .write(NotebooksCompanion(parentId: Value(row.parentId)));
    return <String>[for (final child in children) child.notebookId];
  }

  /// 撤销删除时把 [childIds] 挪回 [parentId] 下：只挪仍在删除时放过去的位置
  /// （[liftedTo]）的子本，撤销窗口里被用户另行移动过的不动；之后修复层级。
  Future<void> _restoreNotebookChildren(
    String parentId,
    String? liftedTo,
    List<String> childIds,
  ) async {
    if (childIds.isEmpty) return;
    await (update(notebooks)..where(
          (t) =>
              t.notebookId.isIn(childIds) &
              (liftedTo == null
                  ? t.parentId.isNull()
                  : t.parentId.equals(liftedTo)),
        ))
        .write(NotebooksCompanion(parentId: Value(parentId)));
    await repairNotebookHierarchy();
  }

  /// 合并：[source] 并入 [target] 并删除之前，它的子本改挂到 [target] 下。
  ///
  /// [target] 本身在 [source] 的子树里时先把它提到 [source] 的上级下，否则
  /// 改挂之后会绕成环；挂过去超出层数的由最后的修复改回顶层。
  Future<void> _moveChildrenForMerge(
    NotebookRow source,
    NotebookRow target,
  ) async {
    final hierarchy = await notebookHierarchy();
    if (hierarchy
        .descendantsOf(source.notebookId)
        .contains(target.notebookId)) {
      await (update(notebooks)..where((t) => t.id.equals(target.id))).write(
        NotebooksCompanion(parentId: Value(source.parentId)),
      );
    }
    await (update(notebooks)..where(
          (t) =>
              t.parentId.equals(source.notebookId) &
              t.id.equals(target.id).not(),
        ))
        .write(NotebooksCompanion(parentId: Value(target.notebookId)));
  }

  Future<int> _nextNotebookSortOrder() async {
    final maxOrder = notebooks.sortOrder.max();
    final row = await (selectOnly(
      notebooks,
    )..addColumns(<Expression<Object>>[maxOrder])).getSingle();
    final current = row.read(maxOrder);
    return current == null ? 0 : current + 1;
  }
}
