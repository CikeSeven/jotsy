// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 编辑页的 AI 功能：写作面板（工具栏、`/` 菜单、选区菜单打开）与智能填写
/// （⋮ 菜单、标题旁按钮）。
///
/// 面板状态机：关闭 → 打开（建会话、记下选区、正文锁定、收起键盘）→ 生成
/// （会话流式接收，可停止）→ 应用（一次事务写回正文、关闭面板）或关闭
/// （会话释放，进行中的生成随之取消）。私密日记在用户没允许时不打开，只
/// 提示原因。
extension EditDiaryAiFlow on EditDiaryController {
  /// 发给 AI 的“这篇日记”：标题、正文、日期与心情、标签取编辑中的值。
  AiContextDiary aiDiarySnapshot() {
    final meta = _state._meta.value;
    final tags = _state.ref.read(tagListProvider).value ?? const <Tag>[];
    return AiContextDiary(
      diaryId: _state.widget.diaryId ?? '',
      title: _state._titleController.text,
      contentText: _state._currentContentText,
      createdAt: _state._draftPublishAt ?? DateTime.now(),
      isArchived: false,
      mood: meta.moodEmoji,
      weather: meta.weather,
      location: meta.location,
      tags: [
        for (final tag in tags)
          if (meta.tagIds.contains(tag.id)) tag.name,
      ],
    );
  }

  /// 这篇日记能不能用单篇 AI 功能：已有日记看它是否私密；新建日记看要
  /// 收进的日记本里有没有私密的。不能用时提示原因。
  Future<bool> _aiAllowed() async {
    final ref = _state.ref;
    if (ref.read(aiPreferencesProvider).privacy.allowPrivate) return true;
    var allowed = await aiDiaryAllowed(ref, _state.widget.diaryId);
    if (allowed && _state.widget.diaryId == null) {
      final notebookIds = _state._meta.value.notebookIds;
      if (notebookIds.isNotEmpty) {
        final notebooks = await ref.read(notebooksProvider.future);
        allowed = !notebooks.any(
          (notebook) =>
              notebookIds.contains(notebook.id) &&
              notebook.effectiveVisibility != NotebookVisibility.normal,
        );
      }
    }
    if (!allowed && _state.mounted) {
      _showHint(_state.context.l10n.aiPanelPrivateBlocked);
    }
    return allowed;
  }

  /// 打开 / 关闭 AI 写作面板。[action] 给出时打开后立即执行它（`/` 菜单的
  /// “AI 续写”）。
  Future<void> toggleAiPanel({AiActionInfo? action}) async {
    if (_state._aiSession != null) {
      closeAiPanel();
      return;
    }
    if (_state._recordingPanelOpen || _state._mediaImportController.isBusy) {
      return;
    }
    // 先记下选区：确认私密时的 await 期间焦点可能变化。
    final selection = _state._contentController.selection;
    if (!await _aiAllowed() || !_state.mounted) return;
    final session = AiWritingSession(
      editor: _state._contentController,
      selection: selection,
    );
    _state.setState(() => _state._aiSession = session);
    FocusManager.instance.primaryFocus?.unfocus();
    if (action != null) await runAiAction(action);
  }

  void closeAiPanel() {
    final session = _state._aiSession;
    if (session == null) return;
    _state.setState(() => _state._aiSession = null);
    // 等面板这一帧卸载后再释放：面板的监听还挂在会话上。
    WidgetsBinding.instance.addPostFrameCallback((_) => session.dispose());
  }

  Future<void> runAiAction(AiActionInfo action) async {
    final session = _state._aiSession;
    if (session == null || !_state.mounted) return;
    await runAiWriting(
      _state.context,
      _state.ref,
      session,
      action: action,
      diary: aiDiarySnapshot(),
    );
  }

  Future<void> runAiInstruction(String instruction) async {
    final session = _state._aiSession;
    if (session == null || !_state.mounted) return;
    await runAiWriting(
      _state.context,
      _state.ref,
      session,
      instruction: instruction,
      diary: aiDiarySnapshot(),
    );
  }

