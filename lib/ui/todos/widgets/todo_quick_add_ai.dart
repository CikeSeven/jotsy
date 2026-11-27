part of 'todo_quick_add_sheet.dart';

/// 快速新建的“AI 整理”：把输入框里的一段话交给 AI 整理成多条待办，预览
/// 在输入框下面逐条长出（可勾掉、改标题、去掉认出的值），确认后与拆成多条
/// 一样一次建好（`createTodos`，同一事务），落进“已添加”堆栈。入口只在
/// AI 助手的待办模块可用时出现。
extension _QuickAddAi on _QuickAddSheetState {
  void _organize() {
    final text = _title.text.trim();
    // 出错后的“重试”也走这里：只挡住正在生成的。
    if (text.isEmpty || _ai.running) return;
    unawaited(
      startTodoAiOrganize(
        context,
        ref,
        _ai,
        text: text,
        today: _today,
        lists: ref.read(todoListsProvider).value ?? const <TodoListRow>[],
        tags: <String>[
          for (final usage
              in ref.read(todoTagsProvider).value ?? const <TodoTagUsage>[])
            usage.name,
        ],
      ),
    );
  }

  Future<void> _useAi() async {
    final inputs = <TodoInput>[
      for (final item in _ai.chosen)
        if (item.title.trim().isNotEmpty)
          _draft.inputForAi(
            item.copyWith(title: item.title.trim()),
            linkedDiaryId: widget.preset.linkedDiaryId,
          ),
    ];
    _ai.reset();
    await _create(inputs);
  }

  /// 输入框旁的“AI 整理”按钮；不可用时不占位。
  Widget? _aiButton({required bool available, required bool canSubmit}) {
    if (!available) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: IconButton(
        tooltip: context.l10n.todoAiOrganize,
        onPressed: canSubmit && !_aiActive ? _organize : null,
        icon: const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 16),
      ),
    );
  }

  Widget _aiPreview(List<TodoListRow> lists, DateTime today) {
    final l10n = context.l10n;
    return ListItemPresence(
      visible: _aiActive,
      appearing: _aiActive,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      child: TodoAiPreview<TodoAiItem>(
        drafts: _ai,
        title: l10n.todoAiOrganizeTitle,
        useLabel: l10n.todoAiAddTodos,
        onUse: () => unawaited(_useAi()),
        onRetry: _organize,
        itemBuilder: (BuildContext context, int index, TodoAiItem item) =>
            TodoAiOrganizeItem(
              item: item,
              on: _ai.isOn(index),
              today: today,
              lists: lists,
              onToggle: () => _ai.toggle(index),
              onEdit: (TodoAiItem next) => _ai.edit(index, next),
            ),
      ),
    );
  }
}
