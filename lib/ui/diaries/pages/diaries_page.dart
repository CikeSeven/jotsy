import 'dart:async';

import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/controllers/diary_export_flow.dart';
import 'package:node_diary/ui/diaries/pages/archived_diaries_page.dart';
import 'package:node_diary/ui/diaries/pages/diary_drafts_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_draft_providers.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/pages/diary_search_page.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_entry_flow.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_chrome_scope.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_top_bar_surface.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/tag_order_codec.dart';
import '../../notebooks/controllers/notebook_lock_flow.dart';
import '../../notebooks/controllers/notebook_membership_ops.dart';
import '../../notebooks/models/notebook_scope_resolver.dart';
import '../../notebooks/providers/home_notebook_scope_provider.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/sections/notebook_action_flows.dart';
import '../../notebooks/pages/notebook_add_diaries_page.dart';
import '../../notebooks/pages/notebook_contents_page.dart';
import '../../notebooks/controllers/notebook_book_export_flow.dart';
import '../../notebooks/pages/notebook_insights_page.dart';
import '../../notebooks/sections/notebook_action_sheets.dart';
import '../../notebooks/sections/notebook_picker_sheet.dart';
import '../../notebooks/sections/notebook_shelf_sheet.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../notebooks/widgets/notebook_chapter_divider.dart';
import '../../notebooks/widgets/notebook_header_sliver.dart';
import '../../notebooks/widgets/notebook_switcher_chip.dart';
import '../../settings/pages/diary_card_style_page.dart';
import '../../settings/providers/app_features_provider.dart';
import '../models/diary_card_style/diary_card_style.dart';
import '../providers/diary_card_style_provider.dart';
import '../viewmodels/diary_view_preferences.dart';
import '../sections/diaries_list_section.dart';
import '../sections/diary_view_options_sheet.dart';
import '../widgets/diaries_header_sliver.dart';
import '../widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/launch_reveal.dart';

part '../controllers/diaries_page_feedback.dart';
part '../controllers/diary_list_transition_coordinator.dart';
part '../controllers/diaries_page_controller.dart';
part '../controllers/diaries_notebook_scope_controller.dart';
part '../controllers/diaries_notebook_membership_controller.dart';

/// 日记列表页。
///
/// 提供关键词搜索、标签筛选、列表展示与进入预览页能力。

class DiariesPage extends ConsumerStatefulWidget {
  const DiariesPage({
    super.key,
    this.pageBackgroundColor,
    this.onCreateActionChanged,
    this.onFabVisibilityChanged,
  });

  final Color? pageBackgroundColor;
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
  static const Duration _listItemTransitionDuration =
      DiariesListSection.itemTransitionDuration;
  static const Duration _listRefreshFadeOutDuration = ExpressiveMotion.fast;
  static const Duration _listRefreshFadeInDuration = ExpressiveMotion.medium;
  static const double _fabToggleScrollThreshold = 26;
  static const int _diaryPageSize = diaryFirstPageSize;
  static const double _loadMoreTriggerExtent = 420;
  static const double _listBottomExtraSpace = 12;
  static const double _tagSectionTopGap = 2;
  static const double _tagSectionBottomGap = 4;

  /// 与 `DiaryHeadSection` 自身高度（顶部 4dp + 52dp 内容行）一致：多留的
  /// 空白会垫在搜索条与标签栏之间，让两者显得脱节。
  static const double _headerCollapsibleHeight = 56;
  static const Duration _tagFilterSnapDuration = ExpressiveMotion.medium;
  static const double _tagFilterFlingVelocity = 600;
  static const double _tagFilterDragCommitDistance = 24;

  // ==================== 列表选择与过渡状态 ====================
  final Set<String> _selectedDiaryIds = <String>{};
  final Set<String> _optimisticHiddenDiaryIds = <String>{};
  final Set<String> _pendingHideDiaryIds = <String>{};
  final Set<String> _appearingDiaryIds = <String>{};
  final Set<String> _archivingDiaryIds = <String>{};
  final Map<String, Timer> _pendingHideTimers = <String, Timer>{};
  final Map<String, Timer> _appearingTimers = <String, Timer>{};

