part of 'todo_quick_add_sheet.dart';

/// 快速新建面板的属性面板：日期、提醒、重复、标签与清单。选完落到手上的值
/// （[TodoQuickAddDraft]），再按新的忽略集合重新识别（`_onChanged`）。
extension _QuickAddPickers on _QuickAddSheetState {
  Future<void> _pickDue(TodoQuickParse parse) async {
    final choice = await showTodoDueSheet(
      context,
      date: _draft.effDate(parse),
      minute: _draft.effMinute(parse),
      today: _today,
    );
    if (choice == null || !mounted) return;
    _update(
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
        _update(() => _draft.setReminders(next, parse, due));
        if (next.isNotEmpty) {
          unawaited(ensureTodoReminderPermission(context, ref));
        }
      },
      onDueMoved: (TodoDueMove move) =>
          _update(() => _draft.moveDue(move.date, move.minute)),
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
    _update(() => _draft.setRepeat(choice.rule, parse, anchor));
    _onChanged();
  }

  Future<void> _pickTags(TodoQuickParse parse) async {
    await showTodoTagPickerSheet(
      context,
      selected: _draft.effTags(parse),
      onChanged: (List<String> next) {
        if (mounted) _update(() => _draft.pickTags(next, parse));
      },
    );
    if (mounted) _onChanged();
  }

  Future<void> _pickList() async {
    final choice = await showTodoListPickerSheet(
      context,
      current: _draft.listId,
    );
    if (choice == null || !mounted) return;
    _update(() {
      _draft
        ..listId = choice.listId
        ..listPicked = true;
    });
    _onChanged();
  }
}
