part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 日记列表页业务控制器。
///
/// 职责边界：
/// - 处理页面事件与业务流程（搜索、筛选、归档、删除、导航）；
/// - 与 Provider/数据库交互；
/// - 不直接构建任何 UI 组件。
class DiariesPageController {
  DiariesPageController(
    this._state, {
    required this.feedback,
    required this.transitionCoordinator,
  });

  final _DiariesPage _state;
  final DiariesPageFeedback feedback;
  final DiaryListTransitionCoordinator transitionCoordinator;

  void attachHomeHintVisibilityListener() {
    final listenable = _state.widget.homeHintVisibleListenable;
    if (listenable == null) {
      return;
    }
    _state._homeHintVisible = listenable.value;
    listenable.addListener(_onHomeHintVisibilityChanged);
  }

  void detachHomeHintVisibilityListener(ValueListenable<bool>? listenable) {
    listenable?.removeListener(_onHomeHintVisibilityChanged);
  }

  void handleHomeHintListenableUpdate({
    required ValueListenable<bool>? previous,
    required ValueListenable<bool>? next,
  }) {
    if (previous == next) {
      return;
    }
    detachHomeHintVisibilityListener(previous);
    attachHomeHintVisibilityListener();
  }

  void _onHomeHintVisibilityChanged() {
    final visible = _state.widget.homeHintVisibleListenable?.value ?? false;
    if (visible == _state._homeHintVisible || !_state.mounted) {
      return;
    }
    _state.setState(() {
      _state._homeHintVisible = visible;
    });
  }

  void clearSelection() {
    if (_state._selectedDiaryIds.isEmpty) {
      return;
    }
    _state.setState(_state._selectedDiaryIds.clear);
  }

  void handleBackPressed() {
    if (_state._isSelectionMode) {
      clearSelection();
      return;
    }
    if (_state._isSearchMode) {
      exitSearchModeAndClear();
    }
  }

