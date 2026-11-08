part of 'app_database.dart';

/// 删除一个清单时被删掉的全部行，供撤销原样写回。
class TodoListDeletion {
  const TodoListDeletion({required this.list, required this.todos});

  final TodoListRow list;
  final List<TodoRow> todos;
}

/// 待办清单读写。
///
/// 输入：清单名、色板键、图标键与拖动后的邻居；输出：drift watch 流与业务 id。
/// 删除是硬删除：删清单连同其中的待办在同一事务里删掉（库里不开外键），撤销
/// 由调用方持有 [TodoListDeletion]、经 [restoreTodoList] 写回。
mixin _AppDatabaseTodoListOps on _$AppDatabase {
  /// 全部清单，按拖动顺序。
  Stream<List<TodoListRow>> watchTodoLists() {
    return (select(todoLists)..orderBy(<OrderClauseGenerator<$TodoListsTable>>[
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.id),
        ]))
        .watch();
  }

  Future<List<TodoListRow>> getTodoLists() {
    return (select(todoLists)..orderBy(<OrderClauseGenerator<$TodoListsTable>>[
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.id),
        ]))
        .get();
  }

  Future<TodoListRow?> getTodoList(String listId) {
    return (select(
      todoLists,
    )..where((t) => t.listId.equals(listId))).getSingleOrNull();
  }

  /// 新建清单（排在最后），返回业务 id。名称去掉首尾空白后不能为空。
  Future<String> createTodoList({
    required String name,
    String colorKey = '',
    String iconKey = '',
  }) async {
    final id = _newBusinessUuid();
    final now = DateTime.now();
    await transaction(() async {
      final maxOrder = todoLists.sortOrder.max();
      final row = await (selectOnly(
        todoLists,
      )..addColumns(<Expression<Object>>[maxOrder])).getSingle();
      final last = row.read(maxOrder);
      await into(todoLists).insert(
        TodoListsCompanion.insert(
          listId: id,
          name: _normalizeTodoListName(name),
          colorKey: Value(colorKey),
          iconKey: Value(iconKey),
          sortOrder: Value(TodoSortOrder.between(last, null)!),
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    return id;
  }

  Future<void> updateTodoList(
    String listId, {
    required String name,
    required String colorKey,
    required String iconKey,
  }) {
    return (update(todoLists)..where((t) => t.listId.equals(listId))).write(
      TodoListsCompanion(
        name: Value(_normalizeTodoListName(name)),
        colorKey: Value(colorKey),
        iconKey: Value(iconKey),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 把清单拖到 [aboveId] 与 [belowId] 之间（都可空：拖到最前 / 最后）。
  Future<void> moveTodoList(String listId, {String? aboveId, String? belowId}) {
    return transaction(() async {
      var rows = await getTodoLists();
      double? orderOf(String? id) {
        if (id == null) return null;
        for (final row in rows) {
          if (row.listId == id) return row.sortOrder;
        }
        return null;
      }

      var value = TodoSortOrder.between(orderOf(aboveId), orderOf(belowId));
      if (value == null) {
        // 邻居已分不开：按现有顺序整串重新编号后再取中点。
        for (var i = 0; i < rows.length; i++) {
          await (update(
            todoLists,
          )..where((t) => t.id.equals(rows[i].id))).write(
            TodoListsCompanion(sortOrder: Value(i * TodoSortOrder.gap)),
          );
        }
        rows = await getTodoLists();
        value = TodoSortOrder.between(orderOf(aboveId), orderOf(belowId)) ?? 0;
      }
      await (update(todoLists)..where((t) => t.listId.equals(listId))).write(
        TodoListsCompanion(
          sortOrder: Value(value),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// 删除清单与其中的全部待办（含已完成），返回被删的行；清单不存在时为 null。
  Future<TodoListDeletion?> deleteTodoList(String listId) {
    return transaction(() async {
      final list = await getTodoList(listId);
      if (list == null) return null;
      final members = await (select(
        todos,
      )..where((t) => t.listId.equals(listId))).get();
      await (delete(todos)..where((t) => t.listId.equals(listId))).go();
      await (delete(todoLists)..where((t) => t.id.equals(list.id))).go();
      return TodoListDeletion(list: list, todos: members);
    });
  }

  /// 撤销删除清单：按原 id 与业务 id 写回清单与其中的待办。
  Future<void> restoreTodoList(TodoListDeletion deletion) {
    return transaction(() async {
      await into(
        todoLists,
      ).insertOnConflictUpdate(deletion.list.toCompanion(false));
      for (final row in deletion.todos) {
        await into(todos).insertOnConflictUpdate(row.toCompanion(false));
      }
    });
  }

  /// 清单里的待办数（含已完成），删清单的确认框据此写明会一起删掉几条。
  Future<int> countTodosInList(String listId) async {
    final count = todos.id.count();
    final row =
        await (selectOnly(todos)
              ..addColumns(<Expression<Object>>[count])
              ..where(todos.listId.equals(listId)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// 每个清单（键为清单业务 id，收集箱为 null）里未完成的待办数。
  Stream<Map<String?, int>> watchOpenTodoCountsByList() {
    final count = todos.id.count();
    final query = selectOnly(todos)
      ..addColumns(<Expression<Object>>[todos.listId, count])
      ..where(todos.completedAt.isNull())
      ..groupBy(<Expression<Object>>[todos.listId]);
    return query.watch().map(
      (rows) => <String?, int>{
        for (final row in rows) row.read(todos.listId): row.read(count) ?? 0,
      },
    );
  }

  String _normalizeTodoListName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) {
      throw const FormatException('清单名称不能为空');
    }
    return name.length > 50 ? name.substring(0, 50) : name;
  }
}
