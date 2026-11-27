import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../widgets/list_item_presence.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/todo_navigation.dart';
import '../controllers/todo_reminder_permission.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_quick_add_draft.dart';
import '../viewmodels/todo_quick_parse.dart';
import '../viewmodels/todo_reminder_pick.dart';
import 'todo_added_stack.dart';
import 'todo_due_sheet.dart';
import 'todo_list_picker_sheet.dart';
import 'todo_quick_add_fields.dart';
import 'todo_quick_split_prompt.dart';
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
/// 识别出的日期 / 重复 / 提醒 / 清单 / 优先级直接落在属性按钮上（与手动
/// 选的一样显示，手动选的优先；点 × 清除时同时不再识别这一种），输入框里
/// 识别出的片段高亮淡入。按回车或发送键即写库，面板留着、只清空标题，便于
/// 连着记几条：刚添加的落进上方“已添加 N 条”的小堆栈（[TodoAddedStack]，
/// 可点开、可撤销）；手动选的属性保留给下一条。粘贴了多行时提示“拆成 N 条
/// 待办？”，拆开时每行各自识别。关掉面板就结束。
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

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet>
    with SingleTickerProviderStateMixin {
  late final TodoQuickInputController _title = TodoQuickInputController(
    text: widget.preset.title,
  )..fade = _highlightFade;
  late final AnimationController _highlightFade = AnimationController(
    vsync: this,
    value: 1,
  );
  final FocusNode _focus = FocusNode();

  late final TodoQuickAddDraft _draft = TodoQuickAddDraft(
    listId: widget.preset.listId,
    dueDate: widget.preset.dueDate,
    priority: widget.preset.priority,
  );
  bool _saving = false;

  /// 拆分提示上写的行数（最近一次有多行时的）。
  int _splitCount = 2;

  /// 这次打开面板后添加的（“已添加”堆栈）。
  final List<TodoAddedItem> _added = <TodoAddedItem>[];

  @override
  void initState() {
    super.initState();
    _title.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _title.removeListener(_onControllerChanged);
    _title.dispose();
    _highlightFade.dispose();
    _focus.dispose();
    super.dispose();
  }

  DateTime get _today => ref.read(todoTodayProvider);

  int get _allDayMinute => ref.read(todoSettingsProvider).allDayReminderMinute;

  TodoQuickParse _parseText(String text) => todoQuickParseOf(
    text,
    enabled: ref.read(todoSettingsProvider).smartParse,
    today: _today,
    lists: ref.read(todoListsProvider).value ?? const <TodoListRow>[],
    ignore: _draft.ignore,
  );

  TodoQuickParse _parse() => _parseText(_title.text);

  /// 控制器的通知里只有文字或选区变了才重新识别：高亮淡入的每一帧也会
  /// 通知（让输入框重画），不能拿来重算。
  TextEditingValue? _lastValue;

  void _onControllerChanged() {
    if (_title.value == _lastValue) return;
    _lastValue = _title.value;
    _onChanged();
  }

  void _onChanged() {
    if (_title.text.isEmpty) _draft.ignored.clear();
    final ranges = <TextRange>[
      for (final token in _parse().tokens) token.range,
    ];
    final gained = _title.gainsHighlights(ranges);
    _title.highlights = ranges;
    if (gained) {
      _highlightFade.duration = ExpressiveMotion.duration(
        context,
        ExpressiveMotion.fast,
      );
      unawaited(_highlightFade.forward(from: 0));
    }
    setState(() {});
  }

  TodoInput? _inputFor(String raw, TodoQuickParse parse) => _draft.inputFor(
    raw,
    parse,
    allDayMinute: _allDayMinute,
    linkedDiaryId: widget.preset.linkedDiaryId,
  );

  /// 写库：[inputs] 依次建好，记进“已添加”，清空输入接着记。
  Future<void> _create(List<TodoInput> inputs) async {
    if (inputs.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final ids = await ref.read(appDatabaseProvider).createTodos(inputs);
      if (inputs.any((TodoInput input) => input.reminders.isNotEmpty) &&
          mounted) {
        unawaited(ensureTodoReminderPermission(context, ref));
      }
      _added.addAll(<TodoAddedItem>[
        for (var i = 0; i < ids.length; i++)
          TodoAddedItem(id: ids[i], title: inputs[i].title),
      ]);
      _draft.ignored.clear();
      _title.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) _focus.requestFocus();
  }

  Future<void> _submit() async {
    final input = _inputFor(_title.text, _parse());
    if (input != null) await _create(<TodoInput>[input]);
  }

  /// 输入里非空的几行（粘贴了多行时提示拆分）。
  List<String> get _lines => <String>[
    for (final line in _title.text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  /// 每行各自识别、各建一条。
  Future<void> _split() async {
    await _create(<TodoInput>[
      for (final line in _lines) ?_inputFor(line, _parseText(line)),
    ]);
  }

  void _keepOne() {
    final text = _lines.join(' ');
    _title.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _undoAdded(String id) async {
    setState(() => _added.removeWhere((TodoAddedItem item) => item.id == id));
    await ref.read(appDatabaseProvider).deleteTodo(id);
  }

  Future<void> _pickDue(TodoQuickParse parse) async {
    final choice = await showTodoDueSheet(
      context,
      date: _draft.effDate(parse),
      minute: _draft.effMinute(parse),
      today: _today,
    );
    if (choice == null || !mounted) return;
    setState(
      () => _draft.pickDue(
        choice.date,
        choice.minute,
        parse,
        allDayMinute: _allDayMinute,
      ),
    );
    _onChanged();
  }

  Future<void> _pickReminders(TodoQuickParse parse) async {
    final due = _draft.effDate(parse) ?? _today;
    await showTodoReminderSheet(
      context,
      reminders: _draft.effReminders(parse, _allDayMinute),
      dueDate: due,
      dueMinute: _draft.effDate(parse) == null ? null : _draft.effMinute(parse),
      allDayMinute: _allDayMinute,
      onChanged: (List<TodoReminder> next) {
        setState(() => _draft.setReminders(next, parse, due));
        if (next.isNotEmpty) {
          unawaited(ensureTodoReminderPermission(context, ref));
        }
      },
      onDueMoved: (TodoDueMove move) =>
          setState(() => _draft.moveDue(move.date, move.minute)),
    );
    _onChanged();
  }

  Future<void> _pickRepeat(TodoQuickParse parse) async {
    final anchor = _draft.effDate(parse) ?? _today;
    final choice = await showTodoRepeatSheet(
      context,
      current: _draft.effRepeat(parse),
      anchor: anchor,
    );
    if (choice == null || !mounted) return;
    setState(() => _draft.setRepeat(choice.rule, parse, anchor));
    _onChanged();
  }

  Future<void> _pickList() async {
    final choice = await showTodoListPickerSheet(
      context,
      current: _draft.listId,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _draft
        ..listId = choice.listId
        ..listPicked = true;
    });
    _onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    ref.watch(todoSettingsProvider.select((s) => s.smartParse));
    final today = ref.watch(todoTodayProvider);
    final parse = _parse();
    final dueDate = _draft.effDate(parse);
    final listId = _draft.effList(parse);
    TodoListRow? list;
    for (final item in lists) {
      if (item.listId == listId) list = item;
    }
    final canSubmit = _title.text.trim().isNotEmpty && !_saving;
    final lines = _lines.length;
    // 收起途中仍写上一次的行数，不闪成“拆成 0 条”。
    if (lines >= 2) _splitCount = lines;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );

    return TodoSheetBody(
      title: l10n.todoNew,
      children: <Widget>[
        AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.spatial,
          alignment: AlignmentDirectional.topStart,
          child: TodoAddedStack(
            items: _added,
            onOpen: (String id) => unawaited(openTodoDetail(context, id)),
            onUndo: (String id) => unawaited(_undoAdded(id)),
          ),
        ),
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
        ListItemPresence(
          visible: lines >= 2,
          appearing: lines >= 2,
          duration: duration,
          child: TodoQuickSplitPrompt(
            count: _splitCount,
            onSplit: () => unawaited(_split()),
            onKeepOne: _keepOne,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        TodoQuickAddFields(
          today: today,
          dueDate: dueDate,
          dueMinute: dueDate == null ? null : _draft.effMinute(parse),
          reminders: _draft.effReminders(parse, _allDayMinute),
          repeat: dueDate == null ? null : _draft.effRepeat(parse),
          list: list,
          priority: _draft.effPriority(parse),
          onPickDue: () => unawaited(_pickDue(parse)),
          onClearDue: () {
            setState(_draft.clearDue);
            _onChanged();
          },
          onPickReminders: () => unawaited(_pickReminders(parse)),
          onClearReminders: () => setState(
            () => _draft
              ..reminders = const <TodoReminder>[]
              ..ignored.add(TodoQuickTokenKind.reminder),
          ),
          onPickRepeat: () => unawaited(_pickRepeat(parse)),
          onClearRepeat: () => setState(
            () => _draft
              ..repeat = null
              ..ignored.add(TodoQuickTokenKind.repeat),
          ),
          onPickList: () => unawaited(_pickList()),
          onPriority: (TodoPriority value) {
            setState(() {
              _draft
                ..priority = value
                ..priorityPicked = true;
            });
            _onChanged();
          },
        ),
        const SizedBox(height: AppSpacing.s),
      ],
    );
  }
}
