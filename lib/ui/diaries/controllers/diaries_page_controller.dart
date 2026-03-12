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

  /// 页面状态对象。
  ///
  /// 该控制器是“事件编排层”，所有用户交互最终都会回写到这个 state。
  final _DiariesPage _state;

  /// 统一处理弹窗/SnackBar 的反馈层，避免流程代码到处散落提示逻辑。
  final DiariesPageFeedback feedback;

  /// 列表过渡协调器，集中控制筛选切换和项目删改时的过渡动画节奏。
  final DiaryListTransitionCoordinator transitionCoordinator;

  /// 监听 Home 级提示可见性，用于驱动 FAB 上移避让。
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

  /// Home 组件替换 listenable 时重新绑定监听，避免监听泄漏。
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

  /// 清空列表多选状态。
  void clearSelection() {
    if (_state._selectedDiaryIds.isEmpty) {
      return;
    }
    _state.setState(_state._selectedDiaryIds.clear);
  }

  /// 处理系统返回键：
  /// 1. 选择模式优先退出选择；
  /// 2. 其余场景交还系统路由栈。
  void handleBackPressed() {
    if (_state._isSelectionMode) {
      clearSelection();
    }
  }

  /// 打开独立搜索页。
  ///
  /// 使用淡入覆盖式路由，弱化“页面跳转”感，保持同场景搜索体验。
  void openSearchPage() {
    final selectedTagIds = <int>{..._state.ref.read(diaryFilterProvider).selectedTagIds};
    Navigator.of(_state.context).push(
      DiarySearchPage.buildRoute(
        initialTagIds: selectedTagIds,
      ),
    );
  }

  /// 切换标签筛选。实际写入动作会通过过渡协调器排队，确保列表过渡连续。
  void toggleTagFilter(int tagId, bool selected) {
    transitionCoordinator.queueFilterMutation(() {
      _state.ref.read(diaryFilterProvider.notifier).toggleTag(tagId, selected);
    });
  }

  /// 清空所有标签筛选条件。
  void clearTagFilters() {
    if (_state.ref.read(diaryFilterProvider).selectedTagIds.isEmpty) {
      return;
    }
    transitionCoordinator.queueFilterMutation(() {
      _state.ref.read(diaryFilterProvider.notifier).clearTags();
    });
  }

  /// 打开编辑页（新建或编辑）。
  ///
  /// 返回后会触发一次列表刷新，确保编辑后的内容及时反映到首页。
  void openEditor({
    String? diaryId,
    bool restoreCreateDraft = true,
  }) {
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
          }),
    );
  }

  /// 打开日记预览页（列表默认入口）。
  ///
  /// 预览页内可能触发删除或编辑：
  /// - 删除通过返回值触发撤销提示；
  /// - 其余数据变更依赖数据库流自动回推，避免强制刷新导致滚动回跳。
  void openPreview(String diaryId) {
    unawaited(
      Navigator.of(_state.context)
          .push<DiaryPreviewResult?>(
            MaterialPageRoute<DiaryPreviewResult?>(
              builder: (BuildContext context) {
                return DiaryPreviewPage(diaryId: diaryId);
              },
            ),
          )
          .then((DiaryPreviewResult? result) async {
            if (!_state.mounted) {
              return;
            }
            // 预览页返回不再强制触发列表重建：
            // - 列表本身由数据库流驱动，数据变更会自动刷新；
            // - 强制刷新会导致滚动位置回跳，影响“返回后继续浏览”体验。
            if (result == DiaryPreviewResult.deleted) {
              final undoRequested = await feedback.showUndoSnackBar(
                message: '已删除日记',
                duration: _DiariesPage._deleteUndoSnackDuration,
              );
              if (!_state.mounted || !undoRequested) {
                return;
              }
              try {
                final db = _state.ref.read(appDatabaseProvider);
                await db.restoreDiary(diaryId, touchUpdatedAt: false);
                if (!_state.mounted) {
                  return;
                }
                await feedback.showInfoSnackBar('已恢复删除的日记');
              } catch (_) {
                if (!_state.mounted) {
                  return;
                }
                await feedback.showInfoSnackBar('恢复失败，请重试');
              }
            }
          }),
    );
  }

  /// 从编辑页返回后主动触发刷新节拍。
  ///
  /// `invalidate` 让 Provider 重取数据，`_listLayoutEpoch` 用于刷新布局签名。
  void refreshAfterEditorReturn() {
    _state.ref.invalidate(filteredDiariesProvider);
    _state.setState(() {
      _state._listLayoutEpoch += 1;
    });
  }

  /// 处理“新建日记”入口：
  /// - 若存在未完成草稿，先弹窗让用户选择继续或清空新建；
  /// - 无草稿时直接进入创建页。
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

  /// 从本地存储字符串尝试解析草稿。
  ///
  /// 解析失败时返回 null，避免脏数据阻塞新建流程。
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

  /// 批量删除所选日记，并提供撤销入口。
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

    // 先在 UI 层启动“收起并隐藏”动画，再执行真实删除。
    _state.setState(() {
      _state._selectedDiaryIds.clear();
    });
    transitionCoordinator.startHideAnimations(targetIds);

    // 删除流程不更新 modified 时间，避免撤销后排序错位。
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

    // 任意失败则回滚已成功删除项，并恢复原选择态。
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

  /// 批量归档所选日记并提供撤销。
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

  /// 列表左滑单条归档入口。
  Future<void> archiveDiaryBySwipe(String diaryId) async {
    await _archiveDiaries(
      <String>[diaryId],
      clearSelection: false,
      showUndoSnack: true,
      animateHide: false,
    );
  }

  /// 执行归档主流程，复用多选与左滑两种入口。
  Future<void> _archiveDiaries(
    List<String> diaryIds, {
    required bool clearSelection,
    required bool showUndoSnack,
    bool animateHide = true,
  }) async {
    // 做 ID 去重与清洗，避免后续数据库操作出现重复请求。
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
    // 仅多选入口需要同步退出选择模式；左滑入口保持当前选择态不变。
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

    // 发生部分失败时回滚 UI + 数据，保证用户感知的一致性。
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

  /// 切换单条选中状态，支持强制选中（长按进入选择模式时使用）。
  void toggleSelection(String noteId, {bool forceSelect = false}) {
    _state.setState(() {
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
  }

  /// 打开归档页。
  void openArchivedPage() {
    Navigator.of(_state.context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const ArchivedDiariesPage(),
      ),
    );
  }

  /// 处理头部菜单动作（排序/布局切换）。
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

  /// 持久化当前视图偏好，确保下次打开页面仍保持同样展示方式。
  void _persistViewPreferences() {
    final settingsService = _state.ref.read(settingsServiceProvider).asData?.value;
    if (settingsService == null) {
      return;
    }
    unawaited(settingsService.setDiarySortModeRaw(_state._sortMode.name));
    unawaited(settingsService.setDiaryLayoutModeRaw(_state._layoutMode.name));
  }

  /// 首次进入页面时加载视图偏好，仅执行一次。
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

  /// 生成当前可见日记列表：
  /// 1. 排除正在归档动画中的项；
  /// 2. 套用排序规则。
  List<DiaryWithTags> buildVisibleItems(List<DiaryWithTags> items) {
    final visibleItems =
        items.where((DiaryWithTags item) {
          return !_state._optimisticHiddenDiaryIds.contains(item.diary.diaryId);
        }).toList();
    _sortDiaries(visibleItems);
    return visibleItems;
  }

  /// 构建顶部标签筛选可见项。
  ///
  /// 规则：若有关键词，仅展示“在当前搜索结果中出现过”的标签。
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

  /// 统一排序逻辑，避免页面层关心具体排序细节。
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

  /// 释放控制器内部资源，重点是计时器和外部监听。
  void dispose() {
    detachHomeHintVisibilityListener(_state.widget.homeHintVisibleListenable);
  }
}
