// 日历类的写工具：待办、纪念日、这天的心情，以及留言。
//
// 待办的提醒：带提醒时先经对话页申请通知权限（`AiToolUi`），拒绝或本平台
// 没有提醒时照样建待办、不带提醒，并告诉模型。提醒的排程由
// `todoReminderSchedulerProvider` 监听待办自动完成，这里不用管。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../anniversaries/controllers/anniversary_edit_controller.dart';
import '../../anniversaries/models/anniversary_draft.dart';
import 'ai_tool.dart';
import 'ai_tool_writes.dart';

/// 按名称找待办清单；null 为收件箱。
Future<String?> _listId(AppDatabase database, Object? name) async {
  if (name is! String || name.trim().isEmpty) return null;
  final lists = await database.getTodoLists();
  for (final list in lists) {
    if (list.name.toLowerCase() == name.trim().toLowerCase()) {
      return list.listId;
    }
  }
  throw AiToolFailure(
    'No to-do list named "$name". Lists: '
    '${lists.map((l) => l.name).join(', ')} (omit `list` for the inbox).',
  );
}

const List<String> _priorities = <String>['none', 'low', 'medium', 'high'];

List<TodoRow> _rows(Object? raw) => [
  for (final row in raw as List? ?? const [])
    TodoRow.fromJson((row as Map).cast<String, dynamic>()),
];

class CreateTodoTool extends AiTool {
  const CreateTodoTool();

  @override
  String get name => 'create_todo';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Add a to-do. `time` needs `date`; `remind_before_minutes` needs both '
      '(0 = at the due time). `list` is a to-do list name (inbox if omitted).';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'title': AiStringSchema(maxLength: 500),
      'note': AiStringSchema(),
      'date': AiDateSchema(),
      'time': AiTimeSchema(),
      'remind_before_minutes': AiIntegerSchema(minimum: 0, maximum: 10080),
      'list': AiStringSchema(),
      'priority': AiStringSchema(enumValues: _priorities),
      'diary_id': AiStringSchema(description: 'Link the to-do to an entry.'),
    },
    required: <String>['title'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolCreateTodo('${args['title'] ?? ''}');

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final date = args['date'] as DateTime?;
    final minute = args['time'] as int?;
    final remind = args['remind_before_minutes'] as int?;
    if (minute != null && date == null) {
      throw const AiToolFailure('`time` needs `date`.');
    }
    if (remind != null && minute == null) {
      throw const AiToolFailure('A reminder needs `date` and `time`.');
    }
    final diaryId = args['diary_id'] as String?;
    if (diaryId != null) await aiWritableDiary(context, diaryId);
    final withReminder = remind != null && AppPlatform.supportsReminders;
    final reminderNote = remind != null && !withReminder
        ? 'This device has no reminders, so the to-do was added without one.'
        : '';
    final id = await database.createTodo(
      TodoInput(
        title: (args['title']! as String).trim(),
        note: (args['note'] as String?)?.trim() ?? '',
        listId: await _listId(database, args['list']),
        priority: TodoPriority.values.byName(
          args['priority'] as String? ?? 'none',
        ),
        dueDate: date,
        dueMinute: minute,
        reminders: [if (withReminder) TodoReminder.beforeDue(remind)],
        linkedDiaryId: diaryId,
      ),
    );
    // 与待办页同一口径：先保存提醒，再确认系统允许发通知。
    if (withReminder) await context.ui?.requestReminderPermission();
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'id': id,
        if (reminderNote.isNotEmpty) 'note': reminderNote,
      },
      summary: context.l10n.aiToolDone,
      undo: <String, Object?>{'id': id},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    await container.read(appDatabaseProvider).deleteTodo(data['id']! as String);
  }
}

class UpdateTodosTool extends AiTool {
  const UpdateTodosTool();