  void enterSearchMode() {
    if (_state._isSelectionMode || _state._isSearchMode) {
      return;
    }
    _state.setState(() {
      _state._isSearchMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_state.mounted) {
        return;
      }
      _state._searchFocusNode.requestFocus();
    });
  }

  void exitSearchModeAndClear() {
    clearSearch(exitSearchMode: true);
    _state._searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void clearSearchInPlace() {
    clearSearch(exitSearchMode: false);
    _state._searchFocusNode.requestFocus();
  }

  void onSearchChanged(String value) {
    if (_state._searchInput != value) {
      _state.setState(() {
        _state._searchInput = value;
      });
    }
    _state._searchDebounceTimer?.cancel();
    _state._searchDebounceTimer = Timer(_DiariesPage._searchDebounceDuration, () {
      _applySearchKeyword(value);
    });
  }

  void _applySearchKeyword(String rawValue) {
    final normalized = rawValue.trim();
    if (normalized == _state._effectiveSearchKeyword) {
      return;
    }
    _state._effectiveSearchKeyword = normalized;
    transitionCoordinator.queueFilterMutation(() {
      _state.ref.read(diaryFilterProvider.notifier).setKeyword(normalized);
    });
  }

  void clearSearch({required bool exitSearchMode}) {
    _state._searchDebounceTimer?.cancel();
    final shouldResetKeyword =
        _state._effectiveSearchKeyword.isNotEmpty ||
        _state._searchInput.trim().isNotEmpty ||
        _state._searchController.text.trim().isNotEmpty;
    _state._searchController.clear();

    if (_state.mounted) {
      _state.setState(() {
        _state._searchInput = '';
        _state._effectiveSearchKeyword = '';
        if (exitSearchMode) {
          _state._isSearchMode = false;
          _state._isSearchAnimating = false;
        }
      });
    } else {
      _state._searchInput = '';
      _state._effectiveSearchKeyword = '';
      if (exitSearchMode) {
        _state._isSearchMode = false;
        _state._isSearchAnimating = false;
      }
    }

    if (shouldResetKeyword) {
      transitionCoordinator.queueFilterMutation(() {
        _state.ref.read(diaryFilterProvider.notifier).setKeyword('');
      });
    }
  }

  void toggleTagFilter(int tagId, bool selected) {
    transitionCoordinator.queueFilterMutation(() {
      _state.ref.read(diaryFilterProvider.notifier).toggleTag(tagId, selected);
    });
  }

  void clearTagFilters() {
    if (_state.ref.read(diaryFilterProvider).selectedTagIds.isEmpty) {
      return;
    }
    transitionCoordinator.queueFilterMutation(() {
      _state.ref.read(diaryFilterProvider.notifier).clearTags();
    });
  }

  void openEditor({
    String? diaryId,
    bool restoreCreateDraft = true,
  }) {
    _state._searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    unawaited(
      Navigator.of(_state.context)
          .push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) {
                return EditDiaryPage(
                  diaryId: diaryId,
                  entryMode:
                      diaryId == null
                          ? EditDiaryEntryMode.create
                          : EditDiaryEntryMode.edit,
                  restoreCreateDraft: restoreCreateDraft,
                );
              },
            ),
          )
          .then((_) {
            if (!_state.mounted) {
              return;
            }
            refreshAfterEditorReturn();
            _state._searchFocusNode.unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          }),
    );
  }

  void refreshAfterEditorReturn() {
    _state.ref.invalidate(filteredDiariesProvider);
    _state.setState(() {
      _state._listLayoutEpoch += 1;
    });
  }

  Future<void> openCreateEditorWithDraftPrompt() async {
    final settingsService = await _state.ref.read(settingsServiceProvider.future);
    final existingDraft = _tryDecodeCreateDraft(
      settingsService.createDiaryDraftRaw,
    );
    if (!_state.mounted) {
      return;
    }

    var restoreCreateDraft = true;
    if (existingDraft?.hasContent == true) {
      final decision = await feedback.showCreateDraftDecisionDialog();
      if (!_state.mounted || decision == null) {
        return;
      }
      if (decision == _CreateDraftDecision.newEmpty) {
        await settingsService.clearCreateDiaryDraft();
        restoreCreateDraft = false;
      }
    }

    openEditor(restoreCreateDraft: restoreCreateDraft);
  }

  NewDiaryDraft? _tryDecodeCreateDraft(String? rawDraft) {
    if (rawDraft == null || rawDraft.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(rawDraft);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return NewDiaryDraft.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteSelectedDiaries() async {
    if (_state._selectedDiaryIds.isEmpty) {
      return;
    }

    final targetIds = _state._selectedDiaryIds.toList(growable: false);
    final confirmed = await feedback.showDeleteSelectedConfirmDialog(
      targetIds.length,
    );
    if (!_state.mounted || !confirmed) {
      return;
    }

    _state.setState(() {
      _state._selectedDiaryIds.clear();
    });
    transitionCoordinator.startHideAnimations(targetIds);

    final db = _state.ref.read(appDatabaseProvider);
    final failedIds = <String>[];
    for (final diaryId in targetIds) {
      try {
        await db.softDeleteDiary(diaryId, touchUpdatedAt: false);
      } catch (_) {
        failedIds.add(diaryId);
      }
    }

    if (!_state.mounted) {
      return;
    }

    if (failedIds.isNotEmpty) {
      final succeededIds =
          targetIds.where((id) => !failedIds.contains(id)).toList(growable: false);
      for (final diaryId in succeededIds) {
        await db.restoreDiary(diaryId, touchUpdatedAt: false);
      }
      if (!_state.mounted) {
        return;
      }
      transitionCoordinator.revealDiaries(targetIds, animate: true);
      _state.setState(() {
        _state._selectedDiaryIds.addAll(targetIds);
      });
      await feedback.showInfoSnackBar('删除失败，请重试');
      return;
    }

    final undoRequested = await feedback.showUndoSnackBar(
      message: '已删除 ${targetIds.length} 条日记',
      duration: _DiariesPage._deleteUndoSnackDuration,
    );

    if (!_state.mounted) {
      return;
    }

    if (undoRequested) {
      for (final diaryId in targetIds) {
        await db.restoreDiary(diaryId, touchUpdatedAt: false);
      }
      if (!_state.mounted) {
        return;
      }
      transitionCoordinator.revealDiaries(targetIds, animate: true);
      await feedback.showInfoSnackBar('已恢复删除的日记');
      return;
    }

    _state.setState(() {
      _state._optimisticHiddenDiaryIds.removeAll(targetIds);
      _state._pendingHideDiaryIds.removeAll(targetIds);
      _state._appearingDiaryIds.removeAll(targetIds);
    });
    transitionCoordinator.clearTransitionTimers(targetIds);
  }

  Future<void> archiveSelectedDiaries() async {
    if (_state._selectedDiaryIds.isEmpty) {
      return;
    }
    await _archiveDiaries(
      _state._selectedDiaryIds.toList(growable: false),
      clearSelection: true,
      showUndoSnack: true,
    );
  }

  Future<void> archiveDiaryBySwipe(String diaryId) async {
    await _archiveDiaries(
      <String>[diaryId],
      clearSelection: false,
      showUndoSnack: true,
      animateHide: false,
    );
  }

  Future<void> _archiveDiaries(
    List<String> diaryIds, {
    required bool clearSelection,
    required bool showUndoSnack,
    bool animateHide = true,
  }) async {
    final targetIds =
        diaryIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false);
    if (targetIds.isEmpty) {
      return;
    }
    if (targetIds.any(_state._archivingDiaryIds.contains)) {
      return;
    }

    _state.setState(() {
      if (clearSelection) {
        _state._selectedDiaryIds.removeAll(targetIds);
      }
      _state._archivingDiaryIds.addAll(targetIds);
    });
    if (animateHide) {
      transitionCoordinator.startHideAnimations(targetIds);
    } else {
      transitionCoordinator.hideDiariesImmediately(targetIds);
    }

    final db = _state.ref.read(appDatabaseProvider);
    final failedIds = <String>[];
    for (final diaryId in targetIds) {
      try {
        await db.archiveDiary(diaryId, touchUpdatedAt: false);
      } catch (_) {
        failedIds.add(diaryId);
      }
    }

    if (!_state.mounted) {
      return;
    }

    if (failedIds.isNotEmpty) {
      final succeededIds =
          targetIds.where((id) => !failedIds.contains(id)).toList(growable: false);
      for (final diaryId in succeededIds) {
        await db.unarchiveDiary(diaryId, touchUpdatedAt: false);
      }
      if (!_state.mounted) {
        return;
      }
      _state.setState(() {
        _state._archivingDiaryIds.removeAll(targetIds);
        if (clearSelection) {
          _state._selectedDiaryIds.addAll(targetIds);
        }
      });
      transitionCoordinator.revealDiaries(targetIds, animate: true);
      await feedback.showInfoSnackBar('归档失败，请重试');
      return;
    }

    if (showUndoSnack) {
      final undoRequested = await feedback.showUndoSnackBar(
        message: '已归档 ${targetIds.length} 条日记',
        duration: _DiariesPage._archiveUndoSnackDuration,
      );

      if (!_state.mounted) {
        return;
      }

      if (undoRequested) {
        for (final diaryId in targetIds) {
          await db.unarchiveDiary(diaryId, touchUpdatedAt: false);
        }
        if (!_state.mounted) {
          return;
        }
        _state.setState(() {
          _state._archivingDiaryIds.removeAll(targetIds);
        });
        transitionCoordinator.revealDiaries(targetIds, animate: true);
        await feedback.showInfoSnackBar('已恢复归档的日记');
        return;
      }
    }

    _state.setState(() {
      _state._optimisticHiddenDiaryIds.removeAll(targetIds);
      _state._pendingHideDiaryIds.removeAll(targetIds);
      _state._appearingDiaryIds.removeAll(targetIds);
      _state._archivingDiaryIds.removeAll(targetIds);
    });
    transitionCoordinator.clearTransitionTimers(targetIds);
  }

  void toggleSelection(String noteId, {bool forceSelect = false}) {
    var shouldClearSearchKeyword = false;
    var shouldUnfocusSearch = false;
    _state.setState(() {
      if (forceSelect && _state._isSearchMode) {
        _state._searchDebounceTimer?.cancel();
        shouldClearSearchKeyword = _state._effectiveSearchKeyword.isNotEmpty ||
            _state._searchInput.trim().isNotEmpty;
        shouldUnfocusSearch = true;
        _state._searchController.clear();
        _state._searchInput = '';
        _state._effectiveSearchKeyword = '';
        _state._isSearchMode = false;
        _state._isSearchAnimating = false;
      }
      if (forceSelect) {
        _state._selectedDiaryIds.add(noteId);
        return;
      }
      if (_state._selectedDiaryIds.contains(noteId)) {
        _state._selectedDiaryIds.remove(noteId);
      } else {
        _state._selectedDiaryIds.add(noteId);
      }
    });
    if (shouldClearSearchKeyword) {
      _state.ref.read(diaryFilterProvider.notifier).setKeyword('');
    }
    if (shouldUnfocusSearch) {
      _state._searchFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void openArchivedPage() {
    Navigator.of(_state.context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const ArchivedDiariesPage(),
      ),
    );
  }

  void onMenuSelected(DiaryMenuAction action) {
    _state.setState(() {
      switch (action) {
        case DiaryMenuAction.sortUpdatedDesc:
          _state._sortMode = DiarySortMode.updatedDesc;
          break;
        case DiaryMenuAction.sortUpdatedAsc:
          _state._sortMode = DiarySortMode.updatedAsc;
          break;
        case DiaryMenuAction.sortTitleAsc:
          _state._sortMode = DiarySortMode.titleAsc;
          break;
        case DiaryMenuAction.layoutList:
          _state._layoutMode = DiaryLayoutMode.list;
          break;
        case DiaryMenuAction.layoutWaterfall:
          _state._layoutMode = DiaryLayoutMode.waterfall;
          break;
      }
    });
    _persistViewPreferences();
  }

  void _persistViewPreferences() {
    final settingsService = _state.ref.read(settingsServiceProvider).asData?.value;
    if (settingsService == null) {
      return;
    }
    unawaited(settingsService.setDiarySortModeRaw(_state._sortMode.name));
    unawaited(settingsService.setDiaryLayoutModeRaw(_state._layoutMode.name));
  }

  void loadViewPreferencesIfNeeded(SettingsService settingsService) {
    if (_state._viewPreferencesLoaded) {
      return;
    }
    final prefs = DiaryViewPreferences.fromRaw(
      sortRaw: settingsService.diarySortModeRaw,
      layoutRaw: settingsService.diaryLayoutModeRaw,
    );
    _state._sortMode = prefs.sortMode;
    _state._layoutMode = prefs.layoutMode;
    _state._viewPreferencesLoaded = true;
  }

  List<DiaryWithTags> buildVisibleItems(List<DiaryWithTags> items) {
    final visibleItems =
        items.where((DiaryWithTags item) {
          return !_state._optimisticHiddenDiaryIds.contains(item.diary.diaryId);
        }).toList();
    _sortDiaries(visibleItems);
    return visibleItems;
  }

  List<Tag> buildTagFiltersForDisplay({
    required List<Tag> allTags,
    required List<DiaryWithTags> visibleItems,
    required String keyword,
  }) {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return allTags;
    }

    final visibleTagIds = <int>{};
    for (final item in visibleItems) {
      for (final tag in item.tags) {
        visibleTagIds.add(tag.id);
      }
    }

    return allTags.where((tag) => visibleTagIds.contains(tag.id)).toList();
  }

  void _sortDiaries(List<DiaryWithTags> items) {
    switch (_state._sortMode) {
      case DiarySortMode.updatedDesc:
        items.sort((a, b) => b.diary.updatedAt.compareTo(a.diary.updatedAt));
        break;
      case DiarySortMode.updatedAsc:
        items.sort((a, b) => a.diary.updatedAt.compareTo(b.diary.updatedAt));
        break;
      case DiarySortMode.titleAsc:
        items.sort(
          (a, b) => a.diary.title.toLowerCase().compareTo(
            b.diary.title.toLowerCase(),
          ),
        );
        break;
    }
  }

  void dispose() {
    _state._searchDebounceTimer?.cancel();
    detachHomeHintVisibilityListener(_state.widget.homeHintVisibleListenable);
  }
}
