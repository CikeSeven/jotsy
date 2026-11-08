import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import 'todo_labels.dart';
import 'todo_sheet.dart';

/// 编辑一条待办的提醒（最多 [TodoReminder.maxReminders] 个）。
///
/// 面板常驻、即改即写：每次增删都经 [onChanged] 交出新的整份列表（详情页
/// 直接写库，快速新建改草稿），面板里的列表随之更新。提醒相对截止日计算，
/// 调用方保证打开前已有截止日（没有日期时先定下日期）。
///
/// 可选项随截止日有没有时刻而不同：有时刻时是“准时 / 提前 5、15、30 分钟 /
/// 提前 1 小时 / 提前 1 天”，全天时是“当天 [allDayMinute] / 前一天 20:00”；
/// 两种都能“自定义时间…”（选日期与时刻，换算成相对截止日的天数与时刻，
/// 最早提前 28 天、不晚于截止时刻）。
Future<void> showTodoReminderSheet(
  BuildContext context, {
  required List<TodoReminder> reminders,
  required DateTime dueDate,
  required int? dueMinute,
  required int allDayMinute,
  required ValueChanged<List<TodoReminder>> onChanged,
}) {
  return showTodoSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => _ReminderSheet(
      initial: reminders,
      dueDate: dueDate,
      dueMinute: dueMinute,
      allDayMinute: allDayMinute,
      onChanged: onChanged,
    ),
  );
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({
    required this.initial,
    required this.dueDate,
    required this.dueMinute,
    required this.allDayMinute,
    required this.onChanged,
  });

  final List<TodoReminder> initial;
  final DateTime dueDate;
  final int? dueMinute;
  final int allDayMinute;
  final ValueChanged<List<TodoReminder>> onChanged;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late List<TodoReminder> _reminders = List<TodoReminder>.of(widget.initial);

  bool get _full => _reminders.length >= TodoReminder.maxReminders;

  void _set(List<TodoReminder> next) {
    setState(() => _reminders = next);
    widget.onChanged(List<TodoReminder>.unmodifiable(next));
  }

  void _add(TodoReminder reminder) {
    if (_full || _reminders.contains(reminder)) return;
    _set(<TodoReminder>[..._reminders, reminder]);
  }

  Future<void> _custom() async {
    final due = widget.dueDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: due,
      firstDate: DateTime(
        due.year,
        due.month,
        due.day - TodoReminder.maxDaysBefore,
      ),
      lastDate: due,
    );
    if (pickedDate == null || !mounted) return;
    final initial = widget.dueMinute ?? widget.allDayMinute;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (pickedTime == null || !mounted) return;
    final days = DateTime.utc(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
    ).difference(DateTime.utc(due.year, due.month, due.day)).inDays;
    final minute = pickedTime.hour * 60 + pickedTime.minute;
    final dueMinute = widget.dueMinute;
    // 日期选择器已限定在截止日之前 28 天到截止日当天；只剩“当天、晚于截止
    // 时刻”这一种越界，按准时提醒处理。
    if (days == 0 && dueMinute != null && minute > dueMinute) {
      _add(const TodoReminder.beforeDue(0));
      return;
    }
    _add(TodoReminder.onDay(days: days, minute: minute));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final timed = widget.dueMinute != null;
    final presets = timed
        ? const <TodoReminder>[
            TodoReminder.beforeDue(0),
            TodoReminder.beforeDue(5),
            TodoReminder.beforeDue(15),
            TodoReminder.beforeDue(30),
            TodoReminder.beforeDue(60),
            TodoReminder.beforeDue(24 * 60),
          ]
        : <TodoReminder>[
            TodoReminder.onDay(days: 0, minute: widget.allDayMinute),
            const TodoReminder.onDay(days: -1, minute: 20 * 60),
          ];
    return TodoSheetBody(
      title: l10n.todoFieldReminders,
      children: <Widget>[
        for (final reminder in _reminders)
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: FaIcon(
              FontAwesomeIcons.solidBell,
              size: 18,
              color: scheme.primary,
            ),
            title: Text(TodoLabels.reminder(context, reminder)),
            trailing: IconButton(
              tooltip: l10n.todoReminderRemove,
              onPressed: () => _set(<TodoReminder>[
                for (final item in _reminders)
                  if (item != reminder) item,
              ]),
              icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
            ),
          ),
        if (_reminders.isNotEmpty) const Divider(indent: 16, endIndent: 16),
        if (_full)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.s,
            ),
            child: Text(
              l10n.todoReminderLimit(TodoReminder.maxReminders),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else ...<Widget>[
          for (final preset in presets)
            if (!_reminders.contains(preset))
              TodoSheetOption(
                icon: FontAwesomeIcons.bell,
                label: TodoLabels.reminder(context, preset),
                onTap: () => _add(preset),
              ),
          TodoSheetOption(
            icon: FontAwesomeIcons.clock,
            label: l10n.todoReminderCustom,
            onTap: _custom,
          ),
        ],
      ],
    );
  }
}
