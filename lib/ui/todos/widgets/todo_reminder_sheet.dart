import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../viewmodels/todo_reminder_pick.dart';
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
/// 两种都能“自定义时间…”（选日期与时刻，经 [resolveTodoReminderPick] 换算
/// 成相对截止日的提醒，最早提前 28 天）。自定义选在截止时间之后时截止时间
/// 顺延过去：先经 [onDueMoved] 交出新的截止日与时刻（调用方写库或改草稿），
/// 再经 [onChanged] 交出提醒列表；面板记住顺延后的截止时间，接着再选时以它
/// 为准。
Future<void> showTodoReminderSheet(
  BuildContext context, {
  required List<TodoReminder> reminders,
  required DateTime dueDate,
  required int? dueMinute,
  required int allDayMinute,
  required ValueChanged<List<TodoReminder>> onChanged,
  required ValueChanged<TodoDueMove> onDueMoved,
}) {
  return showTodoSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => _ReminderSheet(
      initial: reminders,
      dueDate: dueDate,
      dueMinute: dueMinute,
      allDayMinute: allDayMinute,
      onChanged: onChanged,
      onDueMoved: onDueMoved,
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
    required this.onDueMoved,
  });

  final List<TodoReminder> initial;
  final DateTime dueDate;
  final int? dueMinute;
  final int allDayMinute;
  final ValueChanged<List<TodoReminder>> onChanged;
  final ValueChanged<TodoDueMove> onDueMoved;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late List<TodoReminder> _reminders = List<TodoReminder>.of(widget.initial);

  // 当前的截止时间：自定义提醒把它顺延后以新的为准（全天 / 有时刻不会变）。
  late DateTime _due = widget.dueDate;
  late int? _dueMinute = widget.dueMinute;

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
    final due = _due;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: due,
      firstDate: DateTime(
        due.year,
        due.month,
        due.day - TodoReminder.maxDaysBefore,
      ),
      // 截止日之后也能选（截止日随之顺延），上限与截止日面板一样是 30 年后。
      lastDate: DateTime(due.year + 30, 12, 31),
    );
    if (pickedDate == null || !mounted) return;
    final initial = _dueMinute ?? widget.allDayMinute;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (pickedTime == null || !mounted) return;
    final pick = resolveTodoReminderPick(
      due: due,
      dueMinute: _dueMinute,
      date: pickedDate,
      minute: pickedTime.hour * 60 + pickedTime.minute,
    );
    final move = pick.dueMove;
    if (move != null) {
      // 先顺延截止时间再加提醒：调用方在加第一条提醒时会把截止日定下来，
      // 顺序反了会先写成旧的截止日。
      _due = move.date;
      _dueMinute = move.minute;
      widget.onDueMoved(move);
    }
    _add(pick.reminder);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final timed = _dueMinute != null;
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