  @override
  String get name => 'update_todos';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Change to-dos (by id): due date/time (or `clear_due`), list, '
      'priority. `title` and `note` can only be changed for one to-do at a '
      'time.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 100),
      'date': AiDateSchema(),
      'time': AiTimeSchema(),
      'clear_due': AiBooleanSchema(),
      'list': AiStringSchema(allowEmpty: true),
      'priority': AiStringSchema(enumValues: _priorities),
      'title': AiStringSchema(maxLength: 500),
      'note': AiStringSchema(allowEmpty: true),
    },
    required: <String>['ids'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolUpdateTodos(ids is List ? ids.length : 1);
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final ids = (args['ids']! as List).cast<String>().toSet().toList();
    final rows = <TodoRow>[];
    for (final id in ids) {
      final row = await database.getTodo(id);
      if (row == null) throw AiToolFailure('No to-do with id $id.');
      rows.add(row);
    }
    if ((args.containsKey('title') || args.containsKey('note')) &&
        ids.length != 1) {
      throw const AiToolFailure('Change title or note one to-do at a time.');
    }
    final undo = <String, Object?>{};
    final date = args['date'] as DateTime?;
    final minute = args['time'] as int?;
    if (args['clear_due'] == true || date != null || minute != null) {
      if (minute != null && date == null) {
        throw const AiToolFailure('`time` needs `date`.');
      }
      final before = await database.setTodosDue(
        ids,
        date: args['clear_due'] == true ? null : date,
        minute: args['clear_due'] == true ? null : minute,
      );
      undo['due'] = [for (final row in before) row.toJson()];
    }
    if (args.containsKey('list')) {
      final before = await database.setTodosListId(
        ids,
        await _listId(database, args['list']),
      );
      undo['list'] = [for (final row in before) row.toJson()];
    }
    if (args['priority'] case final String priority) {
      final before = await database.setTodosPriority(
        ids,
        TodoPriority.values.byName(priority),
      );
      undo['priority'] = [for (final row in before) row.toJson()];
    }
    if (args['title'] case final String title) {
      await database.setTodoTitle(ids.single, title);
      undo['title'] = rows.single.title;
    }
    if (args['note'] case final String note) {
      await database.setTodoNote(ids.single, note);
      undo['note'] = rows.single.note;
    }
    if (undo.isEmpty) throw const AiToolFailure('Nothing to change.');
    undo['ids'] = ids;
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'todos': ids.length},
      summary: context.l10n.aiToolDone,
      undo: undo,
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final database = container.read(appDatabaseProvider);
    for (final (key, field) in const [
      ('due', TodoBatchField.due),
      ('list', TodoBatchField.list),
      ('priority', TodoBatchField.priority),
    ]) {
      if (data.containsKey(key)) {
        await database.restoreTodoFields(_rows(data[key]), field);
      }
    }
    final ids = aiUndoStrings(data['ids']);
    if (data['title'] case final String title) {
      await database.setTodoTitle(ids.single, title);
    }
    if (data['note'] case final String note) {
      await database.setTodoNote(ids.single, note);
    }
  }
}

class CompleteTodosTool extends AiTool {
  const CompleteTodosTool();

  @override
  String get name => 'complete_todos';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Mark to-dos (by id) as done. Repeating to-dos move to their next date.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 100),
    },
    required: <String>['ids'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolCompleteTodos(ids is List ? ids.length : 1);
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final completions = await context.database.completeTodos(
      (args['ids']! as List).cast<String>(),
      now: context.now,
    );
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'completed': completions.length},
      summary: context.l10n.aiToolDone,
      undo: <String, Object?>{
        'completions': [
          for (final completion in completions)
            <String, Object?>{
              'before': completion.before.toJson(),
              'copyId': ?completion.copyId,
              'nextDue': ?completion.nextDue?.millisecondsSinceEpoch,
            },
        ],
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final database = container.read(appDatabaseProvider);
    for (final raw in data['completions']! as List) {
      final map = (raw as Map).cast<String, Object?>();
      final nextDue = map['nextDue'];
      await database.undoTodoCompletion(
        TodoCompletion(
          before: TodoRow.fromJson(
            (map['before']! as Map).cast<String, dynamic>(),
          ),
          copyId: map['copyId'] as String?,
          nextDue: nextDue is int
              ? DateTime.fromMillisecondsSinceEpoch(nextDue)
              : null,
        ),
      );
    }
  }
}

class DeleteTodosTool extends AiTool {
  const DeleteTodosTool();

  @override
  String get name => 'delete_todos';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.destructive;

  @override
  String get description => 'Delete to-dos (by id). The user confirms first.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 100),
    },
    required: <String>['ids'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.todos;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final ids = args['ids'];
    return l10n.aiToolDeleteTodos(ids is List ? ids.length : 1);
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final titles = <String>[];
    for (final id in (args['ids']! as List).cast<String>()) {
      final row = await context.database.getTodo(id);
      if (row == null) throw AiToolFailure('No to-do with id $id.');
      titles.add(row.title);
    }
    return AiToolPreview(
      title: label(context.l10n, args),
      lines: [...titles.take(8), if (titles.length > 8) '…'],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final rows = await context.database.deleteTodos(
      (args['ids']! as List).cast<String>(),
    );
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'deleted': rows.length},
      summary: context.l10n.aiToolDone,
      undo: <String, Object?>{
        'rows': [for (final row in rows) row.toJson()],
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) => container.read(appDatabaseProvider).restoreTodos(_rows(data['rows']));
}

class CreateAnniversaryTool extends AiTool {
  const CreateAnniversaryTool();

