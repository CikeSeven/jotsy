part of 'todo_quick_add_sheet.dart';

/// 快速新建面板的写库：发送一条、多行拆成多条、合成一行，以及撤销“已添加”
/// 里的某条。写完清空输入接着记（面板留着）。
extension _QuickAddSubmit on _QuickAddSheetState {
  /// 写库：[inputs] 依次建好，记进“已添加”，清空输入接着记。
  Future<void> _create(List<TodoInput> inputs) async {
    if (inputs.isEmpty || _saving) return;
    _update(() => _saving = true);
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
      _draft.resetIgnored();
      _title.clear();
    } finally {
      if (mounted) _update(() => _saving = false);
    }
    if (mounted) _focus.requestFocus();
  }

  Future<void> _submit() async {
    // AI 整理的预览开着时，回车不另把原文建成一条（先用或放弃预览）。
    if (_aiActive) return;
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
    _update(() => _added.removeWhere((TodoAddedItem item) => item.id == id));
    await ref.read(appDatabaseProvider).deleteTodo(id);
  }
}
