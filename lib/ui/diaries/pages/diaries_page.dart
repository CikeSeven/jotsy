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
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/settings_service.dart';
import '../../widgets/glass_bottom_nav.dart';
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
    this.homeHintVisibleListenable,
  });

  final ValueListenable<bool>? homeHintVisibleListenable;

  @override
  ConsumerState<DiariesPage> createState() => _DiariesPage();
}

class _DiariesPage extends ConsumerState<DiariesPage>
    with TickerProviderStateMixin {
  // ==================== 动画与交互节奏常量 ====================
  static const Duration _deleteUndoSnackDuration = Duration(seconds: 4);
  static const Duration _archiveUndoSnackDuration = Duration(seconds: 4);
  static const Duration _restoreHintDuration = Duration(seconds: 2);
  static const Duration _fabShiftDuration = Duration(milliseconds: 260);
  static const Duration _listItemTransitionDuration = Duration(milliseconds: 220);
  static const Duration _listRefreshFadeOutDuration = Duration(milliseconds: 160);
  static const Duration _listRefreshFadeInDuration = Duration(milliseconds: 260);
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const Duration _searchMorphDuration = Duration(milliseconds: 280);
  static const double _fabLiftOffsetWhenHintVisible = 60;
  static const double _fabExtraGapAboveNav = 2;
  static const double _listBottomExtraSpace = 34;
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

  // ==================== 搜索输入与防抖状态 ====================
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;

  // ==================== 列表整体过渡动画 ====================
  late final AnimationController _listRefreshPulseController;
  late final Animation<double> _listRefreshOpacity;
  VoidCallback? _pendingFilterMutation;
  Future<void>? _queuedFilterTransition;
  List<DiaryWithTags> _cachedVisibleItems = const <DiaryWithTags>[];
  int _localHintVisibleCount = 0;
  String _searchInput = '';
  String _effectiveSearchKeyword = '';
  bool _isSearchMode = false;
  bool _isSearchAnimating = false;
  bool _homeHintVisible = false;
  int _listLayoutEpoch = 0;
  DiarySortMode _sortMode = DiarySortMode.updatedDesc;
  DiaryLayoutMode _layoutMode = DiaryLayoutMode.list;
  bool _viewPreferencesLoaded = false;

  // ==================== 页面职责拆分协作对象 ====================
  late final DiariesPageFeedback _feedback;
  late final DiaryListTransitionCoordinator _transitionCoordinator;
  late final DiariesPageController _controller;

  bool get _isSelectionMode => _selectedDiaryIds.isNotEmpty;
  bool get _showHeaderSection => !_isSearchAnimating;
  bool get _isAnyHintVisible =>
      _homeHintVisible || _localHintVisibleCount > 0;

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
    _controller.handleHomeHintListenableUpdate(
      previous: oldWidget.homeHintVisibleListenable,
      next: widget.homeHintVisibleListenable,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _transitionCoordinator.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listRefreshPulseController.dispose();
    super.dispose();
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

        final displayedItems =
            latestVisibleItems ?? _cachedVisibleItems;

        return Scaffold(
          backgroundColor: pageBackgroundColor,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              // 返回键优先处理页面内部状态，再交给路由栈。
              PopScope(
                canPop: !(_isSelectionMode || _isSearchMode),
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) {
                    return;
                  }
                  if (_isSelectionMode) {
                    _controller.clearSelection();
                    return;
                  }
                  if (_isSearchMode) {
                    _controller.exitSearchModeAndClear();
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
                                      tags: _controller.buildTagFiltersForDisplay(
                                        allTags: tags,
                                        visibleItems: displayedItems,
                                        keyword: filterState.keyword,
                                      ),
                                      selectedTagFilterIds: filterState.selectedTagIds,
                                      onToggleTagFilter: _controller.toggleTagFilter,
                                      onClearTagFilters: _controller.clearTagFilters,
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
                                    diariesAsync.isLoading && displayedItems.isEmpty
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
                                        : diariesAsync.hasError && displayedItems.isEmpty
                                        ? SliverFillRemaining(
                                          hasScrollBody: false,
                                          child: Center(
                                            child: Text(
                                              '日记加载失败: ${diariesAsync.asError?.error}',
                                            ),
                                          ),
                                        )
                                        : DiariesListSection(
                                          key: ValueKey<String>(
                                            'diaries_list_${_layoutMode.name}_$_listLayoutEpoch',
                                          ),
                                          themeBrightness: brightness,
                                          diaries: displayedItems,
                                          layoutMode: _layoutMode,
                                          isSelectionMode: _isSelectionMode,
                                          selectedDiaryIds: _selectedDiaryIds,
                                          pendingHideDiaryIds: _pendingHideDiaryIds,
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
                                          isSearchResultEmpty:
                                              filterState.keyword.trim().isNotEmpty,
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
                                        // 头部组件负责：搜索态、多选态、归档入口、排序布局菜单。
                                        DiaryHeadSection(
                                          isSelectionMode: _isSelectionMode,
                                          isSearchMode: _isSearchMode,
                                          selectedCount: _selectedDiaryIds.length,
                                          onCancelSelection: _controller.clearSelection,
                                          onArchiveSelected:
                                              () => unawaited(
                                                _controller.archiveSelectedDiaries(),
                                              ),
                                          onDeleteSelected:
                                              () => unawaited(
                                                _controller.deleteSelectedDiaries(),
                                              ),
                                          onOpenArchived: _controller.openArchivedPage,
                                          sortMode: _sortMode,
                                          layoutMode: _layoutMode,
                                          onMenuSelected: _controller.onMenuSelected,
                                          searchPreviewText: _searchInput,
                                          searchController: _searchController,
                                          searchFocusNode: _searchFocusNode,
                                          onEnterSearch: _controller.enterSearchMode,
                                          onExitSearch:
                                              _controller.exitSearchModeAndClear,
                                          onClearSearch:
                                              _controller.clearSearchInPlace,
                                          onSearchChanged:
                                              _controller.onSearchChanged,
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
                // FAB 在提示可见时自动上移，避免和 SnackBar 发生遮挡。
                AnimatedPositioned(
                  duration: _fabShiftDuration,
                  curve: Curves.easeOutCubic,
                  right: AppSpacing.xl,
                  bottom: fabBottomOffset,
                  child: FloatingActionButton(
                    onPressed: () => unawaited(
                      _controller.openCreateEditorWithDraftPrompt(),
                    ),
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
