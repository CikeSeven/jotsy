part of 'app_database.dart';

/// 一个清单（或收集箱）的完成进度，见
/// [_AppDatabaseTodoQueries.watchTodoListProgress]。
@immutable
class TodoListProgress {
  const TodoListProgress({required this.open, required this.done});

  /// 没有任何待办的清单。
  static const TodoListProgress empty = TodoListProgress(open: 0, done: 0);

  /// 未完成的条数。
  final int open;

  /// 已完成的条数（含重复待办每一次的已完成副本）。
  final int done;

  int get total => open + done;

  /// 已完成的比例（0–1）；清单里没有待办时为 0。
  double get fraction => total == 0 ? 0 : done / total;

  @override
  bool operator ==(Object other) =>
      other is TodoListProgress && other.open == open && other.done == done;

  @override
  int get hashCode => Object.hash(open, done);

  @override
  String toString() => 'TodoListProgress(open: $open, done: $done)';
}

/// 待办查询。
///
/// 输入：筛选条件；输出：drift watch 流或一次性结果，无副作用。
mixin _AppDatabaseTodoQueries on _$AppDatabase {
  /// 全部未完成的待办，按拖动顺序（新建的在前）。各视图在 Dart 里按截止日、
  /// 优先级、清单筛选与分组：待办通常只有几百条，整表订阅比按视图各开一条
  /// 查询更省（切换视图不必重新查库）。
  Stream<List<TodoRow>> watchOpenTodos() {
    return (select(todos)
          ..where((t) => t.completedAt.isNull())
          ..orderBy(_todoManualOrder()))
        .watch();
  }

  Future<List<TodoRow>> getOpenTodos() {
    return (select(todos)
          ..where((t) => t.completedAt.isNull())
          ..orderBy(_todoManualOrder()))
        .get();
  }

  /// 已完成的待办，最近完成的在前，至多 [limit] 条。
  Stream<List<TodoRow>> watchCompletedTodos({int limit = 500}) {
    return (select(todos)
          ..where((t) => t.completedAt.isNotNull())
          ..orderBy(<OrderClauseGenerator<$TodosTable>>[
            (t) => OrderingTerm.desc(t.completedAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(limit))
        .watch();
  }

  /// 截止日落在 [from]–[to]（都含当天）的待办，含已完成的（日历用）。
  /// `YYYY-MM-DD` 文本按字典序比较即按日期比较。
  Stream<List<TodoRow>> watchTodosDueBetween(DateTime from, DateTime to) {
    final start = formatAnniversaryDate(from);
    final end = formatAnniversaryDate(to);
    return (select(todos)
          ..where(
            (t) =>
                t.dueDate.isBiggerOrEqualValue(start) &
                t.dueDate.isSmallerOrEqualValue(end),
          )
          ..orderBy(_todoManualOrder()))
        .watch();
  }

  Stream<TodoRow?> watchTodo(String todoId) {
    return (select(
      todos,
    )..where((t) => t.todoId.equals(todoId))).watchSingleOrNull();
  }

  Future<TodoRow?> getTodo(String todoId) {
    return (select(
      todos,
    )..where((t) => t.todoId.equals(todoId))).getSingleOrNull();
  }

  /// 关联了某篇日记的待办（未完成的在前）。
  Stream<List<TodoRow>> watchTodosLinkedToDiary(String diaryId) {
    return (select(todos)
          ..where((t) => t.linkedDiaryId.equals(diaryId))
          ..orderBy(<OrderClauseGenerator<$TodosTable>>[
            (t) => OrderingTerm(
              expression: t.completedAt.isNull(),
              mode: OrderingMode.desc,
            ),
            ..._todoManualOrder(),
          ]))
        .watch();
  }

  /// 搜索：每个词都要出现在标题、备注或某个步骤里（与日记搜索同一拆词口径，
  /// 见 `splitSearchTerms`），含已完成的，至多 [limit] 条。
  ///
  /// 步骤存的是 JSON，SQL 里的 LIKE 会连键名（`title` / `done`）一起匹配，
  /// 所以先粗筛、再在 Dart 里按解码后的步骤标题精确判断。
  Stream<List<TodoRow>> watchTodoSearch(String keyword, {int limit = 200}) {
    final terms = splitSearchTerms(keyword);
    if (terms.isEmpty) return Stream<List<TodoRow>>.value(const <TodoRow>[]);
    final query = select(todos)
      ..where((t) {
        Expression<bool> all = const Constant(true);
        for (final term in terms) {
          final pattern = containsLikePattern(term);
          all =
              all &
              (t.title.like(pattern, escapeChar: r'\') |
                  t.note.like(pattern, escapeChar: r'\') |
                  t.steps.like(pattern, escapeChar: r'\'));
        }
        return all;
      })
      ..orderBy(<OrderClauseGenerator<$TodosTable>>[
        (t) => OrderingTerm(
          expression: t.completedAt.isNull(),
          mode: OrderingMode.desc,
        ),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return query.watch().map(
      (rows) => rows
          .where((row) => _todoMatchesAll(row, terms))
          .take(limit)
          .toList(growable: false),
    );
  }

  /// 每个清单（键为清单业务 id，收集箱为 null）里未完成与已完成的待办数，
  /// 一条按 `list_id` 分组的查询。已完成的含重复待办每一次的已完成副本（副本
  /// 与原待办在同一清单）；一条待办都没有的清单不在结果里，按
  /// [TodoListProgress.empty] 处理。
  Stream<Map<String?, TodoListProgress>> watchTodoListProgress() {
    final total = todos.id.count();
    // COUNT(列) 只数非 NULL 的值：completed_at 不为 NULL 即已完成。
    final done = todos.completedAt.count();
    final query = selectOnly(todos)
      ..addColumns(<Expression<Object>>[todos.listId, total, done])
      ..groupBy(<Expression<Object>>[todos.listId]);
    return query.watch().map((rows) {
      return <String?, TodoListProgress>{
        for (final row in rows)
          row.read(todos.listId): TodoListProgress(
            open: (row.read(total) ?? 0) - (row.read(done) ?? 0),
            done: row.read(done) ?? 0,
          ),
      };
    });
  }

  bool _todoMatchesAll(TodoRow row, List<String> terms) {
    final title = row.title.toLowerCase();
    final note = row.note.toLowerCase();
    final steps = <String>[
      for (final step in decodeTodoSteps(row.steps)) step.title.toLowerCase(),
    ];
    for (final term in terms) {
      final needle = term.toLowerCase();
      if (title.contains(needle) || note.contains(needle)) continue;
      if (steps.any((step) => step.contains(needle))) continue;
      return false;
    }
    return true;
  }
}

/// 手动排序：按拖动顺序，新建的在前（新建时取所在清单最前的值再往前）。
List<OrderClauseGenerator<$TodosTable>> _todoManualOrder() =>
    <OrderClauseGenerator<$TodosTable>>[
      (t) => OrderingTerm.asc(t.sortOrder),
      (t) => OrderingTerm.desc(t.createdAt),
      (t) => OrderingTerm.asc(t.id),
    ];
