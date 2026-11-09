// 待办的改动类工具：新建与修改（日期、提醒、重复、清单、优先级、标题、
// 备注、关联日记）。完成、取消完成、编辑步骤与删除见
// `ai_tools_todo_status_writes.dart`，清单见 `ai_tools_todo_list_writes.dart`。
//
// 写库只经待办的 DB ops，规则与待办页一致：
// - 提醒与重复都相对截止日；没有截止日的待办设提醒或重复时先把截止日定为
//   今天（与详情页的提醒 / 重复面板同一口径）；
// - 批量改日期不给时刻时每条保留自己的时刻（与多选“改日期”同一口径），
//   `all_day` 才改成全天；
// - 带提醒时先保存提醒，再经对话页确认系统允许发通知（`AiToolUi`）；本平台
//   没有提醒时照样保存其余改动、不带提醒，并告诉模型；
// - 所有校验在写库之前做完，批量里有一条不合规就整批不做，不留半截改动。
// 提醒的排程由 `todoReminderSchedulerProvider` 监听待办自动完成，这里不管。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../todos/models/todo_settings.dart';
import '../models/ai_tool_subject.dart';
import 'ai_tool.dart';
import 'ai_tool_todo_parts.dart';
import 'ai_tool_writes.dart';

const String _noReminderNote =
    'This device has no reminders, so they were left out.';

/// 新建待办默认进哪个清单：设置里的默认清单（还在时），否则收集箱。
Future<String?> _defaultListId(AiToolContext context) async {
  final settings = await context.container.read(settingsServiceProvider.future);
  final id = TodoSettings.decode(
    settings.todoSettingsRawNotifier.value,
  ).defaultListId;
  if (id == null) return null;
  return await context.database.getTodoList(id) == null ? null : id;
}

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
      'Add a to-do. `time` needs `date`. `remind_before_minutes` is a '
      'shortcut for one reminder before the due time; `reminders` and '
      '`repeat` set them fully (a to-do without `date` then gets today). '
      '`steps` are sub-tasks. `list` is a list name ("" = inbox; omitted = '
      'the default list).';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'title': AiStringSchema(maxLength: 500),
      'note': AiStringSchema(),
      'date': AiDateSchema(),
      'time': AiTimeSchema(),
      'remind_before_minutes': AiIntegerSchema(
        minimum: 0,
        maximum: TodoReminder.maxMinutesBefore,
      ),
      'reminders': aiTodoRemindersSchema,
      'repeat': aiTodoRepeatSchema,
      'steps': AiArraySchema(
        items: AiStringSchema(maxLength: TodoStep.maxTitleLength),
        maxItems: TodoStep.maxSteps,
      ),
      'list': AiStringSchema(allowEmpty: true),
      'priority': AiStringSchema(enumValues: aiTodoPriorities),
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
  String? describeArg(AppLocalizations l10n, String key, Object? value) =>
      aiDescribeTodoArg(l10n, key, value);

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    var date = args['date'] as DateTime?;
    final minute = args['time'] as int?;
    if (minute != null && date == null) {
      throw const AiToolFailure('`time` needs `date`.');
    }
    final repeatArg = args['repeat'] as Map<String, Object?>?;
    final wantsRepeat = repeatArg != null && repeatArg['frequency'] != 'none';
    final remindBefore = args['remind_before_minutes'] as int?;
    final reminderArgs = <Object?>[
      if (remindBefore != null)
        <String, Object?>{'minutes_before': remindBefore},
      ...?(args['reminders'] as List?),
    ];
    // 与详情页同一口径：设提醒或重复时没有截止日就定为今天。
    var datedToday = false;
    if (date == null && (wantsRepeat || reminderArgs.isNotEmpty)) {
      date = context.today;
      datedToday = true;
    }
    var reminders = aiTodoReminders(reminderArgs, hasDueTime: minute != null);
    if (reminders.length > TodoReminder.maxReminders) {
      throw const AiToolFailure(
        'A to-do has at most ${TodoReminder.maxReminders} reminders.',
      );
    }
    final dropped = reminders.isNotEmpty && !AppPlatform.supportsReminders;
    if (dropped) reminders = const <TodoReminder>[];
    final repeat = repeatArg == null || date == null
        ? null
        : aiTodoRepeatRule(repeatArg, date);
    final diaryId = args['diary_id'] as String?;
    if (diaryId != null) await aiWritableDiary(context, diaryId);
    final title = (args['title']! as String).trim();
    final id = await database.createTodo(
      TodoInput(
        title: title,
        note: (args['note'] as String?)?.trim() ?? '',
        listId: switch (args['list']) {
          final String list => await aiTodoListId(database, list),
          _ => await _defaultListId(context),
        },
        priority: TodoPriority.values.byName(
          args['priority'] as String? ?? 'none',
        ),
        dueDate: date,
        dueMinute: minute,
        reminders: reminders,
        repeat: repeat,
        steps: aiTodoNewSteps(const <TodoStep>[], [
          for (final step in args['steps'] as List? ?? const []) step as String,
        ]),
        linkedDiaryId: diaryId,
      ),
    );
    // 与待办页同一口径：先保存提醒，再确认系统允许发通知。
    if (reminders.isNotEmpty) await context.ui?.requestReminderPermission();
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'id': id,
        if (datedToday) 'due_date': aiToolDate(date!),
        if (dropped) 'note': _noReminderNote,
      },
      summary: context.l10n.aiToolDone,
      subjects: [AiToolSubject.todo(id, title, due: date)],
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

