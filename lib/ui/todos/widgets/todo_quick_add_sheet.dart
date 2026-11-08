import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/todo_reminder_permission.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import 'todo_due_sheet.dart';
import 'todo_labels.dart';
import 'todo_list_picker_sheet.dart';
import 'todo_reminder_sheet.dart';
import 'todo_repeat_sheet.dart';
import 'todo_sheet.dart';

/// 快速新建待办时预先带上的字段（来自当前视图、日历选中日或日记）。
@immutable
class TodoQuickAddPreset {
  const TodoQuickAddPreset({
    this.listId,
    this.dueDate,
    this.priority = TodoPriority.none,
    this.title = '',
    this.linkedDiaryId,
  });

  final String? listId;
  final DateTime? dueDate;
  final TodoPriority priority;
  final String title;
  final String? linkedDiaryId;
}

/// 快速新建待办：标题输入框 + 一排胶囊（日期、提醒、重复、清单、优先级）。
///
/// 按回车或“添加”即写库，面板留着、只清空标题，便于连着记几条（新的一条
/// 立刻出现在面板后面的列表里）；日期、清单等胶囊的选择保留给下一条。关掉
/// 面板就结束。
Future<void> showTodoQuickAddSheet(
  BuildContext context, {
  TodoQuickAddPreset preset = const TodoQuickAddPreset(),
}) {
  return showTodoSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => _QuickAddSheet(preset: preset),
  );
}

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet({required this.preset});

  final TodoQuickAddPreset preset;

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.preset.title,
  );
  final FocusNode _focus = FocusNode();
  late String? _listId = widget.preset.listId;
  late DateTime? _dueDate = widget.preset.dueDate;
  int? _dueMinute;
  List<TodoReminder> _reminders = const <TodoReminder>[];
  TodoRepeatRule? _repeat;
  late TodoPriority _priority = widget.preset.priority;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _focus.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(appDatabaseProvider)
          .createTodo(
            TodoInput(
              title: title,
              listId: _listId,
              priority: _priority,
              dueDate: _dueDate,
              dueMinute: _dueMinute,
              reminders: _dueDate == null ? const [] : _reminders,
              repeat: _dueDate == null ? null : _repeat,
              linkedDiaryId: widget.preset.linkedDiaryId,
            ),
          );
      _title.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) _focus.requestFocus();
  }

  Future<void> _pickDue() async {
    final choice = await showTodoDueSheet(
      context,
      date: _dueDate,
      minute: _dueMinute,
      today: _today,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _dueDate = choice.date;
      _dueMinute = choice.minute;
      // 去掉日期时提醒与重复一起失效；全天 / 有时刻互换时，只对其中一种
      // 有效的提醒随之去掉。
      if (choice.date == null) {
        _reminders = const <TodoReminder>[];
        _repeat = null;
      } else if (choice.minute == null) {
        _reminders = <TodoReminder>[
          for (final r in _reminders)
            if (r.kind == TodoReminderKind.onDay) r,
        ];
      }
      final repeat = _repeat;
      if (repeat != null && choice.date != null) {
        _repeat = repeat.copyWith(anchor: choice.date);
      }
    });
  }

  Future<void> _pickReminders() async {
    final settings = ref.read(todoSettingsProvider);
    // 提醒相对截止日：没有日期时按今天算，真加上提醒时才把日期定下（只看
    // 一眼就关掉面板不改日期）。
    final due = _dueDate ?? _today;
    await showTodoReminderSheet(
      context,
      reminders: _reminders,
      dueDate: due,
      dueMinute: _dueMinute,
      allDayMinute: settings.allDayReminderMinute,
      onChanged: (List<TodoReminder> next) {
        setState(() {
          _reminders = next;
          if (next.isNotEmpty) _dueDate ??= due;
        });
        if (next.isNotEmpty) {
          unawaited(ensureTodoReminderPermission(context, ref));
        }
      },
    );
  }

  Future<void> _pickRepeat() async {
    final anchor = _dueDate ?? _today;
    final choice = await showTodoRepeatSheet(
      context,
      current: _repeat,
      anchor: anchor,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _repeat = choice.rule;
      if (choice.rule != null) _dueDate ??= anchor;
    });
  }

  Future<void> _pickList() async {
    final choice = await showTodoListPickerSheet(context, current: _listId);
    if (choice == null || !mounted) return;
    setState(() => _listId = choice.listId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    String? listName;
    for (final list in lists) {
      if (list.listId == _listId) listName = list.name;
    }
    final dueDate = _dueDate;
    final canSubmit = _title.text.trim().isNotEmpty && !_saving;
    return TodoSheetBody(
      title: l10n.todoNew,
      trailing: TextButton(
        onPressed: canSubmit ? _submit : null,
        child: Text(l10n.todoQuickAddSubmit),
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: TextField(
            controller: _title,
            focusNode: _focus,
            autofocus: true,
            maxLength: 500,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            contextMenuBuilder: appTextContextMenuBuilder,
            decoration: InputDecoration(
              hintText: l10n.todoQuickAddHint,
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: <Widget>[
              _Chip(
                icon: FontAwesomeIcons.calendar,
                label: dueDate == null
                    ? l10n.todoFieldDue
                    : TodoLabels.due(context, dueDate, _dueMinute, _today),
                active: dueDate != null,
                onPressed: _pickDue,
              ),
              _Chip(
                icon: FontAwesomeIcons.bell,
                label: _reminders.isEmpty
                    ? l10n.todoFieldReminders
                    : _reminders.length == 1
                    ? TodoLabels.reminder(context, _reminders.single)
                    : '${_reminders.length}',
                active: _reminders.isNotEmpty,
                onPressed: _pickReminders,
              ),
              _Chip(
                icon: FontAwesomeIcons.repeat,
                label: _repeat == null
                    ? l10n.todoFieldRepeat
                    : TodoLabels.repeat(l10n, _repeat),
                active: _repeat != null,
                onPressed: _pickRepeat,
              ),
              _Chip(
                icon: listName == null
                    ? TodoLabels.smartViewIcon(TodoSmartView.inbox)
                    : FontAwesomeIcons.listCheck,
                label: listName ?? l10n.todoViewInbox,
                active: _listId != null,
                onPressed: _pickList,
              ),
              ExpressiveMenuAnchor(
                menuChildren: <Widget>[
                  for (final priority in TodoPriority.values.reversed)
                    ExpressiveMenuItem(
                      selected: priority == _priority,
                      leadingIcon: FaIcon(
                        FontAwesomeIcons.solidFlag,
                        color:
                            TodoLabels.priorityColor(scheme, priority) ??
                            scheme.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() => _priority = priority),
                      child: Text(TodoLabels.priority(l10n, priority)),
                    ),
                ],
                builder:
                    (
                      BuildContext context,
                      ExpressiveMenuAnchorState menu,
                      Widget? _,
                    ) => _Chip(
                      icon: FontAwesomeIcons.flag,
                      label: _priority == TodoPriority.none
                          ? l10n.todoFieldPriority
                          : TodoLabels.priority(l10n, _priority),
                      active: _priority != TodoPriority.none,
                      color: TodoLabels.priorityColor(scheme, _priority),
                      onPressed: menu.toggle,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 快速新建面板里的一个胶囊：选了值时高亮。
class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
    this.color,
  });

  final FaIconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? (active ? scheme.primary : scheme.onSurfaceVariant);
    return ActionChip(
      avatar: FaIcon(icon, size: 14, color: tint),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      side: active ? BorderSide(color: tint) : null,
      onPressed: onPressed,
    );
  }
}
