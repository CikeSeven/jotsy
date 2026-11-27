part of 'app_database.dart';

/// 删除一个分区时改动前的样子（供 [_AppDatabaseTodoSectionOps.restoreTodoSection]
/// 撤销）：清单行、其中的待办，以及这些待办是被删掉了还是只是移到了未分区。
class TodoSectionDeletion {
  const TodoSectionDeletion({
    required this.list,
    required this.todos,
    required this.deletedTodos,
  });

  final TodoListRow list;
  final List<TodoRow> todos;
  final bool deletedTodos;
}

/// 清单分区的读写（口径见 `todo_sections.dart`）。
///
/// 约定：
/// 1. 分区定义改在清单行的 `metadata.sections`、待办所属改在待办的
///    `metadata.sectionId`；每个方法一个事务读改写，只动这一个键，别的键原样
///    保留；值本来就一样的行不写（不平白刷新 `updated_at`）；
/// 2. 局域网同步按清单行整条“后写者胜”：两台设备同时改同一清单的分区时以
///    后写的为准（与改清单名同一粒度），不另做分区级合并；
/// 3. 批量移到分区返回改动前的行，撤销经
///    `restoreTodoFields(before, TodoBatchField.section)`。
mixin _AppDatabaseTodoSectionOps
    on _$AppDatabase, _AppDatabaseTodoQueries, _AppDatabaseTodoOps {
  /// 在清单 [listId] 末尾加一个分区，返回它的 id；清单不存在、名称为空或已满
  /// [TodoSections.maxPerList] 个时为 null。
  Future<String?> addTodoSection(String listId, String name) {
    final normalized = TodoSections.normalizeName(name);
    if (normalized == null) return Future<String?>.value();
    return transaction(() async {
      final list = await _todoListRow(listId);
      if (list == null) return null;
      final sections = TodoSections.ofList(list.metadata);
      if (sections.length >= TodoSections.maxPerList) return null;
      final id = _newBusinessUuid();
      await _writeSections(list, <TodoSection>[
        ...sections,
        TodoSection(id: id, name: normalized),
      ]);
      return id;
    });
  }

  /// 给分区改名（名称规整后为空时不改）。
  Future<void> renameTodoSection(String listId, String sectionId, String name) {
    final normalized = TodoSections.normalizeName(name);
    if (normalized == null) return Future<void>.value();
    return _editSections(listId, (List<TodoSection> sections) {
      return <TodoSection>[
        for (final section in sections)
          section.id == sectionId
              ? section.copyWith(name: normalized)
              : section,
      ];
    });
  }

  /// 把分区往前（[delta] 为负）或往后挪几位，挪到头为止。
  Future<void> moveTodoSection(String listId, String sectionId, int delta) {
    return _editSections(listId, (List<TodoSection> sections) {
      final from = sections.indexWhere((s) => s.id == sectionId);
      if (from < 0) return sections;
      final to = (from + delta).clamp(0, sections.length - 1);
      if (to == from) return sections;
      final next = List<TodoSection>.of(sections);
      next.insert(to, next.removeAt(from));
      return next;
    });
  }

  /// 清单 [listId] 里分区 [sectionId] 下的待办数（含已完成的）。
  Future<int> countTodosInSection(String listId, String sectionId) async =>
      (await _todosInSection(listId, sectionId)).length;

  /// 删除分区：其中的待办移到未分区，或 [withTodos] 时一起删除（含已完成
  /// 的）。返回撤销所需的改动前的样子；清单或分区不存在时为 null。
  Future<TodoSectionDeletion?> deleteTodoSection(
    String listId,
    String sectionId, {
    required bool withTodos,
  }) {
    return transaction(() async {
      final list = await _todoListRow(listId);
      if (list == null) return null;
      final sections = TodoSections.ofList(list.metadata);
      if (!sections.any((s) => s.id == sectionId)) return null;
      final rows = await _todosInSection(listId, sectionId);
      if (withTodos) {
        if (rows.isNotEmpty) {
          await deleteTodos(rows.map((TodoRow row) => row.todoId));
        }
      } else {
        final now = DateTime.now();
        for (final row in rows) {
          await _writeTodoSection(row, null, now);
        }
      }
      await _writeSections(list, <TodoSection>[
        for (final section in sections)
          if (section.id != sectionId) section,
      ]);
      return TodoSectionDeletion(
        list: list,
        todos: rows,
        deletedTodos: withTodos,
      );
    });
  }

  /// 撤销删除分区：清单的分区回到删之前（只写这一个键），待办写回（被删
  /// 的整行插回，移走的回到原分区）。
  Future<void> restoreTodoSection(TodoSectionDeletion deletion) {
    return transaction(() async {
      final current = await _todoListRow(deletion.list.listId);
      if (current == null) return;
      await _writeSections(
        current,
        TodoSections.ofList(deletion.list.metadata),
      );
      if (deletion.deletedTodos) {
        await restoreTodos(deletion.todos);
        return;
      }
      final now = DateTime.now();
      for (final before in deletion.todos) {
        final row = await getTodo(before.todoId);
        if (row == null) continue;
        await _writeTodoSection(
          row,
          TodoSections.idOfTodo(before.metadata),
          now,
        );
      }
    });
  }

  /// 把待办 [todoId] 放进分区 [sectionId]（null 为未分区）。
  Future<void> setTodoSection(String todoId, String? sectionId) {
    return transaction(() async {
      final row = await getTodo(todoId);
      if (row == null) return;
      await _writeTodoSection(row, sectionId, DateTime.now());
    });
  }

  /// 批量放进分区 [sectionId]（null 为未分区），返回改动前的行。
  Future<List<TodoRow>> setTodosSection(
    Iterable<String> todoIds,
    String? sectionId,
  ) {
    final ids = todoIds.toSet().toList(growable: false);
    if (ids.isEmpty) return Future<List<TodoRow>>.value(const <TodoRow>[]);
    return transaction(() async {
      final now = DateTime.now();
      final changed = <TodoRow>[];
      for (final row in await (select(
        todos,
      )..where((t) => t.todoId.isIn(ids))).get()) {
        if (await _writeTodoSection(row, sectionId, now)) changed.add(row);
      }
      return changed;
    });
  }

  /// 拖动排序跨了分区：顺序与分区在同一个事务里写（推送只来一次，被拖的行
  /// 不会先回到原分区再跳过去）。
  Future<void> moveTodoToSection(
    String todoId,
    String? sectionId, {
    String? aboveId,
    String? belowId,
  }) {
    return transaction(() async {
      await moveTodo(todoId, aboveId: aboveId, belowId: belowId);
      final row = await getTodo(todoId);
      if (row != null) await _writeTodoSection(row, sectionId, DateTime.now());
    });
  }

  Future<TodoListRow?> _todoListRow(String listId) => (select(
    todoLists,
  )..where((t) => t.listId.equals(listId))).getSingleOrNull();

  Future<List<TodoRow>> _todosInSection(String listId, String sectionId) async {
    final rows =
        await (select(todos)..where(
              (t) =>
                  t.listId.equals(listId) &
                  t.metadata.like('%"${TodoSections.todoKey}":%'),
            ))
            .get();
    return <TodoRow>[
      for (final row in rows)
        if (TodoSections.idOfTodo(row.metadata) == sectionId) row,
    ];
  }

  Future<void> _editSections(
    String listId,
    List<TodoSection> Function(List<TodoSection> sections) edit,
  ) {
    return transaction(() async {
      final list = await _todoListRow(listId);
      if (list == null) return;
      final sections = TodoSections.ofList(list.metadata);
      final next = edit(sections);
      if (next.length == sections.length &&
          List<int>.generate(
            next.length,
            (i) => i,
          ).every((int i) => next[i] == sections[i])) {
        return;
      }
      await _writeSections(list, next);
    });
  }

  Future<void> _writeSections(TodoListRow list, List<TodoSection> sections) {
    final map = decodeTodoMetadata(list.metadata);
    TodoSections.writeInto(map, sections);
    return (update(todoLists)..where((t) => t.id.equals(list.id))).write(
      TodoListsCompanion(
        metadata: Value(jsonEncode(map)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 写一行的分区；与现在的一样时不写，返回是否写了。
  Future<bool> _writeTodoSection(
    TodoRow row,
    String? sectionId,
    DateTime now,
  ) async {
    if (TodoSections.idOfTodo(row.metadata) == sectionId) return false;
    final map = decodeTodoMetadata(row.metadata);
    if (sectionId == null) {
      map.remove(TodoSections.todoKey);
    } else {
      map[TodoSections.todoKey] = sectionId;
    }
    await (update(todos)..where((t) => t.id.equals(row.id))).write(
      TodosCompanion(metadata: Value(jsonEncode(map)), updatedAt: Value(now)),
    );
    return true;
  }
}
