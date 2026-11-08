import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../anniversaries/widgets/anniversary_diary_picker.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../diaries/controllers/diary_open_flow.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_list_style.dart';
import '../widgets/todo_due_sheet.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_list_picker_sheet.dart';
import '../widgets/todo_reminder_sheet.dart';
import '../widgets/todo_repeat_sheet.dart';

/// 详情页的字段卡片：日期、提醒、重复、优先级、清单、关联日记，每行点开对应
/// 的面板，选完即写库（逐项写，见 `_AppDatabaseTodoOps`）。
///
/// 截止日改为全天时，只对有时刻的待办有效的提醒（准时、提前若干分钟）随之
/// 去掉；去掉日期时重复由数据库一并去掉，提醒保留但不会触发（行上不显示）。
class TodoDetailFields extends ConsumerWidget {
  const TodoDetailFields({super.key, required this.row, required this.today});

  final TodoRow row;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final database = ref.read(appDatabaseProvider);
    final settings = ref.watch(todoSettingsProvider);
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    final dueText = row.dueDate;
    final due = dueText == null ? null : parseAnniversaryDate(dueText);
    final reminders = decodeTodoReminders(row.reminders);
    final repeat = decodeTodoRepeat(row.repeat);
    final priority = TodoPriority.of(row.priority);
    TodoListRow? list;
    for (final item in lists) {
      if (item.listId == row.listId) list = item;
    }
    final linkedDiaryId = row.linkedDiaryId;

