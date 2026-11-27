part of 'app_database.dart';

/// 专注记录的读写（表见 [TodoFocusSessions]，口径见 `todo_focus.dart`）。
///
/// 只有写一行与读：记录写完即不可变，没有改与删（覆盖恢复整库替换、同步
/// 写入经各自的路径）。
mixin _AppDatabaseTodoFocusOps on _$AppDatabase {
  /// 记下一段专注，返回业务 id；不到 [TodoFocusRules.minRecordedSeconds] 秒
  /// 的不记，返回 null。
  Future<String?> addTodoFocusSession(TodoFocusInput input) async {
    final seconds = TodoFocusRules.clamp(
      plannedSeconds: input.plannedSeconds,
      focusedSeconds: input.focusedSeconds,
    );
    if (seconds.focused < TodoFocusRules.minRecordedSeconds) return null;
    final id = _newBusinessUuid();
    await into(todoFocusSessions).insert(
      TodoFocusSessionsCompanion.insert(
        sessionId: id,
        todoId: Value(input.todoId),
        startedAt: input.startedAt,
        endedAt: input.endedAt,
        plannedSeconds: seconds.planned,
        focusedSeconds: seconds.focused,
        outcome: input.outcome.name,
      ),
    );
    return id;
  }

  /// 一条待办累计专注了多少秒（详情里的“累计专注”）。
  Stream<int> watchTodoFocusSeconds(String todoId) {
    final total = todoFocusSessions.focusedSeconds.sum();
    final query = selectOnly(todoFocusSessions)
      ..addColumns(<Expression<Object>>[total])
      ..where(todoFocusSessions.todoId.equals(todoId));
    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  /// 从 [since] 起开始的专注（回顾统计按本地日期归到哪一天）。
  Stream<List<TodoFocusRow>> watchTodoFocusSince(DateTime since) {
    final query = select(todoFocusSessions)
      ..where((t) => t.startedAt.isBiggerOrEqualValue(since))
      ..orderBy(<OrderingTerm Function($TodoFocusSessionsTable)>[
        (t) => OrderingTerm.asc(t.startedAt),
      ]);
    return query.watch();
  }
}
