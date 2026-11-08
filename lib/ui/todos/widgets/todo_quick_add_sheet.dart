import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/todo_reminder_permission.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_list_style.dart';
import '../viewmodels/todo_quick_parse.dart';
import 'todo_due_sheet.dart';
import 'todo_field_pill.dart';
import 'todo_labels.dart';
import 'todo_list_picker_sheet.dart';
import 'todo_quick_input.dart';
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

/// 快速新建待办：大号输入框（智能识别的片段高亮）+ 右侧主色圆形发送键，
/// 下面一排属性按钮（日期、提醒、重复、清单、优先级；设了值的为
/// `secondaryContainer` 底并写出值，带 × 清除）。
///
/// 识别出的日期 / 清单 / 优先级直接落在属性按钮上（与手动选的一样显示，
/// 手动选的优先；点 × 清除时同时不再识别这一种）。按回车或发送键即写库，
/// 面板留着、只清空标题，便于连着记几条；手动选的属性保留给下一条。关掉
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
  late final TodoQuickInputController _title = TodoQuickInputController(
    text: widget.preset.title,
  );
  final FocusNode _focus = FocusNode();
  final Set<TodoQuickTokenKind> _ignored = <TodoQuickTokenKind>{};

  // 日期、清单、优先级：起初是视图预填的值（识别出的会盖过它），手动选过
  // （[_duePicked] 等）之后以手动的为准、这一种不再识别。
  late String? _listId = widget.preset.listId;
  bool _listPicked = false;
  late DateTime? _dueDate = widget.preset.dueDate;
  int? _dueMinute;
  bool _duePicked = false;
  late TodoPriority _priority = widget.preset.priority;
  bool _priorityPicked = false;
  List<TodoReminder> _reminders = const <TodoReminder>[];
  TodoRepeatRule? _repeat;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onChanged);
  }

  @override
  void dispose() {
    _title.removeListener(_onChanged);
    _title.dispose();
    _focus.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  TodoQuickParse _parse() => todoQuickParseOf(
    _title.text,
    enabled: ref.read(todoSettingsProvider).smartParse,
    today: _today,
    lists: ref.read(todoListsProvider).value ?? const <TodoListRow>[],
    ignore: <TodoQuickTokenKind>{
      ..._ignored,
      // 手动选过的种类不再识别，原文留在标题里。
      if (_duePicked) ...<TodoQuickTokenKind>{
        TodoQuickTokenKind.date,
        TodoQuickTokenKind.time,
      },
      if (_listPicked) TodoQuickTokenKind.list,
      if (_priorityPicked) TodoQuickTokenKind.priority,
    },
  );

  // 生效的值：手动选的 > 识别出的 > 视图预填的。
  DateTime? _effDate(TodoQuickParse p) => p.date ?? _dueDate;
  int? _effMinute(TodoQuickParse p) => p.date != null ? p.minute : _dueMinute;
  String? _effList(TodoQuickParse p) => p.listId ?? _listId;
  TodoPriority _effPriority(TodoQuickParse p) => p.priority ?? _priority;

  void _onChanged() {
    if (_title.text.isEmpty) _ignored.clear();
    _title.highlights = <TextRange>[
      for (final token in _parse().tokens) token.range,
    ];
    setState(() {});
  }

  Future<void> _submit() async {
    final parse = _parse();
    final raw = _title.text.trim();
    final title = parse.title.isNotEmpty ? parse.title : raw;
    if (title.isEmpty || _saving) return;
    final dueDate = _effDate(parse);
    setState(() => _saving = true);
    try {
      await ref
          .read(appDatabaseProvider)
          .createTodo(
            TodoInput(
              title: title,
              listId: _effList(parse),
              priority: _effPriority(parse),
              dueDate: dueDate,
              dueMinute: dueDate == null ? null : _effMinute(parse),
              reminders: dueDate == null ? const [] : _reminders,
              repeat: dueDate == null ? null : _repeat,
              linkedDiaryId: widget.preset.linkedDiaryId,
            ),
          );
      _ignored.clear();
      _title.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) _focus.requestFocus();
  }

  Future<void> _pickDue(TodoQuickParse parse) async {
    final choice = await showTodoDueSheet(
      context,
      date: _effDate(parse),
      minute: _effMinute(parse),
      today: _today,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _dueDate = choice.date;
      _dueMinute = choice.minute;
      _duePicked = true;
      if (choice.date == null) {
        // 去掉日期时提醒与重复一起失效，识别出的日期也不再要。
        _reminders = const <TodoReminder>[];
        _repeat = null;
        _ignored.addAll(<TodoQuickTokenKind>{
          TodoQuickTokenKind.date,
          TodoQuickTokenKind.time,
        });
      } else if (choice.minute == null) {
        // 全天时只对有时刻的待办有效的提醒随之去掉。
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
    _onChanged();
  }

  /// 加提醒 / 重复时把此刻生效的日期定下来（成为手动的值）：提醒与重复
  /// 都相对它，之后再改标题里的日期词不能让它们悄悄换了参照。没有日期时
  /// 取 [fallback]。
  void _adoptDue(TodoQuickParse parse, DateTime fallback) {
    _dueDate = _effDate(parse) ?? fallback;
    _dueMinute = _effDate(parse) == null ? null : _effMinute(parse);
    _duePicked = true;
  }

  Future<void> _pickReminders(TodoQuickParse parse) async {
    final settings = ref.read(todoSettingsProvider);
    final due = _effDate(parse) ?? _today;
    final minute = _effDate(parse) == null ? null : _effMinute(parse);
    await showTodoReminderSheet(
      context,
      reminders: _reminders,
      dueDate: due,
      dueMinute: minute,
      allDayMinute: settings.allDayReminderMinute,
      onChanged: (List<TodoReminder> next) {
        setState(() {
          _reminders = next;
          if (next.isNotEmpty && !_duePicked) _adoptDue(parse, due);
        });
        if (next.isNotEmpty) {
          unawaited(ensureTodoReminderPermission(context, ref));
        }
      },
    );
    _onChanged();
  }

  Future<void> _pickRepeat(TodoQuickParse parse) async {
    final anchor = _effDate(parse) ?? _today;
    final choice = await showTodoRepeatSheet(
      context,
      current: _repeat,
      anchor: anchor,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _repeat = choice.rule;
      if (choice.rule != null && !_duePicked) _adoptDue(parse, anchor);
    });
    _onChanged();
  }

  Future<void> _pickList() async {
    final choice = await showTodoListPickerSheet(context, current: _listId);
    if (choice == null || !mounted) return;
    setState(() {
      _listId = choice.listId;
      _listPicked = true;
    });
    _onChanged();
  }

  void _clearDue() {
    setState(() {
      _dueDate = null;
      _dueMinute = null;
      _duePicked = true;
      _reminders = const <TodoReminder>[];
      _repeat = null;
      _ignored.addAll(<TodoQuickTokenKind>{
        TodoQuickTokenKind.date,
        TodoQuickTokenKind.time,
      });
    });
    _onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    ref.watch(todoSettingsProvider.select((s) => s.smartParse));
    final parse = _parse();
    final today = _today;
    final dueDate = _effDate(parse);
    final dueMinute = dueDate == null ? null : _effMinute(parse);
    final listId = _effList(parse);
    TodoListRow? list;
    for (final item in lists) {
      if (item.listId == listId) list = item;
    }
    final priority = _effPriority(parse);
    final canSubmit = _title.text.trim().isNotEmpty && !_saving;

    return TodoSheetBody(
      title: l10n.todoNew,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.l, 0, AppSpacing.s, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _title,
                  focusNode: _focus,
                  autofocus: true,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => unawaited(_submit()),
                  // 回车不失焦：面板留着接着记，键盘不收起再弹出。
                  onEditingComplete: () {},
                  contextMenuBuilder: appTextContextMenuBuilder,
                  style: theme.textTheme.titleMedium,
                  decoration: InputDecoration(
                    hintText: l10n.todoQuickAddHint,
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: IconButton.filled(
                  tooltip: l10n.todoQuickAddSubmit,
                  onPressed: canSubmit ? () => unawaited(_submit()) : null,
                  icon: const FaIcon(FontAwesomeIcons.arrowUp, size: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
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
                  onTap: () => unawaited(_pickDue(parse)),
                  onClear: dueDate == null ? null : _clearDue,
                ),
                _pill(
                  icon: FontAwesomeIcons.bell,
                  label: _reminders.isEmpty
                      ? l10n.todoFieldReminders
                      : _reminders.length == 1
                      ? TodoLabels.reminder(context, _reminders.single)
                      : l10n.todoRemindersCount(_reminders.length),
                  set: _reminders.isNotEmpty,
                  onTap: () => unawaited(_pickReminders(parse)),
                  onClear: _reminders.isEmpty
                      ? null
                      : () =>
                            setState(() => _reminders = const <TodoReminder>[]),
                ),
                _pill(
                  icon: FontAwesomeIcons.repeat,
                  label: _repeat == null
                      ? l10n.todoFieldRepeat
                      : TodoLabels.repeat(l10n, _repeat),
                  set: _repeat != null,
                  onTap: () => unawaited(_pickRepeat(parse)),
                  onClear: _repeat == null
                      ? null
                      : () => setState(() => _repeat = null),
                ),
                _pill(
                  icon: list == null
                      ? TodoLabels.smartViewIcon(TodoSmartView.inbox)
                      : TodoListStyle.iconOfRow(list),
                  iconColor: list == null
                      ? null
                      : TodoListStyle.accentOf(
                          list.colorKey,
                          scheme,
                        ).onContainer,
                  label: list?.name ?? l10n.todoViewInbox,
                  set: list != null,
                  onTap: () => unawaited(_pickList()),
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
                        onPressed: () {
                          setState(() {
                            _priority = value;
                            _priorityPicked = true;
                          });
                          _onChanged();
                        },
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
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
      ],
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
