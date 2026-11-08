part of 'app_database.dart';

/// [_AppDatabaseTodoBatchOps.restoreTodoFields] 写回的字段组。
enum TodoBatchField {
  /// 截止日、截止时刻、提醒、重复与稍后提醒：批量改日期会连带去掉重复、
  /// 改为全天时去掉只对有时刻的待办有效的提醒、作废稍后提醒，撤销要一起
  /// 写回。
  due,

  /// 所在清单与拖动顺序（移到别的清单时排到那里的最前）。
  list,

  /// 优先级。
  priority,
}

/// 待办的批量写入：多选后的完成、改日期 / 清单 / 优先级，以及它们的撤销。
///
/// 输入：选中的待办业务 id（重复的只算一次，不存在的跳过）；输出：撤销所需
/// 的完成结果或改动前的整行。
///
/// 约定：
/// 1. 每个方法各在一个事务里执行（watch 流只推送一次，提醒只重排一次），
///    空列表直接返回、不开事务；
/// 2. 每行的规则与单条方法完全一致，并复用单条方法的事务内写法
///    （`_completeTodoRow`、`_todoDueChange`、`_topTodoOrder`）；
/// 3. 逐项修改每行只写这一组列外加 `updated_at`，不整行写回；值本来就相同
///    的行不写：局域网同步按整条记录“后写者胜”，平白刷新 `updated_at` 会让
///    这台设备上没改过的旧值盖掉另一台设备在别的字段上的编辑；
/// 4. 改日期 / 清单 / 优先级返回真正改动了的行（改动前的样子），撤销经
///    [restoreTodoFields] 只把那一组列写回；批量完成的撤销由调用方倒序逐条
///    `undoTodoCompletion`；批量删除沿用 `deleteTodos`（单条删除也经它，
///    见 `_AppDatabaseTodoOps`），撤销经 `restoreTodos`。
mixin _AppDatabaseTodoBatchOps
    on
        _$AppDatabase,
        _AppDatabaseTodoQueries,
        _AppDatabaseTodoOps,
        _AppDatabaseTodoCompleteOps {
  /// 批量完成，返回各条的完成结果（按给出的顺序，跳过不存在与已完成的）。
  /// 每条与 [completeTodo] 同一套规则：重复待办推到下一次并插入这一次的已
  /// 完成副本。[now] 只供测试注入。
  ///
  /// 逐条在事务里现读现写，等同于依次调用 [completeTodo]：前一条插入的副本
  /// 恰好也在选中里时，读到的是插入后（已完成）的样子而被跳过。撤销时倒序
  /// 逐条 [undoTodoCompletion]，后完成的先撤，副本与原行的先后关系不会乱。
  Future<List<TodoCompletion>> completeTodos(
    Iterable<String> todoIds, {
    DateTime? now,
  }) {
    final ids = todoIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return Future<List<TodoCompletion>>.value(const <TodoCompletion>[]);
    }
    return transaction(() async {
      final at = now ?? DateTime.now();
      final results = <TodoCompletion>[];
      for (final id in ids) {
        final row = await getTodo(id);
        if (row == null || row.completedAt != null) continue;
        results.add(await _completeTodoRow(row, at));
      }
      return results;
    });
  }

  /// 批量改截止日与截止时刻，返回改动前的行（供 [restoreTodoFields] 以
  /// [TodoBatchField.due] 撤销）。
  ///
  /// 每行与 [setTodoDue] 同一套规则（去掉日期连带去掉重复、有重复时起点挪到
  /// 新日期、稍后提醒作废）；另外改为全天（[date] 不为空且 [minute] 为
  /// null）时去掉“准时 / 提前若干分钟”这类只对有时刻的待办有效的提醒，只
  /// 留 [TodoReminderKind.onDay]。日期、时刻都没变且没有要去掉的提醒的行
  /// 不写。
  Future<List<TodoRow>> setTodosDue(
    Iterable<String> todoIds, {
    DateTime? date,
    int? minute,
  }) {
    final ids = todoIds.toSet().toList(growable: false);
    if (ids.isEmpty) return Future<List<TodoRow>>.value(const <TodoRow>[]);
    return transaction(() async {
      final dueText = date == null ? null : formatAnniversaryDate(date);
      final dueMinute = date == null ? null : minute;
      final allDay = date != null && minute == null;
      final now = DateTime.now();
      final changed = <TodoRow>[];
      for (final row in await _todosByIds(ids)) {
        var change = _todoDueChange(row, date: date, minute: minute);
        var remindersChanged = false;
        if (allDay) {
          // 与详情页改日期时同一口径：按解码后的提醒过滤，条数变了才写。
          final reminders = decodeTodoReminders(row.reminders);
          final kept = <TodoReminder>[
            for (final reminder in reminders)
              if (reminder.kind == TodoReminderKind.onDay) reminder,
          ];
          if (kept.length != reminders.length) {
            change = change.copyWith(
              reminders: Value(encodeTodoReminders(kept)),
            );
            remindersChanged = true;
          }
        }
        if (!remindersChanged &&
            row.dueDate == dueText &&
            row.dueMinute == dueMinute) {
          continue;
        }
        await (update(todos)..where((t) => t.id.equals(row.id))).write(
          change.copyWith(updatedAt: Value(now)),
        );
        changed.add(row);
      }
      return changed;
    });
  }

  /// 批量移到另一个清单（[listId] 为 null 即收集箱），返回改动前的行（供
  /// [restoreTodoFields] 以 [TodoBatchField.list] 撤销）。
  ///
  /// 与 [setTodoListId] 一样排到目标清单的最前面；几条之间保持搬之前的先后
  /// （按拖动顺序），与批量新建同一写法：倒序逐条放到当前最前。已经在目标
  /// 清单里的行不动（不刷新 `updated_at`，也不被挪到最前）。
  Future<List<TodoRow>> setTodosListId(
    Iterable<String> todoIds,
    String? listId,
  ) {
    final ids = todoIds.toSet().toList(growable: false);
    if (ids.isEmpty) return Future<List<TodoRow>>.value(const <TodoRow>[]);
    return transaction(() async {
      final moving = <TodoRow>[
        for (final row in await _todosByIds(ids))
          if (row.listId != listId) row,
      ];
      if (moving.isEmpty) return moving;
      final now = DateTime.now();
      var top = await _topTodoOrder(listId);
      for (final row in moving.reversed) {
        final order = TodoSortOrder.between(null, top)!;
        top = order;
        await (update(todos)..where((t) => t.id.equals(row.id))).write(
          TodosCompanion(
            listId: Value(listId),
            sortOrder: Value(order),
            updatedAt: Value(now),
          ),
        );
      }
      return moving;
    });
  }

  /// 批量改优先级，返回改动前的行（供 [restoreTodoFields] 以
  /// [TodoBatchField.priority] 撤销）；优先级本来就相同的行不写。
  Future<List<TodoRow>> setTodosPriority(
    Iterable<String> todoIds,
    TodoPriority priority,
  ) {
    final ids = todoIds.toSet().toList(growable: false);
    if (ids.isEmpty) return Future<List<TodoRow>>.value(const <TodoRow>[]);
    return transaction(() async {
      final changed = <TodoRow>[
        for (final row in await _todosByIds(ids))
          if (row.priority != priority.index) row,
      ];
      if (changed.isEmpty) return changed;
      await (update(
        todos,
      )..where((t) => t.id.isIn(changed.map((row) => row.id)))).write(
        TodosCompanion(
          priority: Value(priority.index),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return changed;
    });
  }

  /// 撤销批量改日期 / 清单 / 优先级：把 [before] 里每行的 [field] 那一组列
  /// 写回原值，并刷新 `updated_at`（撤销本身是一次新的编辑，同步时要盖过
  /// 刚才那次改动）。按业务 id 定位，行已不存在时跳过；撤销清单时原清单已
  /// 被删除的行也跳过（不写出指向不存在清单的悬空引用），留在现在的清单。
  Future<void> restoreTodoFields(List<TodoRow> before, TodoBatchField field) {
    if (before.isEmpty) return Future<void>.value();
    return transaction(() async {
      final liveListIds = field == TodoBatchField.list
          ? await _liveTodoListIds(before)
          : null;
      final now = DateTime.now();
      for (final row in before) {
        final listId = row.listId;
        if (listId != null &&
            liveListIds != null &&
            !liveListIds.contains(listId)) {
          continue;
        }
        final change = switch (field) {
          TodoBatchField.due => TodosCompanion(
            dueDate: Value(row.dueDate),
            dueMinute: Value(row.dueMinute),
            reminders: Value(row.reminders),
            repeat: Value(row.repeat),
            snoozedUntil: Value(row.snoozedUntil),
          ),
          TodoBatchField.list => TodosCompanion(
            listId: Value(row.listId),
            sortOrder: Value(row.sortOrder),
          ),
          TodoBatchField.priority => TodosCompanion(
            priority: Value(row.priority),
          ),
        };
        await (update(todos)..where((t) => t.todoId.equals(row.todoId))).write(
          change.copyWith(updatedAt: Value(now)),
        );
      }
    });
  }

  /// [rows] 所在的清单里仍然存在的那些（业务 id；收集箱不是一行，不在内）。
  Future<Set<String>> _liveTodoListIds(List<TodoRow> rows) async {
    final wanted = <String>{
      for (final row in rows)
        if (row.listId case final String id) id,
    };
    if (wanted.isEmpty) return <String>{};
    final query = selectOnly(todoLists)
      ..addColumns(<Expression<Object>>[todoLists.listId])
      ..where(todoLists.listId.isIn(wanted));
    return <String>{
      for (final row in await query.get()) row.read(todoLists.listId)!,
    };
  }

  /// 按业务 id 读出的行，按拖动顺序（与列表里看到的先后一致）。
  Future<List<TodoRow>> _todosByIds(List<String> ids) {
    return (select(todos)
          ..where((t) => t.todoId.isIn(ids))
          ..orderBy(_todoManualOrder()))
        .get();
  }
}
