import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../anniversaries/widgets/anniversary_diary_picker.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_due_sheet.dart';
import '../widgets/todo_list_picker_sheet.dart';
import '../widgets/todo_reminder_sheet.dart';
import '../widgets/todo_repeat_sheet.dart';
import 'todo_reminder_permission.dart';

/// 详情（底部面板与宽窗口详情栏共用）里改一项写一项的流程：打开对应的
/// 面板，选完即写库（逐列写，见 `_AppDatabaseTodoOps`）。
///
/// 截止日改为全天时，只对有时刻的待办有效的提醒（准时、提前若干分钟）随之
/// 去掉；去掉日期时重复由数据库一并去掉，提醒保留但不会触发。提醒与重复
/// 相对截止日：没有日期时按今天算，真加上时才把日期定下（只看一眼就关掉
/// 面板不改日期）。
class TodoFieldEditors {
  const TodoFieldEditors({
    required this.context,
    required this.ref,
    required this.row,
    required this.today,
  });

  final BuildContext context;
  final WidgetRef ref;
  final TodoRow row;
  final DateTime today;

  AppDatabase get _database => ref.read(appDatabaseProvider);

  DateTime? get _due {
    final text = row.dueDate;
    return text == null ? null : parseAnniversaryDate(text);
  }

  Future<void> pickDue() async {
    final reminders = decodeTodoReminders(row.reminders);
    final choice = await showTodoDueSheet(
      context,
      date: _due,
      minute: row.dueMinute,
      today: today,
    );
    if (choice == null) return;
    await _database.setTodoDue(
      row.todoId,
      date: choice.date,
      minute: choice.minute,
    );
    if (choice.date != null && choice.minute == null) {
      final kept = <TodoReminder>[
        for (final r in reminders)
          if (r.kind == TodoReminderKind.onDay) r,
      ];
      if (kept.length != reminders.length) {
        await _database.setTodoReminders(row.todoId, kept);
      }
    }
  }

  Future<void> pickReminders() async {
    final database = _database;
    final due = _due;
    final dueDate = due ?? today;
    var dated = due != null;
    await showTodoReminderSheet(
      context,
      reminders: decodeTodoReminders(row.reminders),
      dueDate: dueDate,
      dueMinute: row.dueMinute,
      allDayMinute: ref.read(todoSettingsProvider).allDayReminderMinute,
      onChanged: (List<TodoReminder> next) {
        if (!dated && next.isNotEmpty) {
          dated = true;
          unawaited(database.setTodoDue(row.todoId, date: dueDate));
        }
        unawaited(database.setTodoReminders(row.todoId, next));
        if (next.isNotEmpty && context.mounted) {
          unawaited(ensureTodoReminderPermission(context, ref));
        }
      },
    );
  }

  Future<void> pickRepeat() async {
    final database = _database;
    final due = _due;
    final anchor = due ?? today;
    final choice = await showTodoRepeatSheet(
      context,
      current: decodeTodoRepeat(row.repeat),
      anchor: anchor,
    );
    if (choice == null) return;
    if (due == null && choice.rule != null) {
      await database.setTodoDue(row.todoId, date: anchor);
    }
    await database.setTodoRepeat(row.todoId, choice.rule);
  }

  Future<void> pickList() async {
    final database = _database;
    final choice = await showTodoListPickerSheet(context, current: row.listId);
    if (choice == null || choice.listId == row.listId) return;
    await database.setTodoListId(row.todoId, choice.listId);
  }

  Future<void> setPriority(TodoPriority priority) =>
      _database.setTodoPriority(row.todoId, priority);

  Future<void> pickDiary() async {
    final database = _database;
    final pick = await showAnniversaryDiaryPicker(
      context,
      date: _due ?? today,
      selectedDiaryId: row.linkedDiaryId,
    );
    if (pick == null) return;
    await database.setTodoLinkedDiary(row.todoId, pick.diaryId);
  }

  /// 复制为新待办：带上全部字段（步骤全部未勾），标题后加“副本”的说法，
  /// 排在同一清单最前。返回新待办的业务 id。
  Future<String> duplicate(String title) {
    return _database.createTodo(
      TodoInput(
        title: title,
        listId: row.listId,
        note: row.note,
        priority: TodoPriority.of(row.priority),
        dueDate: _due,
        dueMinute: row.dueMinute,
        reminders: decodeTodoReminders(row.reminders),
        repeat: decodeTodoRepeat(row.repeat),
        steps: <TodoStep>[
          for (final step in decodeTodoSteps(row.steps))
            step.copyWith(done: false),
        ],
        linkedDiaryId: row.linkedDiaryId,
      ),
    );
  }
}
