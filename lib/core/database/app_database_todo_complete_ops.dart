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

/// 取消完成一条待办的结果，供详情切换与撤销。
class TodoUncompletion {
  const TodoUncompletion({required this.before, this.rolledBackSeriesBefore});

  /// 取消完成前的整行（普通待办，或被删除的已完成副本）。
  final TodoRow before;

  /// 若本次取消完成把原重复待办回滚到了这一次的日期，这里保存回滚前的原待办
  /// 整行；普通待办或早期历史记录恢复为单次待办时为 null。
  final TodoRow? rolledBackSeriesBefore;

  /// 是否回滚到了原重复待办。
  bool get rolledBack => rolledBackSeriesBefore != null;

  /// 取消完成后仍留在库里的那条待办业务 id（回滚了即原待办，否则仍是自己）。
  String get resultingTodoId => rolledBackSeriesBefore?.todoId ?? before.todoId;
}

/// 待办的完成、取消完成、步骤勾选与稍后提醒。
///
/// 重复待办完成一次（[completeTodo]，单个事务）：
/// 1. 按规则算出下一个截止日（`TodoRecurrence.nextDueAfterCompletion`）；
/// 2. 有下一次：插一条“已完成的副本”记下这一次（id 由原 id 与这一次的日期
///    决定，见 `todoOccurrenceId`），同时在副本的 `metadata` 里记下推到的下
///    一个截止日（与按完成日重复时的原起点）；原待办的截止日推到下一次、步
///    骤重置为未完成、稍后提醒作废、已完成次数加一；按完成日重复时这串的起
///    点也挪到下一次；
/// 3. 没有下一次（次数用完或过了截止日期）：原待办直接标为完成，不另插副本。
/// 撤销（[undoTodoCompletion]）把原行写回完成前的样子并删掉副本。
///
/// 取消完成（[uncompleteTodo]，单个事务）：
/// 1. 若是重复待办最近一次的已完成副本，且原待办仍未完成、仍有重复规则、并
///    停在这次完成推到的那一天：把原待办退回这一次的日期（恢复未改动的步骤、
///    按完成日重复时的原起点与已完成次数）并删掉副本，保持完成 ↔ 取消完成
///    对称可逆；
/// 2. 若是更早的历史副本（原待办已经继续推进或被修改 / 删除）：不破坏原计
///    划，把这一条副本恢复为该日的单次未完成待办；
/// 3. 若是有限次数 / 截止日重复待办的最后一次（直接完成在原行上）：清掉完
///    成时间并把已完成次数减一。
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

  /// 取消完成；不存在或本来就未完成时为 null。规则见本 mixin 说明。
  Future<TodoUncompletion?> uncompleteTodo(String todoId, {DateTime? now}) {
    return transaction(() async {
      final row = await getTodo(todoId);
      if (row == null || row.completedAt == null) return null;
      final at = now ?? DateTime.now();
      final meta = decodeTodoMetadata(row.metadata);
      final seriesId = meta[TodoMetadataKeys.repeatOf];
      if (seriesId is String && seriesId.isNotEmpty) {
        final series = await getTodo(seriesId);
        if (series != null && await _canRollbackOccurrence(row, meta, series)) {
          await _rollbackSeriesToOccurrence(series, row, meta, at);
          await (delete(todos)..where((t) => t.id.equals(row.id))).go();
          return TodoUncompletion(before: row, rolledBackSeriesBefore: series);
        }
      }
      Value<String> nextMetadata = const Value.absent();
      if (decodeTodoRepeat(row.repeat) != null) {
        final done = meta[TodoMetadataKeys.repeatDone];
        if (done is int && done > 0) {
          meta[TodoMetadataKeys.repeatDone] = done - 1;
          nextMetadata = Value(jsonEncode(meta));
        }
      }
      await (update(todos)..where((t) => t.id.equals(row.id))).write(
        TodosCompanion(
          completedAt: const Value(null),
          metadata: nextMetadata,
          updatedAt: Value(at),
        ),
      );
      return TodoUncompletion(before: row);
    });
  }

  /// 撤销 [uncompleteTodo]：回滚过原重复待办时把原待办与已完成副本一起写回
  /// 取消前的样子；否则写回完成时间（与有限次数的已完成次数），期间又被完
  /// 成过的不动。
  Future<void> undoTodoUncompletion(TodoUncompletion uncompletion) {
    return transaction(() async {
      final now = DateTime.now();
      final seriesBefore = uncompletion.rolledBackSeriesBefore;
      if (seriesBefore != null) {
        await into(todos).insertOnConflictUpdate(
          seriesBefore.copyWith(updatedAt: now).toCompanion(false),
        );
        await into(todos).insertOnConflictUpdate(
          uncompletion.before.copyWith(updatedAt: now).toCompanion(false),
        );
        return;
      }
      final completedAt = uncompletion.before.completedAt;
      if (completedAt == null) return;
      await (update(todos)..where(
            (t) =>
                t.todoId.equals(uncompletion.before.todoId) &
                t.completedAt.isNull(),
          ))
          .write(
            TodosCompanion(
              completedAt: Value(completedAt),
              metadata: Value(uncompletion.before.metadata),
              updatedAt: Value(now),
            ),
          );
    });
  }

  /// 撤销简单的取消完成：把完成时间写回 [completedAt]（只写这一列外加
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

  /// 已完成副本 [occurrence] 能否安全回滚到原待办 [series]：原待办必须仍未
  /// 完成、仍有重复规则、且仍停在这次完成推进到的那一天（兼容升级前未写
  /// `repeatNextDue` 的旧副本）。
  Future<bool> _canRollbackOccurrence(
    TodoRow occurrence,
    Map<String, Object?> meta,
    TodoRow series,
  ) async {
    if (series.completedAt != null) return false;
    final seriesDueText = series.dueDate;
    final occurrenceDueText = occurrence.dueDate;
    if (seriesDueText == null || occurrenceDueText == null) return false;
    final rule = decodeTodoRepeat(series.repeat);
    if (rule == null) return false;
    final recordedNext = meta[TodoMetadataKeys.repeatNextDue];
    if (recordedNext is String && recordedNext.isNotEmpty) {
      return seriesDueText == recordedNext;
    }
    final due = parseAnniversaryDate(occurrenceDueText);
    final seriesDue = parseAnniversaryDate(seriesDueText);
    if (due == null || seriesDue == null || !seriesDue.isAfter(due)) {
      return false;
    }
    // 旧副本兜底：不能已有更晚的已完成副本，否则回滚会把原待办倒拖到已完成的
    // 周期之前。
    final newer =
        await (select(todos)
              ..where(
                (t) =>
                    _todoOccurrenceOf(t, series.todoId) &
                    t.id.equals(occurrence.id).not() &
                    t.dueDate.isBiggerThanValue(occurrenceDueText),
              )
              ..limit(1))
            .get();
    if (newer.isNotEmpty) return false;
    final completedAt = occurrence.completedAt!;
    final expected = TodoRecurrence.nextDueAfterCompletion(
      rule,
      currentDue: due,
      completedOn: DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      ),
      // 原待办已经成功推进，这里只校验日期衔接，不受 count 上限截断。
      doneCount: 0,
    );
    return expected != null && formatAnniversaryDate(expected) == seriesDueText;
  }

  Future<void> _rollbackSeriesToOccurrence(
    TodoRow series,
    TodoRow occurrence,
    Map<String, Object?> occurrenceMeta,
    DateTime at,
  ) async {
    final seriesMeta = decodeTodoMetadata(series.metadata);
    final done = seriesMeta[TodoMetadataKeys.repeatDone];
    Value<String> nextMetadata = const Value.absent();
    if (done is int && done > 0) {
      seriesMeta[TodoMetadataKeys.repeatDone] = done - 1;
      nextMetadata = Value(jsonEncode(seriesMeta));
    }
    Value<String?> nextRepeat = const Value.absent();
    final rule = decodeTodoRepeat(series.repeat);
    if (rule != null && rule.basis == TodoRepeatBasis.completion) {
      final rawPrevAnchor = occurrenceMeta[TodoMetadataKeys.repeatPrevAnchor];
      final prevAnchor = rawPrevAnchor is String
          ? parseAnniversaryDate(rawPrevAnchor)
          : parseAnniversaryDate(occurrence.dueDate!);
      if (prevAnchor != null) {
        nextRepeat = Value(encodeTodoRepeat(rule.copyWith(anchor: prevAnchor)));
      }
    }
    // 只有原待办下一次的步骤还没被勾过时，才恢复完成前的步骤勾选快照，避免覆
    // 盖用户已经为下一次勾好的步骤。
    final seriesSteps = decodeTodoSteps(series.steps);
    final occurrenceSteps = decodeTodoSteps(occurrence.steps);
    final Value<String> nextSteps =
        occurrenceSteps.isNotEmpty && !seriesSteps.any((step) => step.done)
        ? Value(occurrence.steps)
        : const Value.absent();
    await (update(todos)..where((t) => t.id.equals(series.id))).write(
      TodosCompanion(
        dueDate: Value(occurrence.dueDate),
        repeat: nextRepeat,
        steps: nextSteps,
        snoozedUntil: const Value(null),
        metadata: nextMetadata,
        updatedAt: Value(at),
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
    final nextText = formatAnniversaryDate(next);
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
        // 副本带着这一次的标签、分区以及回滚原待办所需的锚点；repeatOf 必须
        // 是第一个键，`watchTodoOccurrences` 按这一段匹配。
        metadata: Value(
          jsonEncode(<String, Object?>{
            TodoMetadataKeys.repeatOf: row.todoId,
            TodoMetadataKeys.repeatNextDue: nextText,
            if (rule.basis == TodoRepeatBasis.completion)
              TodoMetadataKeys.repeatPrevAnchor: formatAnniversaryDate(
                rule.anchor,
              ),
            if (TodoTags.fromMetadata(metadata) case final tags
                when tags.isNotEmpty)
              TodoTags.metadataKey: tags,
            if (metadata[TodoSections.todoKey] case final String section)
              TodoSections.todoKey: section,
          }),
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
        dueDate: Value(nextText),
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