  /// 玻璃顶栏（刊头 + 标签栏）共用的背景组 key：保持不变，页面重建时
  /// BackdropGroup 不会通知引用它的玻璃重建。
  final BackdropKey _topBarsBackdropKey = BackdropKey();

  // ==================== 列表整体过渡动画 ====================
  late final AnimationController _listRefreshPulseController;
  // 筛选过渡状态（由 DiaryListTransitionCoordinator 读写）：
  // - generation：每次筛选变更自增，过渡只为最新一轮淡入；
  // - held：淡出期间冻结的展示列表，防止新旧数据在半透明时互换；
  // - scrollToTop：本轮过渡释放冻结时让列表回到顶部（切换排序时置位）；
  // - lastDisplayed/currentQuery：build 写入，供冻结与等待首帧数据使用。
  int _filterMutationGeneration = 0;
  Future<void>? _queuedFilterTransition;
  Completer<void>? _filterQueryWaiter;
  List<DiaryWithTags>? _heldDisplayedItems;
  bool _scrollToTopOnFilterRelease = false;
  List<DiaryWithTags> _lastDisplayedItems = const <DiaryWithTags>[];
  DiaryPageQuery? _currentDiaryPageQuery;
  List<DiaryWithTags> _cachedVisibleItems = const <DiaryWithTags>[];
  List<DiaryWithTags>? _cachedVisibleSourceItemsRef;
  String _cachedHiddenDiaryIdsSignature = '';
  List<DiaryWithTags>? _lastSyncedVisibleItemsRef;
  List<Tag>? _cachedTagFilterSourceTagsRef;
  List<DiaryWithTags>? _cachedTagFilterVisibleItemsRef;
  String _cachedTagFilterKeyword = '';
  List<Tag> _cachedTagFilters = const <Tag>[];
  bool _fabVisibleByScroll = true;
  double _fabScrollDeltaAccumulator = 0;
  int _visibleDiaryLimit = _diaryPageSize;
  bool _hasMoreDiaries = false;
  String _pagingSignature = '';
  bool _isPagingCooldown = false;
  Timer? _pagingCooldownTimer;
  DiarySortMode _sortMode = DiarySortMode.updatedDesc;
  DiaryLayoutMode _layoutMode = DiaryLayoutMode.list;
  bool _viewPreferencesLoaded = false;
  late final AnimationController _tagFilterExpansionController;
  double _tagFilterDragDelta = 0;

  /// 标签栏是否（部分）展开：决定系统返回是否先收起标签栏，变化时重建页面
  /// 以更新 PopScope。
  bool _tagFiltersExpanded = false;

  // ==================== 页面职责拆分协作对象 ====================
  late final DiariesPageFeedback _feedback;
  late final DiaryListTransitionCoordinator _transitionCoordinator;
  late final DiariesPageController _controller;
  late final DiariesNotebookScopeController _scopeController;
  late final DiariesNotebookMembershipController _membershipController;

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
    _scopeController = DiariesNotebookScopeController(
      this,
      feedback: _feedback,
      transitionCoordinator: _transitionCoordinator,
    );
    _membershipController = DiariesNotebookMembershipController(
      this,
      feedback: _feedback,
      transitionCoordinator: _transitionCoordinator,
    );
    _tagFilterExpansionController = AnimationController(
      vsync: this,
      duration: _tagFilterSnapDuration,
    )..addListener(_syncTagFiltersExpanded);
    widget.onCreateActionChanged?.call(_openCreateFromHomeFab);
    widget.onFabVisibilityChanged?.call(_fabVisibleByScroll);
    unawaited(_controller.restoreRememberedTagFiltersOnStartup());
    // 筛选切换时做整列表淡入淡出，降低“突兀跳变”的观感。控制器值直接作为
    // 不透明度，曲线只在 animateTo 中给一次，避免与 CurvedAnimation 叠加。
    _listRefreshPulseController = AnimationController(
      vsync: this,
      duration: _listRefreshFadeInDuration,
      value: 1,
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
  }

