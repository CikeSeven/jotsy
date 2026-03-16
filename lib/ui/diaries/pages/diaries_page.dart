import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/archived_diaries_page.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/pages/diary_search_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/settings_service.dart';
import '../viewmodels/diary_view_preferences.dart';
import '../sections/diaries_list_section.dart';
import '../widgets/diary_tag_filter_bar.dart';

part '../controllers/diaries_page_feedback.dart';
part '../controllers/diary_list_transition_coordinator.dart';
part '../controllers/diaries_page_controller.dart';

/// 日记列表页。
///
/// 提供关键词搜索、标签筛选、列表展示与进入预览页能力。

class DiariesPage extends ConsumerStatefulWidget {
  const DiariesPage({
    super.key,
    required this.pageBackgroundColor,
    this.homeHintVisibleListenable,
    this.onCreateActionChanged,
    this.onFabVisibilityChanged,
  });

  final Color pageBackgroundColor;
  final ValueListenable<bool>? homeHintVisibleListenable;
  final ValueChanged<Future<void> Function()?>? onCreateActionChanged;
  final ValueChanged<bool>? onFabVisibilityChanged;

  @override
  ConsumerState<DiariesPage> createState() => _DiariesPage();
}

class _DiariesPage extends ConsumerState<DiariesPage>
    with TickerProviderStateMixin {
  // ==================== 动画与交互节奏常量 ====================
  static const Duration _deleteUndoSnackDuration = Duration(seconds: 4);
  static const Duration _archiveUndoSnackDuration = Duration(seconds: 4);
  static const Duration _restoreHintDuration = Duration(seconds: 2);
  static const Duration _listItemTransitionDuration = Duration(
    milliseconds: 220,
  );
  static const Duration _listRefreshFadeOutDuration = Duration(
    milliseconds: 160,
  );
  static const Duration _listRefreshFadeInDuration = Duration(
    milliseconds: 260,
  );
  static const double _fabToggleScrollThreshold = 26;
  static const int _diaryPageSize = 20;
  static const double _loadMoreTriggerExtent = 420;
  static const double _listBottomExtraSpace = 12;
  static const double _tagSectionTopGap = 2;
  static const double _tagSectionBottomGap = 4;

  // ==================== 列表选择与过渡状态 ====================
  final Set<String> _selectedDiaryIds = <String>{};
  final Set<String> _optimisticHiddenDiaryIds = <String>{};
  final Set<String> _pendingHideDiaryIds = <String>{};
  final Set<String> _appearingDiaryIds = <String>{};
  final Set<String> _archivingDiaryIds = <String>{};
  final Map<String, Timer> _pendingHideTimers = <String, Timer>{};
  final Map<String, Timer> _appearingTimers = <String, Timer>{};

  // ==================== 列表整体过渡动画 ====================
  late final AnimationController _listRefreshPulseController;
  late final Animation<double> _listRefreshOpacity;
  VoidCallback? _pendingFilterMutation;
  Future<void>? _queuedFilterTransition;
  List<DiaryWithTags> _cachedVisibleItems = const <DiaryWithTags>[];
  int _localHintVisibleCount = 0;
  bool _homeHintVisible = false;
  bool _fabVisibleByScroll = true;
  double _fabScrollDeltaAccumulator = 0;
  int _listLayoutEpoch = 0;
  int _visibleDiaryLimit = _diaryPageSize;
  int _lastPageableCount = 0;
  String _pagingSignature = '';
  bool _isPagingCooldown = false;
  Timer? _pagingCooldownTimer;
  DiarySortMode _sortMode = DiarySortMode.updatedDesc;
  DiaryLayoutMode _layoutMode = DiaryLayoutMode.list;
  bool _viewPreferencesLoaded = false;

  // ==================== 页面职责拆分协作对象 ====================
  late final DiariesPageFeedback _feedback;
  late final DiaryListTransitionCoordinator _transitionCoordinator;
  late final DiariesPageController _controller;

  bool get _isSelectionMode => _selectedDiaryIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _feedback = DiariesPageFeedback(this);
    _transitionCoordinator = DiaryListTransitionCoordinator(this);
    _controller = DiariesPageController(
      this,
      feedback: _feedback,
      transitionCoordinator: _transitionCoordinator,
    );
    widget.onCreateActionChanged?.call(_openCreateFromHomeFab);
    widget.onFabVisibilityChanged?.call(_fabVisibleByScroll);
    _controller.attachHomeHintVisibilityListener();
    // 筛选切换时做整列表淡入淡出，降低“突兀跳变”的观感。
    _listRefreshPulseController = AnimationController(
      vsync: this,
      duration: _listRefreshFadeInDuration,
      value: 1,
    );
    _listRefreshOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _listRefreshPulseController,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant DiariesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onCreateActionChanged != widget.onCreateActionChanged) {
      oldWidget.onCreateActionChanged?.call(null);
      widget.onCreateActionChanged?.call(_openCreateFromHomeFab);
    }
    if (oldWidget.onFabVisibilityChanged != widget.onFabVisibilityChanged) {
      widget.onFabVisibilityChanged?.call(_fabVisibleByScroll);
    }
    _controller.handleHomeHintListenableUpdate(
      previous: oldWidget.homeHintVisibleListenable,
      next: widget.homeHintVisibleListenable,
    );
  }

  @override
  void dispose() {
    widget.onCreateActionChanged?.call(null);
    _controller.dispose();
    _transitionCoordinator.dispose();
    _pagingCooldownTimer?.cancel();
    _listRefreshPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // 标签与日记列表分别独立监听，避免相互阻塞。
    final settingsAsync = ref.watch(settingsServiceProvider);
    final filterState = ref.watch(diaryFilterProvider);
    final tagsAsync = ref.watch(tagListProvider);
    final diariesAsync = ref.watch(filteredDiariesProvider);
    final listBottomOffset = _listBottomExtraSpace;

    return settingsAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (Object error, StackTrace stackTrace) => Scaffold(
            body: Center(child: Text(context.l10n.autoT0045(error.toString()))),
          ),
      data: (settingsService) {
        _controller.loadViewPreferencesIfNeeded(settingsService);
        final topSafeInset = MediaQuery.paddingOf(context).top;
        final headerOverlayHeight = topSafeInset + 68;
        final latestVisibleItems =
            diariesAsync.asData != null
                ? _controller.buildVisibleItems(diariesAsync.asData!.value)
                : null;

        if (latestVisibleItems != null) {
          _cachedVisibleItems = latestVisibleItems;
          _transitionCoordinator.syncAppearingTimers(latestVisibleItems);
        }

        final displayedItems = latestVisibleItems ?? _cachedVisibleItems;
        final shouldUnpinSelected = _controller.areAllSelectedPinned(
          displayedItems,
        );
        final currentPagingSignature = _buildPagingSignature(filterState);
        _syncPagingStateWithFilterSignature(currentPagingSignature);
        final pagedDisplayedItems =
            displayedItems.take(_visibleDiaryLimit).toList();
        _lastPageableCount = displayedItems.length;
        final hasMoreDiaries =
            pagedDisplayedItems.length < displayedItems.length;

        return Scaffold(
          backgroundColor: widget.pageBackgroundColor,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              // 返回键优先处理页面内部状态，再交给路由栈。
              PopScope(
                canPop: !_isSelectionMode,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) {
                    return;
                  }
                  if (_isSelectionMode) {
                    _controller.clearSelection();
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
                          color: widget.pageBackgroundColor,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: _handlePrimaryScrollNotification,
                            child: CustomScrollView(
                              key: PageStorageKey<String>(
                                'diaries_scroll_${brightness.name}_${_layoutMode.name}',
                              ),
                              slivers: <Widget>[
                                // 预留头部叠层空间，让应用栏可以做玻璃悬浮效果。
                                SliverToBoxAdapter(
                                  child: SizedBox(height: headerOverlayHeight),
                                ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: _tagSectionTopGap),
                                ),
                                tagsAsync.when(
                                  data: (tags) {
                                    return SliverToBoxAdapter(
                                      // 顶部标签筛选条（支持清空和多选筛选）。
                                      child: DiaryTagFilterBar(
                                        tags: _controller
                                            .buildTagFiltersForDisplay(
                                              allTags: tags,
                                              visibleItems: displayedItems,
                                              keyword: filterState.keyword,
                                            ),
                                        selectedTagFilterIds:
                                            filterState.selectedTagIds,
                                        onToggleTagFilter:
                                            _controller.toggleTagFilter,
                                        onClearTagFilters:
                                            _controller.clearTagFilters,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.m,
                                                    vertical: AppSpacing.s,
                                                  ),
                                              child: Text(
                                                context.l10n.autoT0042(
                                                  error.toString(),
                                                ),
                                              ),
                                            ),
                                          ),
                                ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: _tagSectionBottomGap),
                                ),
                                SliverFadeTransition(
                                  opacity: _listRefreshOpacity,
                                  sliver:
                                      // 数据状态优先级：
                                      // 1) 首屏加载且无缓存；
                                      // 2) 首屏错误且无缓存；
                                      // 3) 渲染列表/空态内容。
                                      diariesAsync.isLoading &&
                                              displayedItems.isEmpty
                                          ? const SliverFillRemaining(
                                            hasScrollBody: false,
                                            child: Center(
                                              child: SizedBox(
                                                height: 22,
                                                width: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            ),
                                          )
                                          : diariesAsync.hasError &&
                                              displayedItems.isEmpty
                                          ? SliverFillRemaining(
                                            hasScrollBody: false,
                                            child: Center(
                                              child: Text(
                                                context.l10n.autoT0127(
                                                  diariesAsync.asError?.error
                                                          .toString() ??
                                                      '',
                                                ),
                                              ),
                                            ),
                                          )
                                          : DiariesListSection(
                                            key: ValueKey<String>(
                                              'diaries_list_${_layoutMode.name}_$_listLayoutEpoch',
                                            ),
                                            themeBrightness: brightness,
                                            diaries: pagedDisplayedItems,
                                            layoutMode: _layoutMode,
                                            isSelectionMode: _isSelectionMode,
                                            selectedDiaryIds: _selectedDiaryIds,
                                            pendingHideDiaryIds:
                                                _pendingHideDiaryIds,
                                            appearingDiaryIds:
                                                _appearingDiaryIds,
                                            onCreate:
                                                () => unawaited(
                                                  _controller
                                                      .openCreateEditorWithDraftPrompt(),
                                                ),
                                            onOpenEditor: (diaryId) {
                                              _controller.openPreview(diaryId);
                                            },
                                            onToggleSelection:
                                                (noteId, forceSelect) =>
                                                    _controller.toggleSelection(
                                                      noteId,
                                                      forceSelect: forceSelect,
                                                    ),
                                            onArchiveDiary:
                                                (diaryId) => unawaited(
                                                  _controller
                                                      .archiveDiaryBySwipe(
                                                        diaryId,
                                                      ),
                                                ),
                                            isSearchResultEmpty: false,
                                          ),
                                ),
                                if (hasMoreDiaries || _isPagingCooldown)
                                  const SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Center(
                                        child: SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                SliverToBoxAdapter(
                                  // 底部留白用于避让 Home 底部导航和 FAB。
                                  child: SizedBox(height: listBottomOffset),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
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
                                    // 头部组件负责：多选态、搜索入口、归档入口、排序布局菜单。
                                    DiaryHeadSection(
                                      isSelectionMode: _isSelectionMode,
                                      selectedCount: _selectedDiaryIds.length,
                                      onCancelSelection:
                                          _controller.clearSelection,
                                      isPinActionUnpin: shouldUnpinSelected,
                                      onPinSelected:
                                          () => unawaited(
                                            _controller.pinSelectedDiaries(
                                              unpin: shouldUnpinSelected,
                                            ),
                                          ),
                                      onArchiveSelected:
                                          () => unawaited(
                                            _controller
                                                .archiveSelectedDiaries(),
                                          ),
                                      onDeleteSelected:
                                          () => unawaited(
                                            _controller.deleteSelectedDiaries(),
                                          ),
                                      onOpenArchived:
                                          _controller.openArchivedPage,
                                      sortMode: _sortMode,
                                      layoutMode: _layoutMode,
                                      onMenuSelected:
                                          _controller.onMenuSelected,
                                      onOpenSearchPage:
                                          _controller.openSearchPage,
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreateFromHomeFab() async {
    await _controller.openCreateEditorWithDraftPrompt();
  }

  bool _handlePrimaryScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification.metrics.extentAfter < _loadMoreTriggerExtent) {
      _requestLoadMoreDiaries();
    }

    if (notification is ScrollEndNotification) {
      _fabScrollDeltaAccumulator = 0;
      return false;
    }

    if (notification is! ScrollUpdateNotification) {
      return false;
    }
    final delta = notification.scrollDelta;
    if (delta == null || delta.abs() < 0.5) {
      return false;
    }

    if (notification.metrics.pixels <= 0) {
      _fabScrollDeltaAccumulator = 0;
      _updateFabVisibilityByScroll(true);
      return false;
    }

    _fabScrollDeltaAccumulator += delta;
    if (_fabScrollDeltaAccumulator >= _fabToggleScrollThreshold) {
      _fabScrollDeltaAccumulator = 0;
      _updateFabVisibilityByScroll(false);
      return false;
    }
    if (_fabScrollDeltaAccumulator <= -_fabToggleScrollThreshold) {
      _fabScrollDeltaAccumulator = 0;
      _updateFabVisibilityByScroll(true);
      return false;
    }
    return false;
  }

  /// 构建当前分页上下文签名。
  ///
  /// 当关键词或标签筛选发生变化时，签名会变化，分页会自动回到首屏 20 条。
  String _buildPagingSignature(DiaryFilterState filterState) {
    final normalizedKeyword = filterState.keyword.trim();
    final sortedTagIds = filterState.selectedTagIds.toList()..sort();
    return '$normalizedKeyword|${sortedTagIds.join(",")}';
  }

  /// 同步分页状态与筛选条件。
  ///
  /// 只要筛选条件变化，就重置分页窗口，避免旧分页状态污染新结果集。
  void _syncPagingStateWithFilterSignature(String signature) {
    if (_pagingSignature == signature) {
      return;
    }
    _pagingSignature = signature;
    _visibleDiaryLimit = _diaryPageSize;
    _isPagingCooldown = false;
    _pagingCooldownTimer?.cancel();
    _pagingCooldownTimer = null;
  }

  /// 请求加载下一批日记（每次 +20）。
  ///
  /// 这里使用一个短冷却窗口，避免滚动通知高频触发导致瞬间连续追加多页。
  void _requestLoadMoreDiaries() {
    if (_isPagingCooldown || _visibleDiaryLimit >= _lastPageableCount) {
      return;
    }
    setState(() {
      _visibleDiaryLimit = math.min(
        _visibleDiaryLimit + _diaryPageSize,
        _lastPageableCount,
      );
      _isPagingCooldown = true;
    });
    _pagingCooldownTimer?.cancel();
    _pagingCooldownTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPagingCooldown = false;
      });
    });
  }

  void _updateFabVisibilityByScroll(bool visible) {
    if (_fabVisibleByScroll == visible) {
      return;
    }
    _fabVisibleByScroll = visible;
    widget.onFabVisibilityChanged?.call(visible);
  }
}

enum _CreateDraftDecision { newEmpty, continueEditing }
