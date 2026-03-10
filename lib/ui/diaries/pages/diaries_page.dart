import 'dart:async';
import 'dart:convert';
import 'dart:ui';

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

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/settings_service.dart';
import '../sections/diaries_list_section.dart';
import '../widgets/diary_tag_filter_bar.dart';

/// 日记列表页。
///
/// 提供关键词搜索、标签筛选、列表展示与进入编辑页能力。

class DiariesPage extends ConsumerStatefulWidget {
  const DiariesPage({super.key});

  @override
  ConsumerState<DiariesPage> createState() => _DiariesPage();
}

class _DiariesPage extends ConsumerState<DiariesPage>
    with TickerProviderStateMixin {
  static const Duration _deleteUndoSnackDuration = Duration(seconds: 4);
  static const Duration _restoreHintDuration = Duration(seconds: 2);
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const Duration _searchMorphDuration = Duration(milliseconds: 280);

  final Set<String> _selectedDiaryIds = <String>{};
  final Set<String> _optimisticHiddenDiaryIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _listSearchFieldKey = GlobalKey();
  final GlobalKey _topSearchFieldKey = GlobalKey();
  Timer? _searchDebounceTimer;
  OverlayEntry? _searchMorphOverlay;
  Rect? _cachedListSearchRect;
  late final AnimationController _searchMorphController;
  late final AnimationController _listFadeController;
  late final Animation<double> _listFadeAnimation;
  List<DiaryWithTags> _cachedVisibleItems = const <DiaryWithTags>[];
  String _cachedVisibleItemsSignature = '';
  String _searchInput = '';
  String _effectiveSearchKeyword = '';
  bool _isSearchMode = false;
  bool _isSearchAnimating = false;
  bool _isSearchMorphEntering = false;
  DiarySortMode _sortMode = DiarySortMode.updatedDesc;
  DiaryLayoutMode _layoutMode = DiaryLayoutMode.list;
  bool _viewPreferencesLoaded = false;

  bool get _isSelectionMode => _selectedDiaryIds.isNotEmpty;
  bool get _showTopSearchField => _isSearchMode && !_isSearchAnimating;
  bool get _showHeaderSection => !_isSearchMode && !_isSearchAnimating;

  @override
  void initState() {
    super.initState();
    _searchMorphController = AnimationController(
      vsync: this,
      duration: _searchMorphDuration,
    );
    _listFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    _listFadeAnimation = CurvedAnimation(
      parent: _listFadeController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchMorphController.dispose();
    _listFadeController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    if (_selectedDiaryIds.isEmpty) {
      return;
    }
    setState(_selectedDiaryIds.clear);
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
      _optimisticHiddenDiaryIds.addAll(targetIds);
    });

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
      setState(() {
        _optimisticHiddenDiaryIds.removeAll(targetIds);
        _selectedDiaryIds.addAll(targetIds);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    var undoRequested = false;
    final closedReason =
        await messenger
            .showSnackBar(
              SnackBar(
                content: Text('已删除 ${targetIds.length} 条日记'),
                duration: _deleteUndoSnackDuration,
                action: SnackBarAction(
                  label: '撤销',
                  onPressed: () {
                    undoRequested = true;
                  },
                ),
              ),
            )
            .closed;

    if (!mounted) {
      return;
    }

    if (undoRequested || closedReason == SnackBarClosedReason.action) {
      for (final diaryId in targetIds) {
        await db.restoreDiary(diaryId, touchUpdatedAt: false);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _optimisticHiddenDiaryIds.removeAll(targetIds);
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('已恢复删除的日记'),
          duration: _restoreHintDuration,
        ),
      );
      return;
    }

    // 数据流刷新后会自然移除已删除项，这里清理临时隐藏集合避免长期残留。
    setState(() {
      _optimisticHiddenDiaryIds.removeAll(targetIds);
    });
  }

  void _toggleSelection(String noteId, {bool forceSelect = false}) {
    setState(() {
      if (forceSelect && _isSearchMode) {
        _isSearchMode = false;
        _isSearchAnimating = false;
        _searchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
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

  String _visibleItemsSignature(List<DiaryWithTags> items) {
    return items
        .map(
          (DiaryWithTags item) =>
              '${item.diary.diaryId}:${item.diary.updatedAt.microsecondsSinceEpoch}',
        )
        .join('|');
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

    final fabBottomOffset = 80 + MediaQuery.paddingOf(context).bottom;
    final listBottomOffset = 112 + MediaQuery.paddingOf(context).bottom;

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
          final signature = _visibleItemsSignature(latestVisibleItems);
          if (signature != _cachedVisibleItemsSignature) {
            _cachedVisibleItems = latestVisibleItems;
            _cachedVisibleItemsSignature = signature;
            unawaited(_listFadeController.forward(from: 0));
          }
        }

        final displayedItems =
            latestVisibleItems ?? _cachedVisibleItems;

        return Scaffold(
          backgroundColor: pageBackgroundColor,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              PopScope(
                canPop: !_isSelectionMode,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) {
                    return;
                  }
                  if (_isSelectionMode) {
                    _clearSelection();
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
                                  return SliverToBoxAdapter(
                                    child: DiaryTagFilterBar(
                                      tags: tags,
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
                                SliverFadeTransition(
                                  opacity: _listFadeAnimation,
                                  sliver: DiariesListSection(
                                    key: ValueKey<String>(
                                      'diaries_list_${brightness.name}_${_layoutMode.name}_$_cachedVisibleItemsSignature',
                                    ),
                                    themeBrightness: brightness,
                                    diaries: displayedItems,
                                    layoutMode: _layoutMode,
                                    isSelectionMode: _isSelectionMode,
                                    selectedDiaryIds: _selectedDiaryIds,
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
                                  ),
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
                                          selectedCount: _selectedDiaryIds.length,
                                          onCancelSelection: _clearSelection,
                                          onArchiveSelected: () {},
                                          onDeleteSelected:
                                              () => unawaited(_deleteSelectedDiaries()),
                                          onOpenArchived: _openArchivedPage,
                                          sortMode: _sortMode,
                                          layoutMode: _layoutMode,
                                          onMenuSelected: _onMenuSelected,
                                          searchFieldKey: _topSearchFieldKey,
                                          searchPreviewText: _searchInput,
                                          searchEnabled: true,
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
                Positioned(
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

