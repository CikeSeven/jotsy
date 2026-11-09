// 待办的只读工具：列出待办（含步骤、提醒与重复）、列出清单。
//
// 都只在待办功能开启时出现；结果里的写法见 `aiTodoItem`（与改动类工具的
// 参数同一形状）。

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../todos/models/todo_settings.dart';
import '../models/ai_tool_subject.dart';
import 'ai_tool.dart';
import 'ai_tool_todo_parts.dart';

/// 清单筛选：空串或 “Inbox”（没有同名清单时）为收集箱。返回 (是否筛选,
/// 清单 id)；清单 id 为 null 即收集箱。
Future<(bool, String?)> _listFilter(AppDatabase database, Object? raw) async {
  if (raw is! String) return (false, null);
  final name = raw.trim();
  if (name.isEmpty) return (true, null);
  final lists = await database.getTodoLists();
  final named = lists
      .where((list) => list.name.toLowerCase() == name.toLowerCase())
      .firstOrNull;
  if (named != null) return (true, named.listId);
  if (name.toLowerCase() == aiTodoInboxName.toLowerCase()) return (true, null);
  return (true, await aiTodoListId(database, name));
}

class ListTodosTool extends AiTool {
  const ListTodosTool();

  @override
  String get name => 'list_todos';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'List to-dos with their steps, reminders and repeat rule: open '
      '(default), completed or all. Optional filters: due date range '
      '(inclusive), keywords (title, note, steps), list name ("" = inbox), '
      'priority.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'status': AiStringSchema(
        enumValues: <String>['open', 'completed', 'all'],
      ),
      'due_from': AiDateSchema(),
      'due_to': AiDateSchema(),
      'query': AiStringSchema(),
      'list': AiStringSchema(allowEmpty: true),
      'priority': AiStringSchema(enumValues: aiTodoPriorities),
      'limit': AiIntegerSchema(minimum: 1, maximum: 200),
    },
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolListTodos;

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) =>
      aiDescribeTodoArg(l10n, key, value);

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final status = args['status'] as String? ?? 'open';
    final from = args['due_from'] as DateTime?;
    final to = args['due_to'] as DateTime?;
    final query = (args['query'] as String?)?.trim();
    final (byList, listId) = await _listFilter(database, args['list']);
    final priority = switch (args['priority']) {
      final String name => TodoPriority.values.byName(name),
      _ => null,
    };
    // 先按最窄的条件从库里取，其余条件在内存里叠加（关键词搜索不带日期
    // 条件，这里补上）。
    List<TodoRow> rows;
    if (query != null && query.isNotEmpty) {
      rows = await database.watchTodoSearch(query).first;
    } else if (from != null || to != null) {
      rows = await database
          .watchTodosDueBetween(from ?? DateTime(1970), to ?? DateTime(9999))
          .first;
    } else if (status == 'completed') {
      rows = await database.watchCompletedTodos().first;
    } else if (status == 'open') {
      rows = await database.getOpenTodos();
    } else {
      rows = [
        ...await database.getOpenTodos(),
        ...await database.watchCompletedTodos().first,
      ];
    }
    bool dueInRange(TodoRow row) {
      if (from == null && to == null) return true;
      final due = row.dueDate == null
          ? null
          : parseAnniversaryDate(row.dueDate!);
      if (due == null) return false;
      return (from == null || !due.isBefore(from)) &&
          (to == null || !due.isAfter(to));
    }

    final filtered = [
      for (final row in rows)
        if ((status == 'all' ||
                (status == 'open') == (row.completedAt == null)) &&
            dueInRange(row) &&
            (!byList || row.listId == listId) &&
            (priority == null || TodoPriority.of(row.priority) == priority))
          row,
    ];
    final lists = <String, String>{
      for (final list in await database.getTodoLists()) list.listId: list.name,
    };
    final limit = args['limit'] as int? ?? 50;
    return AiToolOutcome(
      data: <String, Object?>{
        'total': filtered.length,
        'todos': [
          for (final row in filtered.take(limit)) aiTodoItem(row, lists),
        ],
      },
      summary: context.l10n.aiToolTodoCount(filtered.length),
      subjects: [
        if (byList && listId != null)
          AiToolSubject.todoList(listId, lists[listId] ?? '', input: true),
        for (final row in filtered.take(limit)) aiTodoSubject(row),
      ],
    );
  }
}

class ListTodoListsTool extends AiTool {
  const ListTodoListsTool();

  @override
  String get name => 'list_todo_lists';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'To-do lists with how many open and completed to-dos each has, the '
      'inbox (to-dos in no list), and the default list for new to-dos.';

  @override
  AiObjectSchema get schema =>
      const AiObjectSchema(properties: <String, AiSchema>{});

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolListTodoLists;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final lists = await database.getTodoLists();
    final progress = await database.watchTodoListProgress().first;
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final defaultId = TodoSettings.decode(
      settings.todoSettingsRawNotifier.value,
    ).defaultListId;
    Map<String, Object?> counts(String? id) {
      final p = progress[id] ?? TodoListProgress.empty;
      return <String, Object?>{'open': p.open, 'done': p.done};
    }

    final defaultList = lists
        .where((list) => list.listId == defaultId)
        .firstOrNull;
    return AiToolOutcome(
      data: <String, Object?>{
        'lists': [
          for (final list in lists)
            <String, Object?>{'name': list.name, ...counts(list.listId)},
        ],
        'inbox': counts(null),
        // 默认清单被删掉后按收集箱处理（与待办页同一口径）。
        'default_list': defaultList?.name ?? aiTodoInboxName,
      },
      summary: context.l10n.aiToolTodoListCount(lists.length),
      subjects: [
        for (final list in lists)
          AiToolSubject.todoList(list.listId, list.name),
      ],
    );
  }
}
