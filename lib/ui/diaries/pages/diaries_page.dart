import 'dart:async';
import 'dart:convert';

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
  static const double _tagPinnedHeaderHeight = 46;
  static const double _headerCollapsibleHeight = 68;

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
  List<DiaryWithTags>? _cachedVisibleSourceItemsRef;
  DiarySortMode? _cachedVisibleSortMode;
  String _cachedHiddenDiaryIdsSignature = '';
  List<DiaryWithTags>? _lastSyncedVisibleItemsRef;
  List<Tag>? _cachedTagFilterSourceTagsRef;
  List<DiaryWithTags>? _cachedTagFilterVisibleItemsRef;
  String _cachedTagFilterKeyword = '';
  List<Tag> _cachedTagFilters = const <Tag>[];
  int _localHintVisibleCount = 0;
  bool _homeHintVisible = false;
  bool _fabVisibleByScroll = true;
  double _fabScrollDeltaAccumulator = 0;
  int _listLayoutEpoch = 0;
  int _visibleDiaryLimit = _diaryPageSize;
  bool _hasMoreDiaries = false;
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
        final currentPagingSignature = _buildPagingSignature(filterState);
        _syncPagingStateWithFilterSignature(currentPagingSignature);
        final diaryPageQuery = DiaryPageQuery(
          keyword: filterState.keyword.trim(),
          requiredTagIds: filterState.selectedTagIds.toList()..sort(),
          limit: _visibleDiaryLimit,
          sortMode: _toQuerySortMode(_sortMode),
        );
        final diariesAsync = ref.watch(pagedDiariesProvider(diaryPageQuery));
        final latestPage = diariesAsync.asData?.value;
        final latestVisibleItems =
            latestPage == null ? null : _resolveVisibleItems(latestPage.items);

        if (latestPage != null) {
          _hasMoreDiaries = latestPage.hasMore;
        }

        if (latestVisibleItems != null &&
            !identical(latestVisibleItems, _lastSyncedVisibleItemsRef)) {
          _transitionCoordinator.syncAppearingTimers(latestVisibleItems);
          _lastSyncedVisibleItemsRef = latestVisibleItems;
        }

        final displayedItems = latestVisibleItems ?? _cachedVisibleItems;
        final shouldUnpinSelected = _controller.areAllSelectedPinned(
          displayedItems,
        );
        final hasMoreDiaries = _hasMoreDiaries;

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
                  child: SafeArea(
                    top: true,
                    child: ColoredBox(
                      color: widget.pageBackgroundColor,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handlePrimaryScrollNotification,
                        child: CustomScrollView(
                          key: PageStorageKey<String>(
                            'diaries_scroll_${brightness.name}_${_layoutMode.name}',
                          ),
                          slivers: <Widget>[
                            SliverPersistentHeader(
                              pinned: _isSelectionMode,
                              floating: !_isSelectionMode,
                              delegate: _FixedSliverHeaderDelegate(
                                height: _headerCollapsibleHeight,
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                child: SizedBox(
                                  height: _headerCollapsibleHeight,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
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
                                              _controller
                                                  .deleteSelectedDiaries(),
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
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _FixedSliverHeaderDelegate(
                                height: _tagPinnedHeaderHeight,
                                backgroundColor: widget.pageBackgroundColor,
                                child: tagsAsync.when(
                                  data: (tags) {
                                    final visibleTagFilters =
                                        _resolveTagFiltersForDisplay(
                                          allTags: tags,
                                          visibleItems: displayedItems,
                                          keyword: filterState.keyword,
                                        );
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        top: _tagSectionTopGap,
                                        bottom: _tagSectionBottomGap,
                                      ),
                                      child: DiaryTagFilterBar(
                                        tags: visibleTagFilters,
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
                                      () => const Padding(
                                        padding: EdgeInsets.only(
                                          top: _tagSectionTopGap,
                                          bottom: _tagSectionBottomGap,
                                        ),
                                        child: SizedBox(height: 40),
                                      ),
                                  error: (Object error, StackTrace stackTrace) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        top: _tagSectionTopGap,
                                        bottom: _tagSectionBottomGap,
                                        left: AppSpacing.m,
                                        right: AppSpacing.m,
                                      ),
                                      child: SizedBox(
                                        height: 40,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            context.l10n.autoT0042(
                                              error.toString(),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
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
                                            child: CircularProgressIndicator(
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
                                        diaries: displayedItems,
                                        layoutMode: _layoutMode,
                                        isSelectionMode: _isSelectionMode,
                                        selectedDiaryIds: _selectedDiaryIds,
                                        pendingHideDiaryIds:
                                            _pendingHideDiaryIds,
                                        appearingDiaryIds: _appearingDiaryIds,
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
                                              _controller.archiveDiaryBySwipe(
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

  /// 解析当前可见日记列表，并在输入不变时复用上次结果。
  ///
  /// 缓存失效条件：
  /// 1) provider 返回的日记源引用发生变化；
  /// 2) 排序模式变化；
  /// 3) 乐观隐藏集合变化（归档/删除过渡）。
  List<DiaryWithTags> _resolveVisibleItems(List<DiaryWithTags> sourceItems) {
    final hiddenSignature = _buildDiaryIdSignature(_optimisticHiddenDiaryIds);
    final canReuseCache =
        identical(sourceItems, _cachedVisibleSourceItemsRef) &&
        _cachedVisibleSortMode == _sortMode &&
        _cachedHiddenDiaryIdsSignature == hiddenSignature;
    if (canReuseCache) {
      return _cachedVisibleItems;
    }

    final resolved = _controller.buildVisibleItems(sourceItems);
    _cachedVisibleSourceItemsRef = sourceItems;
    _cachedVisibleSortMode = _sortMode;
    _cachedHiddenDiaryIdsSignature = hiddenSignature;
    _cachedVisibleItems = resolved;
    return resolved;
  }

  /// 解析顶部标签筛选列表，并在可复用时直接返回缓存。
  List<Tag> _resolveTagFiltersForDisplay({
    required List<Tag> allTags,
    required List<DiaryWithTags> visibleItems,
    required String keyword,
  }) {
    final normalizedKeyword = keyword.trim();
    final canReuseCache =
        identical(allTags, _cachedTagFilterSourceTagsRef) &&
        identical(visibleItems, _cachedTagFilterVisibleItemsRef) &&
        _cachedTagFilterKeyword == normalizedKeyword;
    if (canReuseCache) {
      return _cachedTagFilters;
    }

    final resolved = _controller.buildTagFiltersForDisplay(
      allTags: allTags,
      visibleItems: visibleItems,
      keyword: normalizedKeyword,
    );
    _cachedTagFilterSourceTagsRef = allTags;
    _cachedTagFilterVisibleItemsRef = visibleItems;
    _cachedTagFilterKeyword = normalizedKeyword;
    _cachedTagFilters = resolved;
    return resolved;
  }

  String _buildDiaryIdSignature(Set<String> ids) {
    if (ids.isEmpty) {
      return '';
    }
    final sorted = ids.toList()..sort();
    return sorted.join(',');
  }

  /// 构建当前分页上下文签名。
  ///
  /// 当关键词或标签筛选发生变化时，签名会变化，分页会自动回到首屏 20 条。
  String _buildPagingSignature(DiaryFilterState filterState) {
    final normalizedKeyword = filterState.keyword.trim();
    final sortedTagIds = filterState.selectedTagIds.toList()..sort();
    return '$normalizedKeyword|${sortedTagIds.join(",")}|${_sortMode.name}';
  }

  DiaryQuerySortMode _toQuerySortMode(DiarySortMode sortMode) {
    return switch (sortMode) {
      DiarySortMode.updatedAsc => DiaryQuerySortMode.updatedAsc,
      DiarySortMode.titleAsc => DiaryQuerySortMode.titleAsc,
      DiarySortMode.updatedDesc => DiaryQuerySortMode.updatedDesc,
    };
  }

  /// 同步分页状态与筛选条件。
  ///
  /// 只要筛选条件变化，就重置分页窗口，避免旧分页状态污染新结果集。
  void _syncPagingStateWithFilterSignature(String signature) {
    if (_pagingSignature == signature) {
      return;
    }
    _pagingSignature = signature;
    _hasMoreDiaries = false;
    _visibleDiaryLimit = _diaryPageSize;
    _isPagingCooldown = false;
    _pagingCooldownTimer?.cancel();
    _pagingCooldownTimer = null;
  }

  /// 请求加载下一批日记（每次 +20）。
  ///
  /// 数据库查询会随 [_visibleDiaryLimit] 变化重新带 `LIMIT` 拉取窗口，
  /// 因此这里不再依赖全量结果数量，只根据 provider 返回的 hasMore 推进。
  void _requestLoadMoreDiaries() {
    if (_isPagingCooldown || !_hasMoreDiaries) {
      return;
    }
    setState(() {
      _visibleDiaryLimit += _diaryPageSize;
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

class _FixedSliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FixedSliverHeaderDelegate({
    required this.height,
    required this.backgroundColor,
    required this.child,
  });

  final double height;
  final Color backgroundColor;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: backgroundColor,
      child: SizedBox.expand(child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _FixedSliverHeaderDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.child != child;
  }
}