    Future<void> pickDue() async {
      final choice = await showTodoDueSheet(
        context,
        date: due,
        minute: row.dueMinute,
        today: today,
      );
      if (choice == null) return;
      await database.setTodoDue(
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
          await database.setTodoReminders(row.todoId, kept);
        }
      }
    }

    Future<void> pickReminders() async {
      var dueDate = due;
      if (dueDate == null) {
        // 提醒相对截止日：没有日期时先定为今天。
        dueDate = today;
        await database.setTodoDue(row.todoId, date: today);
      }
      if (!context.mounted) return;
      await showTodoReminderSheet(
        context,
        reminders: reminders,
        dueDate: dueDate,
        dueMinute: row.dueMinute,
        allDayMinute: settings.allDayReminderMinute,
        onChanged: (List<TodoReminder> next) =>
            unawaited(database.setTodoReminders(row.todoId, next)),
      );
    }

    Future<void> pickRepeat() async {
      final anchor = due ?? today;
      final choice = await showTodoRepeatSheet(
        context,
        current: repeat,
        anchor: anchor,
      );
      if (choice == null) return;
      if (due == null && choice.rule != null) {
        await database.setTodoDue(row.todoId, date: anchor);
      }
      await database.setTodoRepeat(row.todoId, choice.rule);
    }

    Future<void> pickList() async {
      final choice = await showTodoListPickerSheet(
        context,
        current: row.listId,
      );
      if (choice == null || choice.listId == row.listId) return;
      await database.setTodoListId(row.todoId, choice.listId);
    }

    Future<void> pickDiary() async {
      final pick = await showAnniversaryDiaryPicker(
        context,
        date: due ?? today,
        selectedDiaryId: linkedDiaryId,
      );
      if (pick == null) return;
      await database.setTodoLinkedDiary(row.todoId, pick.diaryId);
    }

    final linkedDiary = linkedDiaryId == null
        ? null
        : ref.watch(todoLinkedDiaryProvider(linkedDiaryId));

    return AppCardSurface(
      shadow: false,
      child: Column(
        children: <Widget>[
          _FieldTile(
            icon: FontAwesomeIcons.calendar,
            title: l10n.todoFieldDue,
            value: due == null
                ? l10n.todoFieldDueEmpty
                : TodoLabels.due(context, due, row.dueMinute, today),
            active: due != null,
            valueColor:
                due != null &&
                    row.completedAt == null &&
                    dueText!.compareTo(formatAnniversaryDate(today)) < 0
                ? scheme.error
                : null,
            onTap: pickDue,
          ),
          _FieldTile(
            icon: FontAwesomeIcons.bell,
            title: l10n.todoFieldReminders,
            value: reminders.isEmpty
                ? l10n.todoFieldRemindersEmpty
                : reminders
                      .map((r) => TodoLabels.reminder(context, r))
                      .join(l10n.isZh ? '、' : ', '),
            active: reminders.isNotEmpty,
            onTap: pickReminders,
          ),
          _FieldTile(
            icon: FontAwesomeIcons.repeat,
            title: l10n.todoFieldRepeat,
            value: TodoLabels.repeat(l10n, repeat),
            active: repeat != null,
            onTap: pickRepeat,
          ),
          ExpressiveMenuAnchor(
            menuChildren: <Widget>[
              for (final value in TodoPriority.values.reversed)
                ExpressiveMenuItem(
                  selected: value == priority,
                  leadingIcon: FaIcon(
                    FontAwesomeIcons.solidFlag,
                    color:
                        TodoLabels.priorityColor(scheme, value) ??
                        scheme.onSurfaceVariant,
                  ),
                  onPressed: () =>
                      unawaited(database.setTodoPriority(row.todoId, value)),
                  child: Text(TodoLabels.priority(l10n, value)),
                ),
            ],
            builder:
                (
                  BuildContext context,
                  ExpressiveMenuAnchorState menu,
                  Widget? _,
                ) => _FieldTile(
                  icon: FontAwesomeIcons.flag,
                  title: l10n.todoFieldPriority,
                  value: TodoLabels.priority(l10n, priority),
                  active: priority != TodoPriority.none,
                  valueColor: TodoLabels.priorityColor(scheme, priority),
                  onTap: () async => menu.toggle(),
                ),
          ),
          _FieldTile(
            icon: list == null
                ? TodoLabels.smartViewIcon(TodoSmartView.inbox)
                : TodoListStyle.iconOfRow(list),
            title: l10n.todoFieldList,
            value: list?.name ?? l10n.todoViewInbox,
            active: true,
            onTap: pickList,
          ),
          _FieldTile(
            icon: FontAwesomeIcons.bookOpen,
            title: l10n.todoFieldDiary,
            value: linkedDiaryId == null
                ? l10n.todoFieldDiaryEmpty
                : linkedDiary?.value == null
                ? (linkedDiary?.isLoading ?? false
                      ? ''
                      : l10n.todoFieldDiaryMissing)
                : _diaryTitle(context, linkedDiary!.value!),
            active: linkedDiaryId != null,
            onTap: pickDiary,
            trailing: linkedDiary?.value == null
                ? null
                : IconButton(
                    tooltip: l10n.todoFieldDiary,
                    onPressed: () => unawaited(
                      openDiaryPage(
                        context,
                        ref,
                        diaryId: linkedDiaryId!,
                        initialDetail: linkedDiary!.value,
                      ),
                    ),
                    icon: const FaIcon(
                      FontAwesomeIcons.arrowUpRightFromSquare,
                      size: 14,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 关联日记的显示名：标题；没有标题时用写下的日期。
  static String _diaryTitle(BuildContext context, DiaryWithTags diary) {
    final title = diary.diary.title.trim();
    if (title.isNotEmpty) return title;
    return context.l10n.formatFullDate(diary.diary.createdAt);
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.active,
    required this.onTap,
    this.valueColor,
    this.trailing,
  });

  final FaIconData icon;
  final String title;
  final String value;
  final bool active;
  final Color? valueColor;
  final Future<void> Function() onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      titleAlignment: ListTileTitleAlignment.center,
      leading: FaIcon(
        icon,
        size: 16,
        color: active ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: value.isEmpty
          ? null
          : Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    valueColor ??
                    (active ? scheme.onSurface : scheme.onSurfaceVariant),
              ),
            ),
      trailing: trailing,
      onTap: () => unawaited(onTap()),
    );
  }
}
