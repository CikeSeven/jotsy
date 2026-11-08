part of 'app_database.dart';

/// 新建一条待办时的字段。
class TodoInput {
  const TodoInput({
    required this.title,
    this.listId,
    this.note = '',
    this.priority = TodoPriority.none,
    this.dueDate,
    this.dueMinute,
    this.reminders = const <TodoReminder>[],
    this.repeat,
    this.steps = const <TodoStep>[],
    this.linkedDiaryId,
    this.sourceDiaryId,
  });

  final String title;
  final String? listId;
  final String note;
  final TodoPriority priority;

  /// 截止日（只取年月日）。
  final DateTime? dueDate;

  /// 截止时刻（一天中的分钟数）；没有 [dueDate] 时忽略。
  final int? dueMinute;
  final List<TodoReminder> reminders;
  final TodoRepeatRule? repeat;
  final List<TodoStep> steps;
  final String? linkedDiaryId;

  /// 从哪篇日记转来（写进 `metadata`）。
  final String? sourceDiaryId;
}

/// 待办写入：新建、逐项修改、拖动排序与删除（查询见 `_AppDatabaseTodoQueries`）。
///
/// 输入：界面整理好的字段；输出：drift watch 流与业务 id。逐项修改的方法
/// 每次只写一列（外加 `updated_at`）：详情页改一项就写一项，局域网同步按整行
/// “后写的为准”合并时，不会把另一台设备在别的字段上的改动连带写回旧值。
/// 删除是硬删除，撤销由调用方持有被删的整行、经 [restoreTodos] 原样写回。
/// 完成 / 取消完成 / 稍后提醒见 `_AppDatabaseTodoCompleteOps`。
mixin _AppDatabaseTodoOps on _$AppDatabase, _AppDatabaseTodoQueries {
  /// 新建一条待办（排在所在清单最前），返回业务 id。
  Future<String> createTodo(TodoInput input) async {
    final ids = await createTodos(<TodoInput>[input]);
    return ids.single;
  }

  /// 批量新建（如从日记里的待办块转来），同一事务；按给出的顺序排在所在
  /// 清单的最前面。
  Future<List<String>> createTodos(List<TodoInput> inputs) {
    return transaction(() async {
      final now = DateTime.now();
      final ids = <String>[];
      final topByList = <String?, double?>{};
      // 倒序插入，每条都放到当前最前：插完后的顺序与给出的顺序一致。
      final created = <TodosCompanion>[];
      for (final input in inputs.reversed) {
        final key = input.listId;
        final top = topByList.containsKey(key)
            ? topByList[key]
            : await _topTodoOrder(key);
        final order = TodoSortOrder.between(null, top)!;
        topByList[key] = order;
        final id = _newBusinessUuid();
        ids.add(id);
        final due = input.dueDate;
        created.add(
          TodosCompanion.insert(
            todoId: id,
            listId: Value(input.listId),
            title: _normalizeTodoTitle(input.title),
            note: Value(input.note.trim()),
            priority: Value(input.priority.index),
            dueDate: Value(due == null ? null : formatAnniversaryDate(due)),
            dueMinute: Value(due == null ? null : input.dueMinute),
            reminders: Value(encodeTodoReminders(input.reminders)),
            repeat: Value(due == null ? null : encodeTodoRepeat(input.repeat)),
            steps: Value(encodeTodoSteps(input.steps)),
            linkedDiaryId: Value(input.linkedDiaryId),
            sortOrder: Value(order),
            metadata: Value(
              jsonEncode(<String, Object?>{
                if (input.sourceDiaryId != null)
                  TodoMetadataKeys.sourceDiaryId: input.sourceDiaryId,
              }),
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await batch((batch) => batch.insertAll(todos, created));
      return ids.reversed.toList(growable: false);
    });
  }

  Future<void> setTodoTitle(String todoId, String title) => _writeTodo(
    todoId,
    TodosCompanion(title: Value(_normalizeTodoTitle(title))),
  );

  Future<void> setTodoNote(String todoId, String note) =>
      _writeTodo(todoId, TodosCompanion(note: Value(note.trim())));

  Future<void> setTodoPriority(String todoId, TodoPriority priority) =>
      _writeTodo(todoId, TodosCompanion(priority: Value(priority.index)));

  /// 移到另一个清单（[listId] 为 null 即收集箱），排在那里的最前面。
  Future<void> setTodoListId(String todoId, String? listId) {
    return transaction(() async {
      final top = await _topTodoOrder(listId);
      await _writeTodo(
        todoId,
        TodosCompanion(
          listId: Value(listId),
          sortOrder: Value(TodoSortOrder.between(null, top)!),
        ),
      );
    });
  }

  /// 改截止日与截止时刻。去掉日期时一并去掉重复（重复必须有日期）；有重复
  /// 时把这串的起点挪到新的截止日，之后按新日子排定（“每月 31 号”改到 15 号
  /// 就是每月 15 号）。改了日期，之前的稍后提醒也作废。
  Future<void> setTodoDue(String todoId, {DateTime? date, int? minute}) {
    return transaction(() async {
      final row = await getTodo(todoId);
      if (row == null) return;
      await _writeTodo(todoId, _todoDueChange(row, date: date, minute: minute));
    });
  }

  Future<void> setTodoReminders(String todoId, List<TodoReminder> reminders) =>
      _writeTodo(
        todoId,
        TodosCompanion(reminders: Value(encodeTodoReminders(reminders))),
      );

  /// 设定重复（null 为不重复）。调用方保证待办已有截止日。
  Future<void> setTodoRepeat(String todoId, TodoRepeatRule? rule) =>
      _writeTodo(todoId, TodosCompanion(repeat: Value(encodeTodoRepeat(rule))));

  Future<void> setTodoSteps(String todoId, List<TodoStep> steps) =>
      _writeTodo(todoId, TodosCompanion(steps: Value(encodeTodoSteps(steps))));

  Future<void> setTodoLinkedDiary(String todoId, String? diaryId) =>
      _writeTodo(todoId, TodosCompanion(linkedDiaryId: Value(diaryId)));

  /// 把待办拖到同一清单里 [aboveId] 与 [belowId] 之间（都可空：拖到最前 /
  /// 最后）。
  Future<void> moveTodo(String todoId, {String? aboveId, String? belowId}) {
    return transaction(() async {
      final row = await getTodo(todoId);
      if (row == null) return;
      Future<double?> orderOf(String? id) async =>
          id == null ? null : (await getTodo(id))?.sortOrder;
      var value = TodoSortOrder.between(
        await orderOf(aboveId),
        await orderOf(belowId),
      );
      if (value == null) {
        await _renumberTodoList(row.listId);
        value =
            TodoSortOrder.between(
              await orderOf(aboveId),
              await orderOf(belowId),
            ) ??
            0;
      }
      await _writeTodo(todoId, TodosCompanion(sortOrder: Value(value)));
    });
  }

  /// 删除并返回被删的整行（供撤销）；不存在时返回 null。
  Future<TodoRow?> deleteTodo(String todoId) async {
    final rows = await deleteTodos(<String>[todoId]);
    return rows.isEmpty ? null : rows.single;
  }

  /// 批量删除，返回被删的行（供撤销）。
  Future<List<TodoRow>> deleteTodos(Iterable<String> todoIds) {
    final ids = todoIds.toSet().toList(growable: false);
    if (ids.isEmpty) return Future<List<TodoRow>>.value(const <TodoRow>[]);
    return transaction(() async {
      final rows = await (select(
        todos,
      )..where((t) => t.todoId.isIn(ids))).get();
      await (delete(todos)..where((t) => t.todoId.isIn(ids))).go();
      return rows;
    });
  }

  /// 删除已完成的待办（[listId] 给出时只删那个清单的；[allLists] 为 true 时
  /// 不论清单），返回被删的行（供撤销）。
  Future<List<TodoRow>> deleteCompletedTodos({
    String? listId,
    bool allLists = false,
  }) {
    return transaction(() async {
      final query = select(todos)
        ..where((t) {
          final done = t.completedAt.isNotNull();
          if (allLists) return done;
          return done &
              (listId == null ? t.listId.isNull() : t.listId.equals(listId));
        });
      final rows = await query.get();
      if (rows.isEmpty) return rows;
      await (delete(
        todos,
      )..where((t) => t.id.isIn(rows.map((r) => r.id)))).go();
      return rows;
    });
  }

  /// 撤销删除：按原 id 与业务 id 写回整行，排序与关联都与删除前一致。
  Future<void> restoreTodos(Iterable<TodoRow> rows) {
    return transaction(() async {
      for (final row in rows) {
        await into(todos).insertOnConflictUpdate(row.toCompanion(false));
      }
    });
  }

  /// 把 [row] 的截止日改为 [date]、截止时刻改为 [minute] 时要写的列（不含
  /// `updated_at`），规则见 [setTodoDue]；单条与批量的 `setTodosDue` 共用。
  TodosCompanion _todoDueChange(
    TodoRow row, {
    required DateTime? date,
    required int? minute,
  }) {
    String? repeat = row.repeat;
    if (date == null) {
      repeat = null;
    } else {
      final rule = decodeTodoRepeat(row.repeat);
      if (rule != null) {
        repeat = encodeTodoRepeat(
          rule.copyWith(anchor: DateTime(date.year, date.month, date.day)),
        );
      }
    }
    return TodosCompanion(
      dueDate: Value(date == null ? null : formatAnniversaryDate(date)),
      dueMinute: Value(date == null ? null : minute),
      repeat: Value(repeat),
      snoozedUntil: const Value(null),
    );
  }

  Future<void> _writeTodo(String todoId, TodosCompanion change) {
    return (update(todos)..where((t) => t.todoId.equals(todoId))).write(
      change.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  /// 清单（null 为收集箱）里最靠前的 `sort_order`；清单为空时为 null。
  Future<double?> _topTodoOrder(String? listId) async {
    final minOrder = todos.sortOrder.min();
    final query = selectOnly(todos)
      ..addColumns(<Expression<Object>>[minOrder])
      ..where(
        listId == null ? todos.listId.isNull() : todos.listId.equals(listId),
      );
    final row = await query.getSingle();
    return row.read(minOrder);
  }

  /// 按现有顺序给清单里的全部待办重新编号（间隔 [TodoSortOrder.gap]）。
  /// 只改排序列、不刷新 `updated_at`：顺序本身没变，不该在同步里算作新编辑。
  Future<void> _renumberTodoList(String? listId) async {
    final rows =
        await (select(todos)
              ..where(
                (t) => listId == null
                    ? t.listId.isNull()
                    : t.listId.equals(listId),
              )
              ..orderBy(_todoManualOrder()))
            .get();
    for (var i = 0; i < rows.length; i++) {
      await (update(todos)..where((t) => t.id.equals(rows[i].id))).write(
        TodosCompanion(sortOrder: Value(i * TodoSortOrder.gap)),
      );
    }
  }

  String _normalizeTodoTitle(String raw) {
    final title = raw.trim();
    if (title.isEmpty) {
      throw const FormatException('待办内容不能为空');
    }
    return title.length > 500 ? title.substring(0, 500) : title;
  }
}