  @override
  String get name => 'create_anniversary';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Add an anniversary or countdown day. `repeat`: once (count down to / '
      'up from the date), yearly, or lunar_yearly (Chinese lunar calendar; '
      'give the solar date of one occurrence and the lunar day is derived '
      'from it).';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'title': AiStringSchema(maxLength: 100),
      'date': AiDateSchema(),
      'repeat': AiStringSchema(
        enumValues: <String>['once', 'yearly', 'lunar_yearly'],
      ),
      'note': AiStringSchema(),
    },
    required: <String>['title', 'date', 'repeat'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.anniversariesEnabled;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolCreateAnniversary('${args['title'] ?? ''}');

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final result = await AnniversaryEditController(context.database).save(
      AnniversaryDraft(
        title: (args['title']! as String).trim(),
        date: args['date']! as DateTime,
        recurrence: switch (args['repeat']) {
          'yearly' => AnniversaryRecurrence.solarYearly,
          'lunar_yearly' => AnniversaryRecurrence.lunarYearly,
          _ => AnniversaryRecurrence.once,
        },
        note: (args['note'] as String?)?.trim() ?? '',
      ),
    );
    final id = (result as AnniversaryCreated).anniversaryId;
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'id': id},
      summary: context.l10n.aiToolDone,
      undo: <String, Object?>{'id': id},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    await container
        .read(appDatabaseProvider)
        .deleteAnniversary(data['id']! as String);
  }
}

class DeleteAnniversaryTool extends AiTool {
  const DeleteAnniversaryTool();

  @override
  String get name => 'delete_anniversary';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.destructive;

  @override
  String get description =>
      'Delete an anniversary (by id). The user confirms first.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{'id': AiStringSchema()},
    required: <String>['id'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.anniversariesEnabled;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolDeleteAnniversary;

  Future<Anniversary> _find(AiToolContext context, String id) async {
    final rows = await context.database.watchAnniversaries().first;
    for (final row in rows) {
      if (row.anniversaryId == id) return row;
    }
    throw AiToolFailure('No anniversary with id $id.');
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final row = await _find(context, args['id']! as String);
    return AiToolPreview(
      title: label(context.l10n, args),
      lines: ['${row.title}  ${row.baseDate}'],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final row = await _find(context, args['id']! as String);
    await context.database.deleteAnniversary(row.anniversaryId);
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      undo: <String, Object?>{'row': row.toJson()},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) => container
      .read(appDatabaseProvider)
      .restoreAnniversary(
        Anniversary.fromJson((data['row']! as Map).cast<String, dynamic>()),
      );
}

class SetDayMoodTool extends AiTool {
  const SetDayMoodTool();

  @override
  String get name => 'set_day_mood';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      "Set (or clear) the calendar's mood for a whole day: awful, bad, meh, "
      "good or great. This is separate from an entry's mood emoji.";

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'date': AiDateSchema(),
      'mood': AiStringSchema(
        enumValues: <String>['awful', 'bad', 'meh', 'good', 'great', 'clear'],
      ),
    },
    required: <String>['date', 'mood'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.calendar;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolSetDayMood('${args['date'] ?? ''}');

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final day = args['date']! as DateTime;
    final key = formatAnniversaryDate(day);
    final previous = (await database.watchDayMoods().first)
        .where((row) => row.day == key)
        .firstOrNull;
    final mood = args['mood']! as String;
    if (mood == 'clear') {
      await database.clearDayMood(day);
    } else {
      await database.setDayMood(day, DayMood.values.byName(mood));
    }
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      undo: <String, Object?>{
        'day': key,
        if (previous != null) 'previous': previous.toJson(),
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final database = container.read(appDatabaseProvider);
    final previous = data['previous'];
    if (previous is Map) {
      await database.restoreDayMood(
        DayMoodRow.fromJson(previous.cast<String, dynamic>()),
      );
    } else {
      await database.clearDayMood(
        parseAnniversaryDate(data['day']! as String)!,
      );
    }
  }
}

class AddCommentTool extends AiTool {
  const AddCommentTool();

  @override
  String get name => 'add_comment';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Add a comment (a short note shown under the entry, written as the '
      'user) to an entry by id. Only when the user asks for it.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'id': AiStringSchema(),
      'text': AiStringSchema(maxLength: 1000),
    },
    required: <String>['id', 'text'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.comments;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolAddComment;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final found = await aiWritableDiary(context, args['id']! as String);
    final id = await context.database.addDiaryComment(
      diaryId: found.diary.diaryId,
      content: (args['text']! as String).trim(),
    );
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      undo: <String, Object?>{'id': id},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    await container
        .read(appDatabaseProvider)
        .deleteDiaryComment(data['id']! as String);
  }
}
