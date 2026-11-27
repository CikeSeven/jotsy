import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../models/todo_view.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_field_pill.dart';
import 'todo_labels.dart';

/// 快速新建面板底部的一行属性按钮（40 高、可横向滚动）：日期、提醒、重复、
/// 清单、优先级（4 项弹出菜单）与标签。显示的都是此刻生效的值（手动选的 > 识别
/// 出的 > 视图预填的），点开对应的面板由宿主处理。
class TodoQuickAddFields extends StatelessWidget {
  const TodoQuickAddFields({
    super.key,
    required this.today,
    required this.dueDate,
    required this.dueMinute,
    required this.reminders,
    required this.repeat,
    required this.list,
    required this.priority,
    required this.onPickDue,
    required this.onClearDue,
    required this.onPickReminders,
    required this.onClearReminders,
    required this.onPickRepeat,
    required this.onClearRepeat,
    required this.onPickList,
    required this.onPriority,
    required this.tags,
    required this.onPickTags,
    required this.onClearTags,
  });

  final DateTime today;
  final DateTime? dueDate;
  final int? dueMinute;
  final List<TodoReminder> reminders;
  final TodoRepeatRule? repeat;
  final TodoListRow? list;
  final TodoPriority priority;
  final VoidCallback onPickDue;
  final VoidCallback onClearDue;
  final VoidCallback onPickReminders;
  final VoidCallback onClearReminders;
  final VoidCallback onPickRepeat;
  final VoidCallback onClearRepeat;
  final VoidCallback onPickList;
  final ValueChanged<TodoPriority> onPriority;
  final List<String> tags;
  final VoidCallback onPickTags;
  final VoidCallback onClearTags;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final dueDate = this.dueDate;
    final repeat = this.repeat;
    final list = this.list;
    return SizedBox(
      height: 40,
      child: DesktopHorizontalScroll(
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          children: <Widget>[
            _pill(
              icon: dueMinute == null
                  ? FontAwesomeIcons.calendar
                  : FontAwesomeIcons.clock,
              label: dueDate == null
                  ? l10n.todoFieldDue
                  : TodoLabels.due(context, dueDate, dueMinute, today),
              set: dueDate != null,
              onTap: onPickDue,
              onClear: dueDate == null ? null : onClearDue,
            ),
            _pill(
              icon: FontAwesomeIcons.bell,
              label: reminders.isEmpty
                  ? l10n.todoFieldReminders
                  : reminders.length == 1
                  ? TodoLabels.reminder(context, reminders.single)
                  : l10n.todoRemindersCount(reminders.length),
              set: reminders.isNotEmpty,
              onTap: onPickReminders,
              onClear: reminders.isEmpty ? null : onClearReminders,
            ),
            _pill(
              icon: FontAwesomeIcons.repeat,
              label: repeat == null
                  ? l10n.todoFieldRepeat
                  : TodoLabels.repeat(l10n, repeat),
              set: repeat != null,
              onTap: onPickRepeat,
              onClear: repeat == null ? null : onClearRepeat,
            ),
            _pill(
              icon: list == null
                  ? TodoLabels.smartViewIcon(TodoSmartView.inbox)
                  : TodoListStyle.iconOfRow(list),
              iconColor: list == null
                  ? null
                  : TodoListStyle.accentOf(list.colorKey, scheme).onContainer,
              label: list?.name ?? l10n.todoViewInbox,
              set: list != null,
              onTap: onPickList,
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
                    onPressed: () => onPriority(value),
                    child: Text(TodoLabels.priority(l10n, value)),
                  ),
              ],
              builder:
                  (
                    BuildContext context,
                    ExpressiveMenuAnchorState menu,
                    Widget? _,
                  ) => _pill(
                    icon: priority == TodoPriority.none
                        ? FontAwesomeIcons.flag
                        : FontAwesomeIcons.solidFlag,
                    iconColor: TodoLabels.priorityColor(scheme, priority),
                    label: priority == TodoPriority.none
                        ? l10n.todoFieldPriority
                        : TodoLabels.priority(l10n, priority),
                    set: priority != TodoPriority.none,
                    onTap: menu.toggle,
                  ),
            ),
            _pill(
              icon: FontAwesomeIcons.tag,
              iconColor: tags.isEmpty ? null : scheme.tertiary,
              label: tags.isEmpty
                  ? l10n.todoFieldTags
                  : tags.map((String tag) => '@$tag').join(' '),
              set: tags.isNotEmpty,
              onTap: onPickTags,
              onClear: tags.isEmpty ? null : onClearTags,
            ),
          ],
        ),
      ),
    );
  }
}

/// 属性按钮排成一行时彼此留 8 的间隔，在 40 高的横向列表里竖直居中。
Widget _pill({
  required FaIconData icon,
  required String label,
  required bool set,
  required VoidCallback onTap,
  VoidCallback? onClear,
  Color? iconColor,
}) {
  return Padding(
    padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
    child: Center(
      child: TodoFieldPill(
        icon: icon,
        label: label,
        set: set,
        onTap: onTap,
        onClear: onClear,
        iconColor: iconColor,
        maxLabelWidth: 180,
      ),
    ),
  );
}
