part of 'app_database.dart';

/// 完成一条待办的结果，供撤销与提示。
class TodoCompletion {
  const TodoCompletion({required this.before, this.copyId, this.nextDue});

  /// 完成前的整行。
  final TodoRow before;

  /// 重复待办这一次的已完成副本的业务 id；不重复或这串已结束时为 null。
  final String? copyId;

  /// 重复待办推到的下一个截止日；不重复或这串已结束时为 null。
  final DateTime? nextDue;

  /// 是否推到了下一次（原待办仍未完成）。
  bool get advanced => nextDue != null;
}

/// 待办的完成、取消完成、步骤勾选与稍后提醒。
///
/// 重复待办完成一次（[completeTodo]，单个事务）：
/// 1. 按规则算出下一个截止日（`TodoRecurrence.nextDueAfterCompletion`）；
/// 2. 有下一次：插一条“已完成的副本”记下这一次（id 由原 id 与这一次的日期
///    决定，见 `todoOccurrenceId`），原待办的截止日推到下一次、步骤重置为
///    未完成、稍后提醒作废、已完成次数加一；按完成日重复时这串的起点也挪到
///    下一次；
/// 3. 没有下一次（次数用完或过了截止日期）：原待办直接标为完成，不另插副本。
/// 撤销（[undoTodoCompletion]）把原行写回完成前的样子并删掉副本。
mixin _AppDatabaseTodoCompleteOps on _$AppDatabase, _AppDatabaseTodoQueries {
  /// 完成一条待办；不存在或已完成时为 null。[now] 只供测试注入。
  Future<TodoCompletion?> completeTodo(String todoId, {DateTime? now}) {
    return transaction(() async {
      final row = await getTodo(todoId);
      if (row == null || row.completedAt != null) return null;
      return _completeTodoRow(row, now ?? DateTime.now());
    });
  }

  /// 撤销 [completeTodo]：原行写回完成前的样子（`updated_at` 取现在，这次
  /// 撤销本身是一次新的编辑），删掉这一次的副本。
  Future<void> undoTodoCompletion(TodoCompletion completion) {
    return transaction(() async {
      await into(todos).insertOnConflictUpdate(
        completion.before
            .copyWith(updatedAt: DateTime.now())
            .toCompanion(false),
      );
      final copyId = completion.copyId;
      if (copyId != null) {
        await (delete(todos)..where((t) => t.todoId.equals(copyId))).go();
      }
    });
  }

  /// 取消完成。重复待办的已完成副本取消后成为一条普通的未完成待办。
  Future<void> uncompleteTodo(String todoId) {
    return (update(todos)..where((t) => t.todoId.equals(todoId))).write(
      TodosCompanion(
        completedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 撤销 [uncompleteTodo]：把完成时间写回 [completedAt]（只写这一列外加
  /// `updated_at`；撤销本身是一次新的编辑，同步时要盖过刚才的取消完成）。
  /// 期间又被完成过的不动。
  Future<void> restoreTodoCompletedAt(String todoId, DateTime completedAt) {
    return (update(
      todos,
    )..where((t) => t.todoId.equals(todoId) & t.completedAt.isNull())).write(
      TodosCompanion(
        completedAt: Value(completedAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 勾选 / 取消勾选一个步骤；步骤不存在时不写。
  Future<void> setTodoStepDone(String todoId, String stepId, bool done) {
    return transaction(() async {
      final row = await getTodo(todoId);
      if (row == null) return;
      final steps = decodeTodoSteps(row.steps);
      final index = steps.indexWhere((step) => step.id == stepId);
      if (index < 0 || steps[index].done == done) return;
      steps[index] = steps[index].copyWith(done: done);
      await (update(todos)..where((t) => t.id.equals(row.id))).write(
        TodosCompanion(
          steps: Value(encodeTodoSteps(steps)),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// 稍后提醒：到 [until] 再提醒一次（null 为取消）。已完成的不写。
  Future<void> snoozeTodo(String todoId, DateTime? until) {
    return (update(
      todos,
    )..where((t) => t.todoId.equals(todoId) & t.completedAt.isNull())).write(
      TodosCompanion(
        snoozedUntil: Value(until),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 完成一条未完成的待办（[row] 为刚在同一事务里读出的整行），规则见本
  /// mixin 的说明。调用方负责开事务并先排除不存在与已完成的：单条的
  /// [completeTodo] 与批量的 `completeTodos` 共用这一份，两条路径的结果逐字
  /// 段一致。
  Future<TodoCompletion> _completeTodoRow(TodoRow row, DateTime at) async {
    final rule = decodeTodoRepeat(row.repeat);
    final dueText = row.dueDate;
    final due = dueText == null ? null : parseAnniversaryDate(dueText);
    if (rule == null || due == null || dueText == null) {
      await _markTodoDone(row, at);
      return TodoCompletion(before: row);
    }
    final metadata = decodeTodoMetadata(row.metadata);
    final previousDone = metadata[TodoMetadataKeys.repeatDone];
    final done = (previousDone is int ? previousDone : 0) + 1;
    metadata[TodoMetadataKeys.repeatDone] = done;
    final next = TodoRecurrence.nextDueAfterCompletion(
      rule,
      currentDue: due,
      completedOn: DateTime(at.year, at.month, at.day),
      doneCount: done,
    );
    if (next == null) {
      await _markTodoDone(row, at, metadata: metadata);
      return TodoCompletion(before: row);
    }
    final copyId = todoOccurrenceId(row.todoId, dueText);
    await into(todos).insertOnConflictUpdate(
      TodosCompanion.insert(
        todoId: copyId,
        listId: Value(row.listId),
        title: row.title,
        note: Value(row.note),
        priority: Value(row.priority),
        dueDate: Value(dueText),
        dueMinute: Value(row.dueMinute),
        steps: Value(row.steps),
        completedAt: Value(at),
        linkedDiaryId: Value(row.linkedDiaryId),
        sortOrder: Value(row.sortOrder),
        metadata: Value(
          jsonEncode(<String, Object?>{TodoMetadataKeys.repeatOf: row.todoId}),
        ),
        createdAt: at,
        updatedAt: at,
      ),
    );
    final nextRule = rule.basis == TodoRepeatBasis.completion
        ? rule.copyWith(anchor: next)
        : rule;
    await (update(todos)..where((t) => t.id.equals(row.id))).write(
      TodosCompanion(
        dueDate: Value(formatAnniversaryDate(next)),
        repeat: Value(encodeTodoRepeat(nextRule)),
        steps: Value(
          encodeTodoSteps(<TodoStep>[
            for (final step in decodeTodoSteps(row.steps))
              step.copyWith(done: false),
          ]),
        ),
        snoozedUntil: const Value(null),
        metadata: Value(jsonEncode(metadata)),
        updatedAt: Value(at),
      ),
    );
    return TodoCompletion(before: row, copyId: copyId, nextDue: next);
  }

  Future<void> _markTodoDone(
    TodoRow row,
    DateTime at, {
    Map<String, Object?>? metadata,
  }) {
    return (update(todos)..where((t) => t.id.equals(row.id))).write(
      TodosCompanion(
        completedAt: Value(at),
        snoozedUntil: const Value(null),
        metadata: metadata == null
            ? const Value.absent()
            : Value(jsonEncode(metadata)),
        updatedAt: Value(at),
      ),
    );
  }
}