/// 一条待办改完之后的截止日与时刻（还没写库，供先做校验）。
typedef _Due = ({DateTime? date, int? minute});

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
      'Change to-dos (by id). `date` alone keeps each to-do\'s own time; '
      '`time` alone keeps each date; `all_day` removes the time; '
      '`clear_due` removes the date (and repeat). `reminders` replaces all '
      'reminders ([] removes them); `repeat` replaces the repeat rule. '
      '`list` ("" = inbox), `priority`, and `diary_id` ("" unlinks). `title` '
      'and `note` only for one to-do at a time. Steps: edit_todo_steps.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 100),
      'date': AiDateSchema(),
      'time': AiTimeSchema(),
      'all_day': AiBooleanSchema(),
      'clear_due': AiBooleanSchema(),
      'reminders': aiTodoRemindersSchema,
      'repeat': aiTodoRepeatSchema,
      'list': AiStringSchema(allowEmpty: true),
      'priority': AiStringSchema(enumValues: aiTodoPriorities),
      'diary_id': AiStringSchema(allowEmpty: true),
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
  String? describeArg(AppLocalizations l10n, String key, Object? value) =>
      aiDescribeTodoArg(l10n, key, value);

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final ids = (args['ids']! as List).cast<String>().toSet().toList();
    final rows = await aiTodosByIds(database, ids);
    if ((args.containsKey('title') || args.containsKey('note')) &&
        ids.length != 1) {
      throw const AiToolFailure('Change title or note one to-do at a time.');
    }
    final date = args['date'] as DateTime?;
    final minute = args['time'] as int?;
    final allDay = args['all_day'] == true;
    final clearDue = args['clear_due'] == true;
    final repeatArg = args['repeat'] as Map<String, Object?>?;
    final wantsRepeat = repeatArg != null && repeatArg['frequency'] != 'none';
    final reminderArgs = args['reminders'] as List?;
    final wantsReminders = reminderArgs != null && reminderArgs.isNotEmpty;
    if (clearDue &&
        (date != null || minute != null || wantsRepeat || wantsReminders)) {
      throw const AiToolFailure(
        '`clear_due` cannot be combined with a date, time, reminders or '
        'repeat.',
      );
    }
    if (allDay && minute != null) {
      throw const AiToolFailure('Give `time` or `all_day`, not both.');
    }

    // 1. 先算出每条改完后的截止日与时刻，并做完全部校验，再写库。
    final dueTouched = clearDue || date != null || minute != null || allDay;
    final planned = <String, _Due>{};
    var datedToday = false;
    for (final row in rows) {
      final current = row.dueDate == null
          ? null
          : parseAnniversaryDate(row.dueDate!);
      var newDate = clearDue ? null : date ?? current;
      final newMinute = clearDue || allDay ? null : minute ?? row.dueMinute;
      if (newDate == null && minute != null) {
        throw AiToolFailure(
          'To-do ${row.todoId} has no due date; give `date` with `time`.',
        );
      }
      if (newDate == null && (wantsRepeat || wantsReminders)) {
        newDate = context.today;
        datedToday = true;
      }
      planned[row.todoId] = (
        date: newDate,
        minute: newDate == null ? null : newMinute,
      );
    }
    final reminders = <String, List<TodoReminder>>{
      if (reminderArgs != null)
        for (final row in rows)
          row.todoId: aiTodoReminders(
            reminderArgs,
            hasDueTime: planned[row.todoId]!.minute != null,
          ),
    };
    final repeats = <String, TodoRepeatRule?>{
      if (repeatArg != null)
        for (final row in rows)
          row.todoId: planned[row.todoId]!.date == null
              ? null
              : aiTodoRepeatRule(repeatArg, planned[row.todoId]!.date!),
    };
    final listId = switch (args['list']) {
      final String list => await aiTodoListId(database, list),
      _ => null,
    };
    final diaryId = args['diary_id'] as String?;
    final linked = diaryId != null && diaryId.isNotEmpty
        ? await aiWritableDiary(context, diaryId)
        : null;
    final dropped = wantsReminders && !AppPlatform.supportsReminders;
    final hasChange =
        dueTouched ||
        datedToday ||
        (reminderArgs != null && !dropped) ||
        repeatArg != null ||
        args.containsKey('list') ||
        args.containsKey('priority') ||
        diaryId != null ||
        args.containsKey('title') ||
        args.containsKey('note');
    if (!hasChange) throw const AiToolFailure('Nothing to change.');

    // 2. 写库。截止日按（日期, 时刻）分组各写一次：批量方法每组一个事务，
    // 值没变的行不写。
    final undo = <String, Object?>{};
    if (dueTouched || datedToday) {
      final groups = <_Due, List<String>>{};
      for (final MapEntry(:key, :value) in planned.entries) {
        groups.putIfAbsent(value, () => <String>[]).add(key);
      }
      for (final MapEntry(key: due, value: group) in groups.entries) {
        await database.setTodosDue(group, date: due.date, minute: due.minute);
      }
    }
    // 值本来就相同的不写（同批量方法：平白刷新 `updated_at` 会让同步时这台
    // 设备上没改过的旧值盖掉另一台设备的编辑）。比较的是改完截止日之后的行。
    if (reminderArgs != null && !dropped) {
      for (final MapEntry(:key, :value) in reminders.entries) {
        final now = await database.getTodo(key);
        if (now?.reminders == encodeTodoReminders(value)) continue;
        await database.setTodoReminders(key, value);
      }
    }
    if (repeatArg != null) {
      for (final MapEntry(:key, :value) in repeats.entries) {
        final now = await database.getTodo(key);
        if (now?.repeat == encodeTodoRepeat(value)) continue;
        await database.setTodoRepeat(key, value);
      }
    }
    // 截止日、提醒、重复与稍后提醒是一组（`TodoBatchField.due`）：记下真正
    // 变了的行改动前的样子，撤销时整组写回。
    final dueBefore = <TodoRow>[];
    for (final before in rows) {
      final after = await database.getTodo(before.todoId);
      if (after == null) continue;
      if (after.dueDate != before.dueDate ||
          after.dueMinute != before.dueMinute ||
          after.reminders != before.reminders ||
          after.repeat != before.repeat ||
          after.snoozedUntil != before.snoozedUntil) {
        dueBefore.add(before);
      }
    }
    if (dueBefore.isNotEmpty) {
      undo['due'] = [for (final row in dueBefore) row.toJson()];
    }
    if (args.containsKey('list')) {
      final before = await database.setTodosListId(ids, listId);
      undo['list'] = [for (final row in before) row.toJson()];
    }
    if (args['priority'] case final String priority) {
      final before = await database.setTodosPriority(
        ids,
        TodoPriority.values.byName(priority),
      );
      undo['priority'] = [for (final row in before) row.toJson()];
    }
    if (diaryId != null) {
      final target = diaryId.isEmpty ? null : diaryId;
      final previous = <String, Object?>{};
      for (final row in rows) {
        if (row.linkedDiaryId == target) continue;
        await database.setTodoLinkedDiary(row.todoId, target);
        previous[row.todoId] = row.linkedDiaryId;
      }
      undo['diary'] = previous;
    }
    if (args['title'] case final String title) {
      await database.setTodoTitle(ids.single, title);
      undo['title'] = rows.single.title;
    }
    if (args['note'] case final String note) {
      await database.setTodoNote(ids.single, note);
      undo['note'] = rows.single.note;
    }
    undo['ids'] = ids;
    if (wantsReminders && !dropped) {
      await context.ui?.requestReminderPermission();
    }
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'todos': ids.length,
        if (datedToday) 'note': 'To-dos without a date are now due today.',
        if (dropped) 'reminders_note': _noReminderNote,
      },
      summary: context.l10n.aiToolDone,
      subjects: [
        for (final row in rows)
          aiTodoSubject(row, title: args['title'] as String?),
        if (linked != null) aiDiarySubject(linked.diary, input: true),
      ],
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
        await database.restoreTodoFields(aiTodoRows(data[key]), field);
      }
    }
    if (data['diary'] case final Map<Object?, Object?> previous) {
      for (final MapEntry(:key, :value) in previous.entries) {
        await database.setTodoLinkedDiary(key! as String, value as String?);
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
