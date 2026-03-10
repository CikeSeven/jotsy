import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/archived_diaries_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/settings_service.dart';
import '../../widgets/glass_bottom_nav.dart';
import '../sections/diaries_list_section.dart';
import '../widgets/diary_tag_filter_bar.dart';

/// 日记列表页。
///
/// 提供关键词搜索、标签筛选、列表展示与进入编辑页能力。

class DiariesPage extends ConsumerStatefulWidget {
  const DiariesPage({
    super.key,
    this.homeHintVisibleListenable,
  });

  final ValueListenable<bool>? homeHintVisibleListenable;

  @override
  ConsumerState<DiariesPage> createState() => _DiariesPage();
}

class _DiariesPage extends ConsumerState<DiariesPage>
    with TickerProviderStateMixin {
  static const Duration _deleteUndoSnackDuration = Duration(seconds: 4);
  static const Duration _archiveUndoSnackDuration = Duration(seconds: 4);
  static const Duration _restoreHintDuration = Duration(seconds: 2);
  static const Duration _fabShiftDuration = Duration(milliseconds: 260);
  static const Duration _listItemTransitionDuration = Duration(milliseconds: 220);
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const Duration _searchMorphDuration = Duration(milliseconds: 280);
  static const double _fabLiftOffsetWhenHintVisible = 60;
  static const double _fabExtraGapAboveNav = 2;
  static const double _listBottomExtraSpace = 34;

  final Set<String> _selectedDiaryIds = <String>{};
  final Set<String> _optimisticHiddenDiaryIds = <String>{};
  final Set<String> _pendingHideDiaryIds = <String>{};
  final Set<String> _appearingDiaryIds = <String>{};
  final Set<String> _archivingDiaryIds = <String>{};
  final Map<String, Timer> _pendingHideTimers = <String, Timer>{};
  final Map<String, Timer> _appearingTimers = <String, Timer>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;
  List<DiaryWithTags> _cachedVisibleItems = const <DiaryWithTags>[];
  int _localHintVisibleCount = 0;
  String _searchInput = '';
  String _effectiveSearchKeyword = '';
  bool _isSearchMode = false;
  bool _isSearchAnimating = false;
  bool _homeHintVisible = false;
  DiarySortMode _sortMode = DiarySortMode.updatedDesc;
  DiaryLayoutMode _layoutMode = DiaryLayoutMode.list;
  bool _viewPreferencesLoaded = false;

  bool get _isSelectionMode => _selectedDiaryIds.isNotEmpty;
  bool get _showHeaderSection => !_isSearchAnimating;
  bool get _isAnyHintVisible =>
      _homeHintVisible || _localHintVisibleCount > 0;

  @override
  void initState() {
    super.initState();
    _attachHomeHintVisibilityListener();
  }

  @override
  void didUpdateWidget(covariant DiariesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeHintVisibleListenable != widget.homeHintVisibleListenable) {
      _detachHomeHintVisibilityListener(oldWidget.homeHintVisibleListenable);
      _attachHomeHintVisibilityListener();
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    for (final timer in _pendingHideTimers.values) {
      timer.cancel();
    }
    _pendingHideTimers.clear();
    for (final timer in _appearingTimers.values) {
      timer.cancel();
    }
    _appearingTimers.clear();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _detachHomeHintVisibilityListener(widget.homeHintVisibleListenable);
    super.dispose();
  }

  void _attachHomeHintVisibilityListener() {
    final listenable = widget.homeHintVisibleListenable;
    if (listenable == null) {
      return;
    }
    _homeHintVisible = listenable.value;
    listenable.addListener(_onHomeHintVisibilityChanged);
  }

  void _detachHomeHintVisibilityListener(ValueListenable<bool>? listenable) {
    listenable?.removeListener(_onHomeHintVisibilityChanged);
  }

  void _onHomeHintVisibilityChanged() {
    final visible = widget.homeHintVisibleListenable?.value ?? false;
    if (visible == _homeHintVisible || !mounted) {
      return;
    }
    setState(() {
      _homeHintVisible = visible;
    });
  }

  void _clearSelection() {
    if (_selectedDiaryIds.isEmpty) {
      return;
    }
    setState(_selectedDiaryIds.clear);
  }

  /// 进入搜索态：显示输入框并聚焦。
  void _enterSearchMode() {
    if (_isSelectionMode || _isSearchMode) {
      return;
    }
    setState(() {
      _isSearchMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _searchFocusNode.requestFocus();
    });
  }

  /// 退出搜索态并清空搜索条件。
  void _exitSearchModeAndClear() {
    _clearSearch(exitSearchMode: true);
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// 清空输入但保持搜索态，便于继续输入。
  void _clearSearchInPlace() {
    _clearSearch(exitSearchMode: false);
    _searchFocusNode.requestFocus();
  }

  void _onSearchChanged(String value) {
    if (_searchInput != value) {
      setState(() {
        _searchInput = value;
      });
    }
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      _applySearchKeyword(value);
    });
  }

  void _applySearchKeyword(String rawValue) {
    final normalized = rawValue.trim();
    if (normalized == _effectiveSearchKeyword) {
      return;
    }
    _effectiveSearchKeyword = normalized;
    ref.read(diaryFilterProvider.notifier).setKeyword(normalized);
  }

  void _clearSearch({required bool exitSearchMode}) {
    _searchDebounceTimer?.cancel();
    final shouldResetKeyword =
        _effectiveSearchKeyword.isNotEmpty ||
        _searchInput.trim().isNotEmpty ||
        _searchController.text.trim().isNotEmpty;
    _searchController.clear();

    if (mounted) {
      setState(() {
        _searchInput = '';
        _effectiveSearchKeyword = '';
        if (exitSearchMode) {
          _isSearchMode = false;
          _isSearchAnimating = false;
        }
      });
    } else {
      _searchInput = '';
      _effectiveSearchKeyword = '';
      if (exitSearchMode) {
        _isSearchMode = false;
        _isSearchAnimating = false;
      }
    }

    if (shouldResetKeyword) {
      ref.read(diaryFilterProvider.notifier).setKeyword('');
    }
  }

  // 打开编辑页，使用系统默认页面转场。
  void _openEditor({
    String? diaryId,
    bool restoreCreateDraft = true,
  }) {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    unawaited(
      Navigator.of(context)
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
            if (!mounted) {
              return;
            }
            _searchFocusNode.unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          }),
    );
  }

  Future<void> _openCreateEditorWithDraftPrompt() async {
    final settingsService = await ref.read(settingsServiceProvider.future);
    final existingDraft = _tryDecodeCreateDraft(
      settingsService.createDiaryDraftRaw,
    );
    if (!mounted) {
      return;
    }

    var restoreCreateDraft = true;
    if (existingDraft?.hasContent == true) {
      final decision = await _showCreateDraftDecisionDialog();
      if (!mounted || decision == null) {
        return;
      }
      if (decision == _CreateDraftDecision.newEmpty) {
        await settingsService.clearCreateDiaryDraft();
        restoreCreateDraft = false;
      }
    }

    _openEditor(
      restoreCreateDraft: restoreCreateDraft,
    );
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

  Future<_CreateDraftDecision?> _showCreateDraftDecisionDialog() {
    return showDialog<_CreateDraftDecision>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('发现未完成日记'),
          content: const Text('检测到你上次有未保存的日记，是否继续编辑？'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(_CreateDraftDecision.newEmpty),
              child: const Text('新建空笔记'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.primary,
              ),
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(_CreateDraftDecision.continueEditing),
              child: const Text('继续编辑'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showDeleteSelectedConfirmDialog(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除日记'),
          content: Text('确认删除已选择的 $count 条日记吗？'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _showInfoSnackBar(
    String message, {
    Duration duration = _restoreHintDuration,
  }) async {
    await _showTrackedSnackBar(
      snackBar: SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }

  Future<SnackBarClosedReason> _showTrackedSnackBar({
    required SnackBar snackBar,
    Duration? forceCloseAfter,
  }) async {
    if (mounted) {
      setState(() {
        _localHintVisibleCount += 1;
      });
    }

    final closedReason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: snackBar,
      forceCloseAfter: forceCloseAfter,
    );

    if (mounted) {
      setState(() {
        if (_localHintVisibleCount > 0) {
          _localHintVisibleCount -= 1;
        }
      });
    }
    return closedReason;
  }

  /// 统一显示“可撤销”提示，并强制按设定时长自动关闭。
  ///
  /// 某些系统无障碍模式下，带 action 的 SnackBar 可能不会自动消失。
  /// 这里通过 controller.close() 兜底，保证交互时长一致。
  Future<bool> _showUndoSnackBar({
    required String message,
    required Duration duration,
  }) async {
    var undoRequested = false;
    final closedReason = await _showTrackedSnackBar(
      snackBar: SnackBar(
        content: Text(message),
        duration: duration,
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            undoRequested = true;
          },
        ),
      ),
      forceCloseAfter: duration,
    );

    return undoRequested || closedReason == SnackBarClosedReason.action;
  }

  Future<void> _deleteSelectedDiaries() async {
    if (_selectedDiaryIds.isEmpty) {
      return;
    }

    final targetIds = _selectedDiaryIds.toList(growable: false);
    final confirmed = await _showDeleteSelectedConfirmDialog(targetIds.length);
    if (!mounted || !confirmed) {
      return;
    }

    setState(() {
      _selectedDiaryIds.clear();
    });
    _startHideAnimations(targetIds);

    final db = ref.read(appDatabaseProvider);
    final failedIds = <String>[];
    for (final diaryId in targetIds) {
      try {
        await db.softDeleteDiary(diaryId, touchUpdatedAt: false);
      } catch (_) {
        failedIds.add(diaryId);
      }
    }

    if (!mounted) {
      return;
    }

    // 批量失败时回滚成功删除，避免出现部分成功导致状态不一致。
    if (failedIds.isNotEmpty) {
      final succeededIds =
          targetIds.where((id) => !failedIds.contains(id)).toList(growable: false);
      for (final diaryId in succeededIds) {
        await db.restoreDiary(diaryId, touchUpdatedAt: false);
      }
      if (!mounted) {
        return;
      }
      _revealDiaries(targetIds, animate: true);
      setState(() {
        _selectedDiaryIds.addAll(targetIds);
      });
      await _showInfoSnackBar('删除失败，请重试');
      return;
    }

    final undoRequested = await _showUndoSnackBar(
      message: '已删除 ${targetIds.length} 条日记',
      duration: _deleteUndoSnackDuration,
    );

    if (!mounted) {
      return;
    }

    if (undoRequested) {
      for (final diaryId in targetIds) {
        await db.restoreDiary(diaryId, touchUpdatedAt: false);
      }
      if (!mounted) {
        return;
      }
      _revealDiaries(targetIds, animate: true);
      await _showInfoSnackBar('已恢复删除的日记');
      return;
    }

    // 数据流刷新后会自然移除已删除项，这里清理临时隐藏集合避免长期残留。
    setState(() {
      _optimisticHiddenDiaryIds.removeAll(targetIds);
      _pendingHideDiaryIds.removeAll(targetIds);
      _appearingDiaryIds.removeAll(targetIds);
    });
    _clearTransitionTimers(targetIds);
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
    if (targetIds.any(_archivingDiaryIds.contains)) {
      return;
    }

    setState(() {
      if (clearSelection) {
        _selectedDiaryIds.removeAll(targetIds);
      }
      _archivingDiaryIds.addAll(targetIds);
    });
    if (animateHide) {
      _startHideAnimations(targetIds);
    } else {
      _hideDiariesImmediately(targetIds);
    }

    final db = ref.read(appDatabaseProvider);
    final failedIds = <String>[];
    for (final diaryId in targetIds) {
      try {
        await db.archiveDiary(diaryId, touchUpdatedAt: false);
      } catch (_) {
        failedIds.add(diaryId);
      }
    }

    if (!mounted) {
      return;
    }

    if (failedIds.isNotEmpty) {
      final succeededIds =
          targetIds.where((id) => !failedIds.contains(id)).toList(growable: false);
      for (final diaryId in succeededIds) {
        await db.unarchiveDiary(diaryId, touchUpdatedAt: false);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _archivingDiaryIds.removeAll(targetIds);
        if (clearSelection) {
          _selectedDiaryIds.addAll(targetIds);
        }
      });
      _revealDiaries(targetIds, animate: true);
      await _showInfoSnackBar('归档失败，请重试');
      return;
    }

    if (showUndoSnack) {
      final undoRequested = await _showUndoSnackBar(
        message: '已归档 ${targetIds.length} 条日记',
        duration: _archiveUndoSnackDuration,
      );

      if (!mounted) {
        return;
      }

      if (undoRequested) {
        for (final diaryId in targetIds) {
          await db.unarchiveDiary(diaryId, touchUpdatedAt: false);
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _archivingDiaryIds.removeAll(targetIds);
        });
        _revealDiaries(targetIds, animate: true);
        await _showInfoSnackBar('已恢复归档的日记');
        return;
      }
    }

    setState(() {
      _optimisticHiddenDiaryIds.removeAll(targetIds);
      _pendingHideDiaryIds.removeAll(targetIds);
      _appearingDiaryIds.removeAll(targetIds);
      _archivingDiaryIds.removeAll(targetIds);
    });
    _clearTransitionTimers(targetIds);
  }

  Future<void> _archiveSelectedDiaries() async {
    if (_selectedDiaryIds.isEmpty) {
      return;
    }
    await _archiveDiaries(
      _selectedDiaryIds.toList(growable: false),
      clearSelection: true,
      showUndoSnack: true,
    );
  }

  Future<void> _archiveDiaryBySwipe(String diaryId) async {
    await _archiveDiaries(
      <String>[diaryId],
      clearSelection: false,
      showUndoSnack: true,
      animateHide: false,
    );
  }

  void _startHideAnimations(Iterable<String> diaryIds) {
    final targetIds = diaryIds.toSet();
    if (targetIds.isEmpty) {
      return;
    }

    for (final diaryId in targetIds) {
      _appearingTimers.remove(diaryId)?.cancel();
      _pendingHideTimers[diaryId]?.cancel();
      _pendingHideTimers[diaryId] = Timer(_listItemTransitionDuration, () {
        _pendingHideTimers.remove(diaryId);
        if (!mounted) {
          return;
        }
        setState(() {
          _pendingHideDiaryIds.remove(diaryId);
          _optimisticHiddenDiaryIds.add(diaryId);
        });
      });
    }

    setState(() {
      _appearingDiaryIds.removeAll(targetIds);
      _pendingHideDiaryIds.addAll(targetIds);
    });
  }

  void _hideDiariesImmediately(Iterable<String> diaryIds) {
    final targetIds = diaryIds.toSet();
    if (targetIds.isEmpty) {
      return;
    }
    _clearTransitionTimers(targetIds);
    setState(() {
      _pendingHideDiaryIds.removeAll(targetIds);
      _appearingDiaryIds.removeAll(targetIds);
      _optimisticHiddenDiaryIds.addAll(targetIds);
    });
  }

  void _revealDiaries(Iterable<String> diaryIds, {required bool animate}) {
    final targetIds = diaryIds.toSet();
    if (targetIds.isEmpty) {
      return;
    }

    for (final diaryId in targetIds) {
      _pendingHideTimers.remove(diaryId)?.cancel();
      _appearingTimers.remove(diaryId)?.cancel();
    }

    setState(() {
      _pendingHideDiaryIds.removeAll(targetIds);
      _optimisticHiddenDiaryIds.removeAll(targetIds);
      if (animate) {
        _appearingDiaryIds.addAll(targetIds);
      } else {
        _appearingDiaryIds.removeAll(targetIds);
      }
    });
  }

  void _clearTransitionTimers(Iterable<String> diaryIds) {
    for (final diaryId in diaryIds) {
      _pendingHideTimers.remove(diaryId)?.cancel();
      _appearingTimers.remove(diaryId)?.cancel();
    }
  }

  void _syncAppearingTimers(List<DiaryWithTags> visibleItems) {
    if (_appearingDiaryIds.isEmpty) {
      return;
    }
    final visibleIds =
        visibleItems.map((DiaryWithTags item) => item.diary.diaryId).toSet();
    final targetIds = _appearingDiaryIds.intersection(visibleIds);
    if (targetIds.isEmpty) {
      return;
    }

    for (final diaryId in targetIds) {
      if (_appearingTimers.containsKey(diaryId)) {
        continue;
      }
      _appearingTimers[diaryId] = Timer(_listItemTransitionDuration, () {
        _appearingTimers.remove(diaryId);
        if (!mounted) {
          return;
        }
        setState(() {
          _appearingDiaryIds.remove(diaryId);
        });
      });
    }
  }

  void _toggleSelection(String noteId, {bool forceSelect = false}) {
    var shouldClearSearchKeyword = false;
    var shouldUnfocusSearch = false;
    setState(() {
      if (forceSelect && _isSearchMode) {
        _searchDebounceTimer?.cancel();
        shouldClearSearchKeyword =
            _effectiveSearchKeyword.isNotEmpty || _searchInput.trim().isNotEmpty;
        shouldUnfocusSearch = true;
        _searchController.clear();
        _searchInput = '';
        _effectiveSearchKeyword = '';
        _isSearchMode = false;
        _isSearchAnimating = false;
      }
      if (forceSelect) {
        _selectedDiaryIds.add(noteId);
        return;
      }
      if (_selectedDiaryIds.contains(noteId)) {
        _selectedDiaryIds.remove(noteId);
      } else {
        _selectedDiaryIds.add(noteId);
      }
    });
    if (shouldClearSearchKeyword) {
      ref.read(diaryFilterProvider.notifier).setKeyword('');
    }
    if (shouldUnfocusSearch) {
      _searchFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _openArchivedPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const ArchivedDiariesPage(),
      ),
    );
  }

  void _onMenuSelected(DiaryMenuAction action) {
    setState(() {
      switch (action) {
        case DiaryMenuAction.sortUpdatedDesc:
          _sortMode = DiarySortMode.updatedDesc;
          break;
        case DiaryMenuAction.sortUpdatedAsc:
          _sortMode = DiarySortMode.updatedAsc;
          break;
        case DiaryMenuAction.sortTitleAsc:
          _sortMode = DiarySortMode.titleAsc;
          break;
        case DiaryMenuAction.layoutList:
          _layoutMode = DiaryLayoutMode.list;
          break;
        case DiaryMenuAction.layoutWaterfall:
          _layoutMode = DiaryLayoutMode.waterfall;
          break;
      }
    });
    _persistViewPreferences();
  }

  void _persistViewPreferences() {
    final settingsService = ref.read(settingsServiceProvider).asData?.value;
    if (settingsService == null) {
      return;
    }
    unawaited(settingsService.setDiarySortModeRaw(_sortMode.name));
    unawaited(settingsService.setDiaryLayoutModeRaw(_layoutMode.name));
  }

  void _loadViewPreferencesIfNeeded(SettingsService settingsService) {
    if (_viewPreferencesLoaded) {
      return;
    }
    _sortMode = _sortModeFromRaw(settingsService.diarySortModeRaw);
    _layoutMode = _layoutModeFromRaw(settingsService.diaryLayoutModeRaw);
    _viewPreferencesLoaded = true;
  }

  DiarySortMode _sortModeFromRaw(String raw) {
    switch (raw) {
      case 'updatedAsc':
        return DiarySortMode.updatedAsc;
      case 'titleAsc':
        return DiarySortMode.titleAsc;
      case 'updatedDesc':
      default:
        return DiarySortMode.updatedDesc;
    }
  }

  DiaryLayoutMode _layoutModeFromRaw(String raw) {
    switch (raw) {
      case 'waterfall':
        return DiaryLayoutMode.waterfall;
      case 'list':
      default:
        return DiaryLayoutMode.list;
    }
  }

  void _sortDiaries(List<DiaryWithTags> items) {
    switch (_sortMode) {
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

  List<DiaryWithTags> _buildVisibleItems(List<DiaryWithTags> items) {
    final visibleItems =
        items.where((DiaryWithTags item) {
          return !_optimisticHiddenDiaryIds.contains(item.diary.diaryId);
        }).toList();
    _sortDiaries(visibleItems);
    return visibleItems;
  }

  List<Tag> _buildTagFiltersForDisplay({
    required List<Tag> allTags,
    required List<DiaryWithTags> visibleItems,
    required String keyword,
  }) {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return allTags;
    }

    // 关键词筛选生效时，仅展示“当前结果列表里实际存在”的标签。
    final visibleTagIds = <int>{};
    for (final item in visibleItems) {
      for (final tag in item.tags) {
        visibleTagIds.add(tag.id);
      }
    }

    return allTags.where((tag) => visibleTagIds.contains(tag.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final pageBackgroundColor =
        brightness == Brightness.light ? Colors.white : colorScheme.surface;
    // 标签与日记列表分别独立监听，避免相互阻塞。
    final settingsAsync = ref.watch(settingsServiceProvider);
    final filterState = ref.watch(diaryFilterProvider);
    final tagsAsync = ref.watch(tagListProvider);
    final diariesAsync = ref.watch(filteredDiariesProvider);
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final fabBaseBottomOffset =
        bottomSafeInset +
        GlassBottomNav.navBottomInset +
        GlassBottomNav.navHeight +
        _fabExtraGapAboveNav;
    final fabBottomOffset =
        fabBaseBottomOffset +
        (_isAnyHintVisible ? _fabLiftOffsetWhenHintVisible : 0);

    final listBottomOffset =
        bottomSafeInset +
        GlassBottomNav.navBottomInset +
        GlassBottomNav.navHeight +
        _listBottomExtraSpace;

    return settingsAsync.when(
      loading:
          () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (Object error, StackTrace stackTrace) =>
              Scaffold(body: Center(child: Text('设置加载失败: $error'))),
      data: (settingsService) {
        _loadViewPreferencesIfNeeded(settingsService);
        final topSafeInset = MediaQuery.paddingOf(context).top;
        final headerOverlayHeight = topSafeInset + 68;
        final latestVisibleItems =
            diariesAsync.asData != null
                ? _buildVisibleItems(diariesAsync.asData!.value)
                : null;

        if (latestVisibleItems != null) {
          _cachedVisibleItems = latestVisibleItems;
          _syncAppearingTimers(latestVisibleItems);
        }

        final displayedItems =
            latestVisibleItems ?? _cachedVisibleItems;

        return Scaffold(
          backgroundColor: pageBackgroundColor,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              PopScope(
                canPop: !(_isSelectionMode || _isSearchMode),
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) {
                    return;
                  }
                  if (_isSelectionMode) {
                    _clearSelection();
                    return;
                  }
                  if (_isSearchMode) {
                    _exitSearchModeAndClear();
                  }
                },
                child: Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) {
                      return KeyEventResult.ignored;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Stack(
                    children: [
                      SafeArea(
                        top: false,
                        child: ColoredBox(
                          color: pageBackgroundColor,
                          child: CustomScrollView(
                            key: PageStorageKey<String>(
                              'diaries_scroll_${brightness.name}_${_layoutMode.name}',
                            ),
                            slivers: <Widget>[
                              SliverToBoxAdapter(
                                child: SizedBox(height: headerOverlayHeight),
                              ),
                              tagsAsync.when(
                                data: (tags) {
                                  final tagsForDisplay = _buildTagFiltersForDisplay(
                                    allTags: tags,
                                    visibleItems: displayedItems,
                                    keyword: filterState.keyword,
                                  );
                                  return SliverToBoxAdapter(
                                    child: DiaryTagFilterBar(
                                      tags: tagsForDisplay,
                                      selectedTagFilterIds: filterState.selectedTagIds,
                                      onToggleTagFilter: (tagId, selected) {
                                        ref
                                            .read(diaryFilterProvider.notifier)
                                            .toggleTag(tagId, selected);
                                      },
                                      onClearTagFilters: () {
                                        ref
                                            .read(diaryFilterProvider.notifier)
                                            .clearTags();
                                      },
                                    ),
                                  );
                                },
                                loading:
                                    () => const SliverToBoxAdapter(
                                      child: SizedBox(height: 56),
                                    ),
                                error:
                                    (Object error, StackTrace stackTrace) =>
                                        SliverToBoxAdapter(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.m,
                                              vertical: AppSpacing.s,
                                            ),
                                            child: Text('标签加载失败: $error'),
                                          ),
                                        ),
                              ),
                              if (diariesAsync.isLoading && displayedItems.isEmpty)
                                const SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                )
                              else if (diariesAsync.hasError && displayedItems.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: Text(
                                      '日记加载失败: ${diariesAsync.asError?.error}',
                                    ),
                                  ),
                                )
                              else
                                DiariesListSection(
                                  themeBrightness: brightness,
                                  diaries: displayedItems,
                                  layoutMode: _layoutMode,
                                  isSelectionMode: _isSelectionMode,
                                  selectedDiaryIds: _selectedDiaryIds,
                                  pendingHideDiaryIds: _pendingHideDiaryIds,
                                  appearingDiaryIds: _appearingDiaryIds,
                                  onCreate:
                                      () => unawaited(
                                        _openCreateEditorWithDraftPrompt(),
                                      ),
                                  onOpenEditor: (diaryId) {
                                    _openEditor(
                                      diaryId: diaryId,
                                    );
                                  },
                                  onToggleSelection:
                                      (noteId, forceSelect) => _toggleSelection(
                                        noteId,
                                        forceSelect: forceSelect,
                                      ),
                                  onArchiveDiary:
                                      (diaryId) =>
                                          unawaited(_archiveDiaryBySwipe(diaryId)),
                                ),
                              SliverToBoxAdapter(
                                child: SizedBox(height: listBottomOffset),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: !_showHeaderSection,
                          child: AnimatedOpacity(
                            duration: _searchMorphDuration,
                            curve: Curves.easeOutCubic,
                            opacity: _showHeaderSection ? 1 : 0,
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: AppEffects.softShadow,
                              ),
                              child: ClipRect(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 20,
                                    sigmaY: 20,
                                    tileMode: TileMode.mirror,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface.withAlpha(10),
                                    child: Column(
                                      children: [
                                        SizedBox(height: topSafeInset),
                                        DiaryHeadSection(
                                          isSelectionMode: _isSelectionMode,
                                          isSearchMode: _isSearchMode,
                                          selectedCount: _selectedDiaryIds.length,
                                          onCancelSelection: _clearSelection,
                                          onArchiveSelected:
                                              () => unawaited(_archiveSelectedDiaries()),
                                          onDeleteSelected:
                                              () => unawaited(_deleteSelectedDiaries()),
                                          onOpenArchived: _openArchivedPage,
                                          sortMode: _sortMode,
                                          layoutMode: _layoutMode,
                                          onMenuSelected: _onMenuSelected,
                                          searchPreviewText: _searchInput,
                                          searchController: _searchController,
                                          searchFocusNode: _searchFocusNode,
                                          onEnterSearch: _enterSearchMode,
                                          onExitSearch: _exitSearchModeAndClear,
                                          onClearSearch: _clearSearchInPlace,
                                          onSearchChanged: _onSearchChanged,
                                        ),
                                        Container(
                                          height: 1,
                                          margin: const EdgeInsets.only(
                                            top: AppSpacing.xs,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_isSelectionMode)
                AnimatedPositioned(
                  duration: _fabShiftDuration,
                  curve: Curves.easeOutCubic,
                  right: AppSpacing.xl,
                  bottom: fabBottomOffset,
                  child: FloatingActionButton(
                    onPressed:
                        () => unawaited(_openCreateEditorWithDraftPrompt()),
                    child: FaIcon(FontAwesomeIcons.plus),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _CreateDraftDecision { newEmpty, continueEditing }