  /// 写回结果并关闭面板：先解锁正文（面板打开时正文只读），再一次事务
  /// 写入，撤销一步回到原样。
  void applyAiResult(AiActionOutput output) {
    final session = _state._aiSession;
    if (session == null) return;
    final applied = session.apply(output);
    if (!applied) return;
    closeAiPanel();
    scheduleEditAutoSave();
    onCreateDraftInputChanged();
  }

  /// `/` 菜单的 AI 命令。
  Future<void> handleAiSlash(DiaryAiSlashCommand command) async {
    switch (command) {
      case DiaryAiSlashCommand.write:
        await toggleAiPanel();
      case DiaryAiSlashCommand.continueWriting:
        final l10n = _state.context.l10n;
        final prefs = _state.ref.read(aiPreferencesProvider);
        final action = aiWritingActions(
          l10n,
          l10n,
          prefs,
          includeHidden: true,
        ).firstWhere((item) => item.id == AiWritingAction.continueWriting.id);
        await toggleAiPanel(action: action);
      case DiaryAiSlashCommand.prompts:
        await _state._openAiPrompts();
    }
  }

  /// ⋮ 菜单与标题旁按钮：生成标题、推荐标签与心情。[titleOnly] 时只问
  /// 标题并直接填入（可撤销），否则弹出建议面板让用户勾选。
  Future<void> suggestWithAi({required bool titleOnly}) async {
    if (_state._aiBusy || !await _aiAllowed() || !_state.mounted) return;
    final ref = _state.ref;
    final tags = ref.read(tagListProvider).value ?? const <Tag>[];
    final moods = ref.read(moodOptionsProvider).value ?? const <String>[];
    _state.setState(() => _state._aiBusy = true);
    AiSuggestion? suggestion;
    try {
      suggestion = await requestAiSuggestion(
        _state.context,
        ref,
        diary: aiDiarySnapshot(),
        tags: [for (final tag in tags) tag.name],
        moods: moods,
      );
    } finally {
      if (_state.mounted) _state.setState(() => _state._aiBusy = false);
    }
    if (suggestion == null || suggestion.isEmpty || !_state.mounted) return;
    final l10n = _state.context.l10n;
    if (titleOnly) {
      final title = suggestion.title;
      if (title == null) {
        _showHint(l10n.aiSuggestNothing);
        return;
      }
      _applyAiTitle(title);
      return;
    }
    final selectedNames = {
      for (final tag in tags)
        if (_state._meta.value.tagIds.contains(tag.id)) tag.name,
    };
    final choice = await showAiSuggestionSheet(
      _state.context,
      suggestion: suggestion,
      selectedTags: selectedNames,
    );
    if (choice == null || choice.isEmpty || !_state.mounted) return;
    if (choice.title case final title?) _applyAiTitle(title);
    final names = [...choice.tags, ...choice.newTags];
    if (names.isNotEmpty) {
      final color = Theme.of(_state.context).colorScheme.primary.toARGB32();
      final result = await ref.read(appDatabaseProvider).ensureTagsByName([
        for (final name in names) (name: name, color: color),
      ]);
      for (final id in result.ids.values) {
        _state._meta.setTagSelected(id, true);
      }
    }
    if (choice.mood case final mood?) _state._meta.setMood(mood);
    if (_state.mounted) _showHint(l10n.aiSuggestApplied);
  }

  /// 填入标题；原来有标题时提示条带撤销，恢复原标题。
  void _applyAiTitle(String title) {
    final previous = _state._titleController.text;
    _state._titleController.text = title;
    final l10n = _state.context.l10n;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: _state.context,
        snackBar: SnackBar(
          persist: false,
          content: Text(l10n.aiSuggestTitleApplied),
          action: previous.isEmpty
              ? null
              : SnackBarAction(
                  label: l10n.commonUndo,
                  onPressed: () {
                    if (_state.mounted) _state._titleController.text = previous;
                  },
                ),
        ),
      ),
    );
  }
}