  @override
  void dispose() {
    widget.onCreateActionChanged?.call(null);
    _transitionCoordinator.dispose();
    _pagingCooldownTimer?.cancel();
    _tagFilterExpansionController.dispose();
    _listRefreshPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colorScheme = theme.colorScheme;
    final pageBgColor = widget.pageBackgroundColor ?? colorScheme.surface;
    final diaryCardTagLimit =
        ref.watch(diaryCardTagLimitProvider).asData?.value ??
        SettingsService.defaultDiaryCardTagLimit;
    // 标签与日记列表分别独立监听，避免相互阻塞。
    final settingsAsync = ref.watch(settingsServiceProvider);
    final filterState = ref.watch(diaryFilterProvider);
    final tagsAsync = ref.watch(tagListProvider);
    // 首页顶栏用玻璃时，列表滚到状态栏下方，状态栏那一条并进顶栏（见
    // DiariesHeaderSliver）。两处高度都从页面自己的 context 读（在下面的
    // SafeArea 之外、首页 Scaffold 的 body 之内）：
    // - top：状态栏高度；
    // - bottom：玻璃底栏悬浮在内容之上（首页 Scaffold extendBody）时为底栏
    //   槽位高度，末尾多留这一段，最后一篇才能完整滚到胶囊上方；实色底栏时
    //   Scaffold 已扣掉，为 0，列表底部与改版前一致。
    final glassTopBars = HomeChromeScope.glassTopBarsOf(context);
    final viewPadding = MediaQuery.paddingOf(context);
    final listBottomOffset = _listBottomExtraSpace + viewPadding.bottom;
    // 当前范围（全部日记 / 某本日记本）；全部日记时不订阅书架列表。
    final scopeResolution = ref.watch(homeNotebookScopeResolutionProvider);
    final currentNotebook = scopeResolution.notebook;
    // 日记本功能关闭时隐藏入口，数据保留：不订阅书架，标签栏不留切换胶囊。
    final notebooksEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.notebooks),
    );
    final hasNotebooks = notebooksEnabled && ref.watch(hasNotebooksProvider);
    ref.listen<bool>(
      appFeaturesProvider.select((features) => features.notebooks),
      (_, bool enabled) => _scopeController.handleFeatureToggled(enabled),
    );
    ref.listen<HomeNotebookScopeResolution>(
      homeNotebookScopeResolutionProvider,
      _scopeController.handleResolutionChanged,
    );
    ref.listen<String?>(
      homeNotebookScopeProvider.select((scope) => scope.notebookId),
      (_, String? next) => _scopeController.handleScopeIdChanged(next),
    );
    // 日记本里只列本子里用到的标签（已选的保留，好让用户取消）。
    final scopeTagIds = scopeResolution.isAll
        ? null
        : ref.watch(scopeTagIdsProvider(scopeResolution.scope)).value;

    return settingsAsync.when(
      loading: () => const Scaffold(body: DelayedLoadingIndicator()),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        body: Center(child: Text(context.l10n.autoT0045(error.toString()))),
      ),
      data: (settingsService) {
        _controller.loadViewPreferencesIfNeeded(settingsService);
        // 日记本里按本子自己的排序，不用全局排序偏好。
        final notebookSort = scopeResolution.sort;
        final sortMode = notebookSort == null
            ? _sortMode
            : diarySortModeForNotebook(notebookSort);
        final currentPagingSignature = _buildPagingSignature(
          filterState,
          sortMode: sortMode,
          scope: scopeResolution.scope,
        );
        _syncPagingStateWithFilterSignature(currentPagingSignature);
        final diaryPageQuery = DiaryPageQuery(
          keyword: filterState.keyword.trim(),
          requiredTagIds: filterState.selectedTagIds.toList()..sort(),
          limit: _visibleDiaryLimit,
          sortMode: sortMode,
          scope: scopeResolution.scope,
        );
        final diariesAsync = ref.watch(pagedDiariesProvider(diaryPageQuery));
        final latestPage = diariesAsync.asData?.value;
        final latestVisibleItems = latestPage == null
            ? null
            : _resolveVisibleItems(latestPage.items);

        if (latestPage != null) {
          _hasMoreDiaries = latestPage.hasMore;
        }

        if (latestVisibleItems != null &&
            !identical(latestVisibleItems, _lastSyncedVisibleItemsRef)) {
          _transitionCoordinator.syncAppearingTimers(latestVisibleItems);
          _lastSyncedVisibleItemsRef = latestVisibleItems;
        }

        // 筛选过渡淡出期间优先展示冻结列表，新查询首帧数据到达后才释放。
        final displayedItems =
            _heldDisplayedItems ?? latestVisibleItems ?? _cachedVisibleItems;
        _lastDisplayedItems = displayedItems;
        _currentDiaryPageQuery = diaryPageQuery;
        final shouldUnpinSelected = _controller.areAllSelectedPinned(
          displayedItems,
        );
        final hasMoreDiaries = _hasMoreDiaries;
        // 普通日记本里多选才有“移出 / 移动到”；头部卡片与列表卡片同一侧边距。
        // 功能关闭的那一刻范围还没退回全部日记（见 handleFeatureToggled），
        // 这里先不给本子里的操作。
        final manualNotebook =
            notebooksEnabled &&
                currentNotebook != null &&
                currentNotebook.isManual
            ? currentNotebook
            : null;
        final cardStyle = ref.watch(diaryCardStyleProvider);
        // 与列表（DiariesListSection 经 DiaryCardResolvedStyle）同一份模式样式：
        // resolved.modeStyle 就是 style.mode(mode)，边距与卡片间距两处一致。
        final cardModeStyle = cardStyle.mode(
          _layoutMode == DiaryLayoutMode.waterfall
              ? DiaryCardMode.waterfall
              : DiaryCardMode.list,
        );
        final cardSideMargin = cardModeStyle.sideMargin;
        final tagHeaderContent = tagsAsync.when(
          data: (tags) {
            final visibleTagFilters = _resolveTagFiltersForDisplay(
              allTags: _scopeTags(
                tags,
                scopeTagIds,
                filterState.selectedTagIds,
              ),
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
                expansionProgress: _tagFilterExpansionController,
                canExpand: () => _tagFilterExpansionController.value < 1,
                canCollapse: () => _tagFilterExpansionController.value > 0,
                selectedTagFilterIds: filterState.selectedTagIds,
                onToggleTagFilter: _controller.toggleTagFilter,
                onClearTagFilters: _controller.clearTagFilters,
                onVerticalDragStart: (_) => _handleTagFilterDragStart(),
                onVerticalDragUpdate: _handleTagFilterDragUpdate,
                onVerticalDragEnd: _handleTagFilterDragEnd,
                onCollapse: () => _animateTagFiltersTo(false),
                leading: notebooksEnabled
                    ? NotebookSwitcherChip(
                        notebook: currentNotebook,
                        onTap: () => unawaited(_scopeController.openShelf()),
                      )
                    : null,
                leadingWidth: notebooksEnabled
                    ? NotebookSwitcherChip.measureWidth(
                        context,
                        currentNotebook,
                      )
                    : 0,
                keepVisible:
                    notebooksEnabled &&
                    (hasNotebooks || currentNotebook != null),
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.only(
              top: _tagSectionTopGap,
              bottom: _tagSectionBottomGap,
            ),
            child: SizedBox(height: 40),
          ),
          error: (Object error, StackTrace stackTrace) => Padding(
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
                  context.l10n.autoT0042(error.toString()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
        // Measure the animated bar itself instead of reserving a fixed
        // maximum-height sliver. Content changes and width/text-scale changes then
        // update the pinned extent in the same layout pass, without a delayed
        // size callback or a second independently calculated animation.
        // 底色留在编排之外：入场期间只有标签内容淡入上浮，不透出下方列表；
        // 玻璃时同理，玻璃绝不能放进 LaunchReveal 的透明度层（模糊采不到
        // 页面）。标签栏始终存在（没有标签时也留着上下间距），是顶栏最下面
        // 一片，底缘细线画在这里、不画在刊头上。
        final tagHeader = PinnedHeaderSliver(
          child: HomeTopBarSurface(
            solidColor: pageBgColor,
            showHairline: true,
            grouped: true,
            child: LaunchReveal(
              slot: LaunchRevealSlot.filters,
              child: tagHeaderContent,
            ),
          ),
        );

        return Scaffold(
          backgroundColor: pageBgColor,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              // 返回键优先处理页面内部状态，再交给路由栈。
              PopScope(
                canPop:
                    !_isSelectionMode &&
                    !_tagFiltersExpanded &&
                    scopeResolution.isAll,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) {
                    return;
                  }
                  _handlePopBlocked();
                },
                child: Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) {
                      return KeyEventResult.ignored;
                    }
                    return KeyEventResult.ignored;
                  },
                  // 玻璃顶栏时不让出状态栏：列表滚到状态栏下方，由刊头的
                  // 玻璃盖住。底部始终不让：实色时本就为 0，玻璃时列表要
                  // 滚到悬浮胶囊下方（末尾占位已补上胶囊高度）。
                  child: SafeArea(
                    top: !glassTopBars,
                    bottom: false,
                    child: ColoredBox(
                      color: pageBgColor,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handlePrimaryScrollNotification,
                        // 刊头与标签栏两片玻璃共用一次背景读取（同一区域
                        // 不叠两层重模糊）。BackdropGroup 只是 InheritedWidget，
                        // 实色时没有玻璃引用它，始终挂着免得切换材质时
                        // 列表被重新挂载、丢掉滚动位置。
                        child: BackdropGroup(
                          backdropKey: _topBarsBackdropKey,
                          child: CustomScrollView(
                            key: PageStorageKey<String>(
                              'diaries_scroll_${brightness.name}_${_layoutMode.name}',
                            ),
                            slivers: <Widget>[
                              DiariesHeaderSliver(
                                pinned: _isSelectionMode,
                                height: _headerCollapsibleHeight,
                                glass: glassTopBars,
                                topInset: viewPadding.top,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                child: SizedBox(
                                  height: _headerCollapsibleHeight,
                                  child: LaunchReveal(
                                    slot: LaunchRevealSlot.masthead,
                                    // 只让顶栏随草稿份数重建，不牵动整页。
                                    child: Consumer(
                                      builder: (context, ref, _) => DiaryHeadSection(
                                        isSelectionMode: _isSelectionMode,
                                        selectedCount: _selectedDiaryIds.length,
                                        onCancelSelection:
                                            _controller.clearSelection,
                                        isPinActionUnpin: shouldUnpinSelected,
                                        onPinSelected: () => unawaited(
                                          _controller.pinSelectedDiaries(
                                            unpin: shouldUnpinSelected,
                                          ),
                                        ),
                                        onArchiveSelected: () => unawaited(
                                          _controller.archiveSelectedDiaries(),
                                        ),
                                        onExportSelected: () => unawaited(
                                          _controller.exportSelectedDiaries(),
                                        ),
                                        onDeleteSelected: () => unawaited(
                                          _controller.deleteSelectedDiaries(),
                                        ),
                                        // 日记本功能关闭时多选栏不给收录 / 移出 / 移动。
                                        onAddToNotebookSelected:
                                            !notebooksEnabled
                                            ? null
                                            : () => unawaited(
                                                _membershipController
                                                    .addSelectedToNotebooks(),
                                              ),
                                        onRemoveFromNotebookSelected:
                                            manualNotebook == null
                                            ? null
                                            : () => unawaited(
                                                _membershipController
                                                    .removeSelectedFromCurrent(),
                                              ),
                                        onMoveToNotebookSelected:
                                            manualNotebook == null
                                            ? null
                                            : () => unawaited(
                                                _membershipController
                                                    .moveSelectedToNotebook(),
                                              ),
                                        onOpenArchived:
                                            _controller.openArchivedPage,
                                        onOpenDrafts:
                                            _controller.openDraftsPage,
                                        draftCount:
                                            ref
                                                .watch(diaryDraftCountProvider)
                                                .value ??
                                            0,
                                        onOpenViewOptions:
                                            _controller.openViewOptions,
                                        onOpenSearchPage:
                                            _controller.openSearchPage,
                                        searchHint: currentNotebook == null
                                            ? null
                                            : context.l10n.notebookSearchIn(
                                                NotebookSwitcherChip.labelFor(
                                                  context,
                                                  currentNotebook,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              tagHeader,
                              // 玻璃顶栏底缘有一条细线，静止时第一张卡片（或日记本
                              // 头部卡片）贴着它显得挤；实色时同色无线、看不出来。
                              // 只在玻璃时留一段与卡片间距相同的空白，让第一张卡片
                              // 离细线与卡片彼此之间一样远。放成随内容滚走的普通
                              // sliver，而不是加高固定的标签栏：滚动后不多占顶栏。
                              // 实色时不插入，布局与改版前逐像素一致。卡片间距可调到
                              // 0（卡片相接），此时仍至少留 8，不让卡片压在细线上。
                              if (glassTopBars)
                                SliverToBoxAdapter(
                                  key: const ValueKey<String>(
                                    'diaries_glass_top_gap',
                                  ),
                                  child: SizedBox(
                                    height: cardModeStyle.cardGap < 8
                                        ? 8
                                        : cardModeStyle.cardGap,
                                  ),
                                ),
                              NotebookHeaderSliver(
                                notebook: currentNotebook,
                                horizontalMargin: cardSideMargin,
                                onAction: (NotebookAction action) => unawaited(
                                  _scopeController.handleHeaderAction(action),
                                ),
                                onExportBook: () =>
                                    unawaited(_scopeController.exportBook()),
                                onAddDiaries: manualNotebook == null
                                    ? null
                                    : () => unawaited(
                                        _scopeController.openAddDiaries(),
                                      ),
                                onOpenContents: manualNotebook == null
                                    ? null
                                    : () => unawaited(
                                        _scopeController.openContents(),
                                      ),
                                onOpenInsights: () =>
                                    unawaited(_scopeController.openInsights()),
                                selectedChapterId:
                                    scopeResolution.state.chapterId,
                                unassignedChapterOnly:
                                    scopeResolution.state.unassignedChapterOnly,
                                onSelectChapter: _scopeController.selectChapter,
                              ),
                              SliverFadeTransition(
                                opacity: _listRefreshPulseController,
                                sliver:
                                    // 数据状态优先级：
                                    // 1) 首屏加载且无缓存；
                                    // 2) 首屏错误且无缓存；
                                    // 3) 渲染列表/空态内容。
                                    diariesAsync.isLoading &&
                                        displayedItems.isEmpty
                                    ? const SliverFillRemaining(
                                        hasScrollBody: false,
                                        child: DelayedLoadingIndicator(
                                          size: 22,
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
                                          'diaries_list_${_layoutMode.name}',
                                        ),
                                        diaries: displayedItems,
                                        layoutMode: _layoutMode,
                                        isSelectionMode: _isSelectionMode,
                                        selectedDiaryIds: _selectedDiaryIds,
                                        maxVisibleTags: diaryCardTagLimit,
                                        cardStyle: cardStyle,
                                        moodOptions: ref.watch(
                                          diaryCardMoodOptionsProvider,
                                        ),
                                        pendingHideDiaryIds:
                                            _pendingHideDiaryIds,
                                        appearingDiaryIds: _appearingDiaryIds,
                                        onCreate: () => unawaited(
                                          _controller
                                              .openCreateEditorWithDraftPrompt(),
                                        ),
                                        onOpenEditor: (diary, coverHero) {
                                          _controller.openPreview(
                                            diary.diary.diaryId,
                                            initialDetail: diary,
                                            coverHero: coverHero,
                                          );
                                        },
                                        onToggleSelection:
                                            (noteId, forceSelect) =>
                                                _controller.toggleSelection(
                                                  noteId,
                                                  forceSelect: forceSelect,
                                                ),
                                        onArchiveDiary: (diaryId) => unawaited(
                                          _controller.archiveDiaryBySwipe(
                                            diaryId,
                                          ),
                                        ),
                                        isSearchResultEmpty: false,
                                        sectionHeaderBuilder:
                                            _bookSectionHeaders(
                                              scopeResolution,
                                              displayedItems,
                                            ),
                                        // 日记本里没筛选时的空列表：“这本还空着”。
                                        emptyState:
                                            currentNotebook != null &&
                                                filterState
                                                    .selectedTagIds
                                                    .isEmpty
                                            ? NotebookEmptyState(
                                                onWriteFirst:
                                                    manualNotebook == null
                                                    ? null
                                                    : () => unawaited(
                                                        _controller
                                                            .openCreateEditorWithDraftPrompt(),
                                                      ),
                                                onPickExisting:
                                                    manualNotebook == null
                                                    ? null
                                                    : () => unawaited(
                                                        _scopeController
                                                            .openAddDiaries(),
                                                      ),
                                              )
                                            : null,
                                      ),
                              ),
                              // 还有下一页时常驻一个固定高度的槽位（加载前后
                              // 列表底部不跳），指示器只在下一页真正加载且超过
                              // 300ms 时出现：常驻的循环指示器即使滚出屏幕、
                              // 切到其他 Tab 也会逐帧出帧耗电。
                              if (hasMoreDiaries)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: SizedBox(
                                      height: 18,
                                      child: diariesAsync.isLoading
                                          ? const DelayedLoadingIndicator(
                                              size: 18,
                                            )
                                          : null,
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
              ),
            ],
          ),
        );
      },
    );
  }

  /// 书序分隔行：只在普通日记本按书序、选着“全部”章节、列表布局且本子有
  /// 章节时提供（瀑布流不分隔，保持简单）。只在这时订阅本子的章节归属，
  /// 其他情况不多一条查询。
  Widget? Function(BuildContext, int)? _bookSectionHeaders(
    HomeNotebookScopeResolution resolution,
    List<DiaryWithTags> displayedItems,
  ) {
    final notebook = resolution.notebook;
    if (notebook == null ||
        !notebook.isManual ||
        resolution.sort != NotebookSort.book ||
        resolution.state.chapterId != null ||
        resolution.state.unassignedChapterOnly ||
        _layoutMode != DiaryLayoutMode.list ||
        notebook.payload.chapters.isEmpty) {
      return null;
    }
    final entryChapters = ref
        .watch(notebookEntryChaptersProvider(notebook.id))
        .value;
    if (entryChapters == null) {
      return null;
    }
    return notebookBookSectionHeaders(
      diaries: displayedItems,
      chapters: notebook.payload.chapters,
      entryChapters: entryChapters,
    );
  }

  /// 返回被拦下时的顺序：退出多选 → 收起展开的标签栏 → 回到全部日记。
  ///
  /// 日记页在 Home 里保活，切到别的 Tab 后它的 PopScope 仍会收到返回；那时
  /// 返回只用于切回日记页（Home 处理），后两步只在日记页可见时执行。
  void _handlePopBlocked() {
    if (_isSelectionMode) {
      _controller.clearSelection();
      return;
    }
    if (!TickerMode.valuesOf(context).enabled) {
      return;
    }
    if (_tagFiltersExpanded) {
      _animateTagFiltersTo(false);
      return;
    }
    _scopeController.showAll();
  }

  void _syncTagFiltersExpanded() {
    final expanded = _tagFilterExpansionController.value > 0;
    if (expanded != _tagFiltersExpanded && mounted) {
      setState(() => _tagFiltersExpanded = expanded);
    }
  }

  /// 标签栏的候选标签：全部日记时为全部标签；日记本里只留本子里用到的与
  /// 已选的（[scopeTagIds] 还没查出来时先显示全部）。
  List<Tag> _scopeTags(
    List<Tag> tags,
    Set<int>? scopeTagIds,
    Set<int> selectedTagIds,
  ) {
    if (scopeTagIds == null) {
      return tags;
    }
    final filtered = <Tag>[
      for (final tag in tags)
        if (scopeTagIds.contains(tag.id) || selectedTagIds.contains(tag.id))
          tag,
    ];
    // 内容没变时沿用上次的列表实例，下游的标签缓存按引用复用。
    final previous = _cachedScopeTags;
    if (previous != null &&
        previous.length == filtered.length &&
        identical(_cachedScopeTagsSource, tags) &&
        _sameTagIds(previous, filtered)) {
      return previous;
    }
    _cachedScopeTagsSource = tags;
    return _cachedScopeTags = filtered;
  }

  List<Tag>? _cachedScopeTags;
  List<Tag>? _cachedScopeTagsSource;

  static bool _sameTagIds(List<Tag> a, List<Tag> b) {
    for (var index = 0; index < a.length; index++) {
      if (a[index].id != b[index].id) {
        return false;
      }
    }
    return true;
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

  void _handleTagFilterDragStart() {
    _tagFilterExpansionController.stop();
    _tagFilterDragDelta = 0;
  }

  void _handleTagFilterDragUpdate(double delta, double expansionExtent) {
    // The sliver extent and the bar's clipping viewport share this normalized
    // progress, so the content follows the finger without a second animation.
    _tagFilterDragDelta += delta;
    if (expansionExtent <= 0) {
      return;
    }
    final nextProgress =
        (_tagFilterExpansionController.value + delta / expansionExtent).clamp(
          0.0,
          1.0,
        );
    _tagFilterExpansionController.value = nextProgress;
  }

  void _handleTagFilterDragEnd(double velocity) {
    // A deliberate short pull should not require traversing half of the
    // visible panel. Use net displacement for slow gestures so moving back
    // towards the start cancels the intent; tiny movements retain the nearest
    // state, while a fling can still override the final position.
    final bool shouldExpand;
    if (velocity.abs() >= _tagFilterFlingVelocity) {
      shouldExpand = velocity > 0;
    } else if (_tagFilterDragDelta.abs() >= _tagFilterDragCommitDistance) {
      shouldExpand = _tagFilterDragDelta > 0;
    } else {
      shouldExpand = _tagFilterExpansionController.value >= 0.5;
    }
    _animateTagFiltersTo(shouldExpand);
  }

  void _animateTagFiltersTo(bool expanded) {
    final target = expanded ? 1.0 : 0.0;
    final duration = ExpressiveMotion.duration(context, _tagFilterSnapDuration);
    if (duration == Duration.zero) {
      _tagFilterExpansionController.value = target;
      return;
    }
    unawaited(
      _tagFilterExpansionController.animateTo(
        target,
        duration: duration,
        curve: ExpressiveMotion.effects,
      ),
    );
  }

  /// 解析当前可见日记列表，并在输入不变时复用上次结果。
  ///
  /// 缓存失效条件：
  /// 1) provider 返回的日记源引用发生变化（换排序即换查询，源引用随之变化）；
  /// 2) 乐观隐藏集合变化（归档/删除过渡）。
  List<DiaryWithTags> _resolveVisibleItems(List<DiaryWithTags> sourceItems) {
    final hiddenSignature = _buildDiaryIdSignature(_optimisticHiddenDiaryIds);
    final canReuseCache =
        identical(sourceItems, _cachedVisibleSourceItemsRef) &&
        _cachedHiddenDiaryIdsSignature == hiddenSignature;
    if (canReuseCache) {
      return _cachedVisibleItems;
    }

    final resolved = _controller.buildVisibleItems(sourceItems);
    _cachedVisibleSourceItemsRef = sourceItems;
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
  /// 当关键词、标签筛选、排序或范围（全部日记 / 日记本）发生变化时，签名会
  /// 变化，分页会自动回到首屏 20 条。
  String _buildPagingSignature(
    DiaryFilterState filterState, {
    required DiarySortMode sortMode,
    required DiaryListScope scope,
  }) {
    final normalizedKeyword = filterState.keyword.trim();
    final sortedTagIds = filterState.selectedTagIds.toList()..sort();
    return '$normalizedKeyword|${sortedTagIds.join(",")}|${sortMode.name}'
        '|$scope';
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
    // 冷却只是“连续触底时不重复加页”的节流标志，与 UI 无关，到期无需重建；
    // 底部加载指示器只由 hasMore 决定（下一页返回前仍为 true）。
    _pagingCooldownTimer?.cancel();
    _pagingCooldownTimer = Timer(const Duration(milliseconds: 140), () {
      _isPagingCooldown = false;
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
