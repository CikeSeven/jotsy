part of 'app_database.dart';

/// 把 [row] 的截止日改为 [date]、截止时刻改为 [minute] 时要写的列（不含
/// `updated_at`），规则见 `setTodoDue`；单条与批量的 `setTodosDue` 共用。
///
/// 推迟次数：未完成的待办从一个日子改到更晚的日子时，`metadata` 里的
/// [TodoMetadataKeys.postponeCount] 加一（只读改这一个键，别的键原样保留）；
/// 改早、改到同一天只换时刻、去掉日期或第一次设日期都不算。撤销改期时
/// （`restoreTodoFields` 的 due 一组）次数回到原值。
TodosCompanion _todoDueChangeFor(
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
  final nextText = date == null ? null : formatAnniversaryDate(date);
  final before = row.dueDate;
  final postponed =
      row.completedAt == null &&
      before != null &&
      nextText != null &&
      nextText.compareTo(before) > 0;
  Value<String> metadata = const Value.absent();
  if (postponed) {
    final map = decodeTodoMetadata(row.metadata);
    final count = map[TodoMetadataKeys.postponeCount];
    map[TodoMetadataKeys.postponeCount] = (count is int ? count : 0) + 1;
    metadata = Value(jsonEncode(map));
  }
  return TodosCompanion(
    dueDate: Value(nextText),
    dueMinute: Value(date == null ? null : minute),
    repeat: Value(repeat),
    snoozedUntil: const Value(null),
    metadata: metadata,
  );
}

/// 一行待办的截止日被往后推过几次（见 [_todoDueChangeFor]）。
int todoPostponeCount(TodoRow row) {
  final count = decodeTodoMetadata(
    row.metadata,
  )[TodoMetadataKeys.postponeCount];
  return count is int && count > 0 ? count : 0;
}

/// 备注里的清单行：`- [ ] 买菜`、`* [x] 订票`、`[ ] 打电话`（方括号里空格为
/// 未完成，`x` / `X` 为已完成）。返回去掉这些行之后的备注与按原顺序的各步；
/// 没有清单行时步骤为空、备注原样。
({String note, List<({String title, bool done})> steps}) splitTodoNoteChecklist(
  String note,
) {
  final kept = <String>[];
  final steps = <({String title, bool done})>[];
  for (final line in note.split('\n')) {
    final match = _todoChecklistLine.firstMatch(line);
    final title = match?.group(2)?.trim() ?? '';
    if (match == null || title.isEmpty) {
      kept.add(line);
      continue;
    }
    final mark = match.group(1)!;
    steps.add((title: title, done: mark == 'x' || mark == 'X'));
  }
  if (steps.isEmpty) return (note: note, steps: steps);
  return (note: kept.join('\n').trim(), steps: steps);
}

final RegExp _todoChecklistLine = RegExp(
  r'^\s*(?:[-*+]\s+)?\[([ xX])\]\s+(.*)$',
);

/// 详情页的几项整理：步骤转为独立待办、备注里的清单行转为步骤，以及重复
/// 待办每一次的完成记录（坚持记录）。各自一个事务，只改涉及的列。
mixin _AppDatabaseTodoDetailOps
    on
        _$AppDatabase,
        _AppDatabaseTodoQueries,
        _AppDatabaseTodoOps,
        _AppDatabaseTodoCompleteOps {
  /// 把 [todoId] 的一步 [stepId] 拿出来另建一条待办（同一清单，排在最前；
  /// 已勾掉的步骤建成后直接完成），并从原来的步骤里去掉。同一事务；这一步
  /// 不存在时什么都不做、返回 null，否则返回新待办的业务 id。
  Future<String?> convertTodoStepToTodo(String todoId, String stepId) {
    return transaction(() async {
      final row = await getTodo(todoId);
      if (row == null) return null;
      final steps = decodeTodoSteps(row.steps);
      final index = steps.indexWhere((TodoStep step) => step.id == stepId);
      if (index < 0) return null;
      final step = steps[index];
      final id = await createTodo(
        TodoInput(
          title: step.title,
          listId: row.listId,
          tags: TodoTags.ofMetadataText(row.metadata),
        ),
      );
      if (step.done) await completeTodo(id);
      await setTodoSteps(todoId, <TodoStep>[...steps]..removeAt(index));
      return id;
    });
  }

  /// 把备注里的清单行（[splitTodoNoteChecklist]）挪进步骤末尾，备注去掉这些
  /// 行；步骤总数不超过 [TodoStep.maxSteps]，放不下的行留在备注里。同一
  /// 事务；返回挪过去的步数。
  Future<int> moveTodoNoteChecklistToSteps(String todoId) {
    return transaction(() async {
      final row = await getTodo(todoId);
      if (row == null) return 0;
      final split = splitTodoNoteChecklist(row.note);
      if (split.steps.isEmpty) return 0;
      final steps = decodeTodoSteps(row.steps);
      final room = TodoStep.maxSteps - steps.length;
      if (room <= 0) return 0;
      final moved = split.steps.take(room).toList();
      final next = <TodoStep>[...steps];
      for (final item in moved) {
        next.add(
          TodoStep(
            id: TodoStep.nextId(next),
            title: item.title.length > TodoStep.maxTitleLength
                ? item.title.substring(0, TodoStep.maxTitleLength)
                : item.title,
            done: item.done,
          ),
        );
      }
      // 放不下的清单行原样留在备注末尾。
      final leftover = <String>[
        for (final item in split.steps.skip(moved.length))
          '- [${item.done ? 'x' : ' '}] ${item.title}',
      ];
      final note = <String>[
        if (split.note.isNotEmpty) split.note,
        ...leftover,
      ].join('\n');
      await (update(todos)..where((t) => t.id.equals(row.id))).write(
        TodosCompanion(
          note: Value(note),
          steps: Value(encodeTodoSteps(next)),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return moved.length;
    });
  }

  /// 重复待办 [todoId] 每一次的完成记录（已完成副本，`metadata.repeatOf`
  /// 指向它），最近完成的在前，至多 [limit] 条。
  Stream<List<TodoRow>> watchTodoOccurrences(String todoId, {int limit = 400}) {
    final marker = jsonEncode(<String, Object?>{
      TodoMetadataKeys.repeatOf: todoId,
    });
    // 副本的 metadata 由完成时整份写入，`{"repeatOf":"<id>"}` 是它的一段。
    final needle = '%${marker.substring(1, marker.length - 1)}%';
    return (select(todos)
          ..where((t) => t.completedAt.isNotNull() & t.metadata.like(needle))
          ..orderBy(<OrderClauseGenerator<$TodosTable>>[
            (t) => OrderingTerm.desc(t.completedAt),
          ])
          ..limit(limit))
        .watch();
  }
}
