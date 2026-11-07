import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../notebooks/controllers/diary_notebook_pick_flow.dart';
import '../../notebooks/controllers/notebook_quick_create_flows.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/form_width.dart';
import '../../widgets/image_viewer_hero.dart';
import '../../widgets/primary_shortcut.dart';
import '../../widgets/route_entrance_waiter.dart';
import '../../widgets/width_layout_builder.dart';
import '../controllers/diary_card_menu_flows.dart';
import '../controllers/diary_open_flow.dart';
import '../controllers/diary_search_controller.dart';
import '../controllers/diary_search_filter_flows.dart';
import '../models/diary_preview_sequence.dart';
import '../models/diary_search_preferences.dart';
import '../providers/diary_card_style_provider.dart';
import '../providers/diary_comments_provider.dart';
import '../providers/diary_filters.dart';
import '../providers/diary_mood_palette_provider.dart';
import '../providers/diary_search_providers.dart';
import '../sections/diaries_list_section.dart';
import '../sections/diary_head_section.dart';
import '../sections/diary_search_results_header.dart';
import '../sections/diary_search_suggestions.dart';
import '../sections/diary_search_top_bar.dart';
import '../widgets/diaries_empty_state.dart';
import '../widgets/diary_comments/diary_search_comment_hit.dart';

/// 日记搜索页（独立覆盖层，DESIGN.md §5.33）。
///
/// 结构：实色顶栏（返回 + 胶囊输入框 + 存为智能日记本，下面一行条件与筛选
/// 胶囊，见 [DiarySearchTopBar]）+ 下方内容区。内容区没有条件时为最近搜索
/// 与常用标签（[DiarySearchSuggestions]），有条件时为“共 N 篇 / 排序”与
/// 结果卡片（关键词高亮）。
///
/// 职责：本页只做装配——路由、生命周期、provider 订阅与组合。搜索会话
/// （防抖、条件、分页）在 [DiarySearchController]，筛选面板的流程在
/// `diary_search_filter_flows.dart`，最近搜索与排序是本机偏好
/// （[diarySearchPreferencesProvider]）。页面内的条件不回写首页的筛选。
///
/// 键盘：首次聚焦推迟到路由入场结束（[RouteEntranceWaiter]），键盘不与
/// 转场叠加；页面只读 `viewPadding`、结果列表只按宽度构建
/// （[WidthLayoutBuilder]），键盘升降时不逐帧重建结果卡片。
class DiarySearchPage extends ConsumerStatefulWidget {
  const DiarySearchPage({
    super.key,
    this.initialKeyword = '',
    this.initialTagIds = const <int>{},
    this.scope = DiaryListScope.all,
    this.scopeLabel,
    this.scopeIcon,
  });

  final String initialKeyword;
  final Set<int> initialTagIds;

  /// 搜索范围：从日记本里打开时为这本，条件行最前显示可移除的日记本胶囊
  /// （[scopeLabel] + [scopeIcon]）；移除后在全部日记中搜索。
  final DiaryListScope scope;
  final String? scopeLabel;
  final FaIconData? scopeIcon;

  /// 构建覆盖式搜索页路由，保持与日记列表入口一致的体感。
  static Route<void> buildRoute({
    String initialKeyword = '',
    Set<int> initialTagIds = const <int>{},
    DiaryListScope scope = DiaryListScope.all,
    String? scopeLabel,
    FaIconData? scopeIcon,
  }) {
    // 不透明路由：转场期间下层仍会绘制，完成后下层转为 offstage，不再在
    // 搜索期间持续绘制整屏日记列表（并暂停其 ticker）。
    return PageRouteBuilder<void>(
      transitionDuration: ExpressiveMotion.standard,
      reverseTransitionDuration: ExpressiveMotion.medium,
      pageBuilder: (context, animation, secondaryAnimation) {
        return DiarySearchPage(
          initialKeyword: initialKeyword,
          initialTagIds: initialTagIds,
          scope: scope,
          scopeLabel: scopeLabel,
          scopeIcon: scopeIcon,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (ExpressiveMotion.reduceMotion(context)) {
          return child;
        }
        final easedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubicEmphasized,
          reverseCurve: Curves.easeInOutCubic,
        );
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(easedAnimation);
        final scaleAnimation = Tween<double>(
          begin: 0.992,
          end: 1,
        ).animate(easedAnimation);
        return FadeTransition(
          opacity: easedAnimation,
          child: SlideTransition(
            position: offsetAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<DiarySearchPage> createState() => _DiarySearchPageState();
}

class _DiarySearchPageState extends ConsumerState<DiarySearchPage> {
  static const double _loadMoreTriggerExtent = 420;

  late final DiarySearchController _session = DiarySearchController(
    initialKeyword: widget.initialKeyword,
    initialTagIds: widget.initialTagIds,
    scope: widget.scope,
  );
  final FocusNode _searchFocusNode = FocusNode();
  final RouteEntranceWaiter _routeEntranceWaiter = RouteEntranceWaiter();

  // 首次聚焦推迟到路由转场结束：转场途中弹出键盘会让 viewInsets 逐帧变化，
  // 页面在动画期间被反复重新布局。
  bool _searchAutofocusEnabled = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _routeEntranceWaiter.schedule(this, _enableSearchAutofocus);
  }

  void _enableSearchAutofocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _searchAutofocusEnabled = true);
      _searchFocusNode.requestFocus();
    });
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _routeEntranceWaiter.dispose();
    _session
      ..removeListener(_onSessionChanged)
      ..dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final preferences = ref.watch(diarySearchPreferencesProvider);
    final notebooksEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.notebooks),
    );
    final pageQuery = session.pageQuery(
      sortMode: preferences.sort.mode,
      // 开启留言功能时关键词也搜留言（只在搜索页）。
      matchComments: ref.watch(diaryCommentsEnabledProvider),
    );
    final hasCondition = session.hasAnyCondition;
    final diariesAsync = hasCondition
        ? ref.watch(searchDiariesProvider(pageQuery))
        : null;
    if (diariesAsync?.asData?.value case final page?) {
      session.acceptPage(page, pageQuery);
    }
    if (hasCondition) {
      final count = ref.watch(searchDiaryCountProvider(pageQuery.timelineKey));
      if (count.asData?.value case final value?) {
        session.acceptCount(value);
      }
    }
    final tagList = ref.watch(tagListProvider).value;
    final selectedTags = _selectedTags(tagList);
    // 用 viewPadding：padding 的底边在键盘盖过导航条的那几帧里逐帧变小，
    // 读 padding（哪怕只取顶边）会让整页（连同结果卡片）跟着逐帧重建。
    final topSafeInset = MediaQuery.viewPaddingOf(context).top;
    final scopeLabel = session.scope != DiaryListScope.all
        ? widget.scopeLabel
        : null;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        primaryShortcut(LogicalKeyboardKey.keyF): _focusSearchField,
      },
      child: AppPageBackground(
        area: AppBackgroundArea.other,
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            body: Column(
              children: <Widget>[
                // 实色顶栏：纯色背景时与页面同色，图片背景时不透明。
                ColoredBox(
                  color: AppPageBackdrop.solidBarColorOf(context),
                  child: Padding(
                    padding: EdgeInsets.only(top: topSafeInset),
                    child: DiarySearchTopBar(
                      session: session,
                      focusNode: _searchFocusNode,
                      autofocus: _searchAutofocusEnabled,
                      selectedTags: selectedTags,
                      scopeLabel: scopeLabel,
                      scopeIcon: widget.scopeIcon ?? FontAwesomeIcons.book,
                      onClose: _closePage,
                      onSubmitted: _submitSearch,
                      onPickTags: () =>
                          unawaited(pickDiarySearchTags(context, session)),
                      onPickFilter: (slot) => unawaited(
                        pickDiarySearchFilter(context, session, slot),
                      ),
                      onSaveAsNotebook: notebooksEnabled
                          ? _saveAsNotebookAction(tagList)
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: ColoredBox(
                      color: AppPageBackdrop.pageColorOf(context),
                      // 空状态与结果之间交叉淡入，输入第一个字 / 清空时不硬切。
                      child: AnimatedSwitcher(
                        duration: ExpressiveMotion.duration(
                          context,
                          ExpressiveMotion.fast,
                        ),
                        switchInCurve: ExpressiveMotion.effects,
                        switchOutCurve: ExpressiveMotion.exit,
                        child: hasCondition
                            ? KeyedSubtree(
                                key: const ValueKey<String>('search_results'),
                                child: _buildResults(
                                  diariesAsync!,
                                  preferences.sort,
                                ),
                              )
                            : KeyedSubtree(
                                key: const ValueKey<String>(
                                  'search_suggestions',
                                ),
                                child: _buildSuggestions(selectedTags),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 没有条件时：最近搜索与常用标签（排除已选为条件的标签）。
  Widget _buildSuggestions(List<Tag> selectedTags) {
    final recent = ref.watch(
      diarySearchPreferencesProvider.select((value) => value.recent),
    );
    final selectedIds = <int>{for (final tag in selectedTags) tag.id};
    final tags = <Tag>[
      for (final tag in ref.watch(searchTagSuggestionsProvider(_session.scope)))
        if (!selectedIds.contains(tag.id)) tag,
    ];
    final preferences = ref.read(diarySearchPreferencesProvider.notifier);
    return WidthLayoutBuilder(
      builder: (BuildContext context, double maxWidth) =>
          DiarySearchSuggestions(
            recent: recent,
            tags: tags,
            horizontalPadding: FormWidth.gutter(maxWidth),
            onTapRecent: (query) {
              _session.applyKeyword(query);
              preferences.remember(query);
            },
            onRemoveRecent: preferences.forget,
            onClearRecent: preferences.clearRecent,
            onTapTag: (tag) => _session.addTag(tag.id),
          ),
    );
  }

  /// 有条件时：结果数与排序 + 结果卡片（新查询加载中继续显示上一份结果，
  /// 避免输入停顿后整屏闪白）+ 触底加载。
  Widget _buildResults(
    AsyncValue<PagedDiariesResult> diariesAsync,
    DiarySearchSort sort,
  ) {
    final session = _session;
    final displayed = diariesAsync.asData?.value.items ?? session.cachedItems;
    final terms = session.terms;
    final diaryCardTagLimit =
        ref.watch(diaryCardTagLimitProvider).asData?.value ??
        SettingsService.defaultDiaryCardTagLimit;
    // 只命中留言的结果在卡片下方附上命中的那条（功能关闭时为空表）。
    final commentHits =
        ref.watch(diaryCommentHitsProvider(session.keyword)).value ??
        const <String, DiaryCommentRow>{};
    // 在页面 build 里订阅，不放进下面只随宽度重建的布局回调。
    final cardStyle = ref.watch(diaryCardStyleProvider);
    final moodPalette = ref.watch(diaryMoodPaletteProvider);
    final commentCounts =
        ref.watch(diaryCommentCountsProvider).value ?? const <String, int>{};
    final menuActions = _menuActions();
    final errorText = diariesAsync.hasError
        ? context.l10n.autoT0127(diariesAsync.asError?.error.toString() ?? '')
        : null;
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      // 只按宽度构建：键盘升降时 body 逐帧变矮，普通 LayoutBuilder 会逐帧
      // 重建整列结果卡片（见 WidthLayoutBuilder）。
      child: WidthLayoutBuilder(
        builder: (BuildContext context, double maxWidth) {
          final side = FormWidth.extra(
            maxWidth,
            childInset: cardStyle.list.sideMargin,
          );
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  side + cardStyle.list.sideMargin,
                  2,
                  side + cardStyle.list.sideMargin - 4,
                  4,
                ),
                sliver: SliverToBoxAdapter(
                  child: DiarySearchResultsHeader(
                    count: session.cachedCount,
                    sort: sort,
                    onSortChanged: ref
                        .read(diarySearchPreferencesProvider.notifier)
                        .setSort,
                  ),
                ),
              ),
              if (diariesAsync.isLoading && displayed.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: DelayedLoadingIndicator(size: 22),
                )
              else if (errorText != null && displayed.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(errorText)),
                )
              else
                // 宽窗口：结果卡片列最宽 720 并居中（卡片自带左右边距
                // sideMargin，这里只补其余留白；手机上为 0）。
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  sliver: SliverMainAxisGroup(
                    slivers: <Widget>[
                      DiariesListSection(
                        // 卡片样式按这一列实际的宽度解析。
                        availableWidth: maxWidth - side * 2,
                        diaries: displayed,
                        commentCounts: commentCounts,
                        highlightTerms: terms,
                        belowCardBuilder: (BuildContext context, diary) =>
                            _commentHit(commentHits, diary, session.keyword),
                        layoutMode: DiaryLayoutMode.list,
                        selectedDiaryIds: const <String>{},
                        isSelectionMode: false,
                        maxVisibleTags: diaryCardTagLimit,
                        cardStyle: cardStyle,
                        moodPalette: moodPalette,
                        onCreate: () {},
                        onOpenEditor: (diary, coverHero) =>
                            unawaited(_openPreview(diary, coverHero)),
                        onToggleSelection: (_, __) {},
                        isSearchResultEmpty: true,
                        emptyState: _NoResults(
                          onClearFilters: session.filters.isActive
                              ? session.clearFilters
                              : null,
                        ),
                        menuActions: menuActions,
                      ),
                      // 还有下一页时保留固定高度的槽位，指示器只在查询真正
                      // 进行且超过 300ms 时出现：输入关键词触发的本地查询
                      // 通常几毫秒即返回，常驻的循环指示器则会持续出帧。
                      SliverToBoxAdapter(
                        child: session.hasMore || diariesAsync.isLoading
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: SizedBox(
                                  height: 18,
                                  child: diariesAsync.isLoading
                                      ? const DelayedLoadingIndicator(size: 18)
                                      : null,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (errorText != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.l,
                              8,
                              AppSpacing.l,
                              0,
                            ),
                            child: Text(errorText),
                          ),
                        ),
                    ],
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  /// 已选为条件的标签，按标签列表的顺序；列表还没到时按 id 给出占位名。
  List<Tag> _selectedTags(List<Tag>? tags) {
    final ids = _session.tagIds;
    if (tags != null) {
      return <Tag>[
        for (final tag in tags)
          if (ids.contains(tag.id)) tag,
      ];
    }
    final colorScheme = Theme.of(context).colorScheme;
    return <Tag>[
      for (final id in ids.toList()..sort())
        Tag(
          id: id,
          name: context.l10n.autoT0126(id.toString()),
          color: colorScheme.primary.toARGB32(),
        ),
    ];
  }

  /// 键盘“搜索”：立即生效、记进最近搜索，并收起键盘看结果。
  void _submitSearch() {
    _session.commitInput();
    ref.read(diarySearchPreferencesProvider.notifier).remember(_session.input);
    _searchFocusNode.unfocus();
  }

  /// Ctrl / ⌘ + F：回到输入框并全选，方便直接换一个词。
  void _focusSearchField() {
    _searchFocusNode.requestFocus();
    final text = _session.text;
    text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.text.length,
    );
  }

  /// “存为智能日记本”：有关键词、标签或筛选规则时可用，规则见
  /// [runSaveSearchAsSmartNotebook]。标签列表尚未加载时不可用（拿不到标签
  /// 名）。日记本范围与“含归档”不进规则：智能日记本没有这两种口径。
  VoidCallback? _saveAsNotebookAction(List<Tag>? tags) {
    final session = _session;
    if (tags == null || !session.hasAnyCondition) {
      return null;
    }
    final tagNames = <String>[
      for (final tag in tags)
        if (session.tagIds.contains(tag.id)) tag.name,
    ];
    return () => unawaited(
      runSaveSearchAsSmartNotebook(
        context,
        keyword: session.keyword,
        tagNames: tagNames,
        filterRules: session.filters.rules,
      ),
    );
  }

  void _closePage() {
    Navigator.of(context).maybePop();
  }

  /// 只命中留言的结果下方那条命中的留言；标题与正文已含全部词时不加。
  Widget? _commentHit(
    Map<String, DiaryCommentRow> hits,
    DiaryWithTags diary,
    String keyword,
  ) {
    final hit = hits[diary.diary.diaryId];
    if (hit == null ||
        !DiarySearchCommentHit.matchesOnlyComment(
          title: diary.diary.title,
          contentText: diary.diary.contentText,
          keyword: keyword,
        )) {
      return null;
    }
    return DiarySearchCommentHit(content: hit.content, keyword: keyword);
  }

  /// 打开预览页（“打开日记时直接编辑”开启时为编辑页，见 [openDiaryPage]）：
  /// 只在当前结果里左右翻，结果还有没加载的部分时按同一条件接上。打开前把
  /// 关键词记进最近搜索；在里面删除了某一篇时给出撤销。
  Future<void> _openPreview(
    DiaryWithTags diary,
    ImageViewerHero? coverHero,
  ) async {
    final session = _session;
    if (session.keyword.isNotEmpty) {
      ref
          .read(diarySearchPreferencesProvider.notifier)
          .remember(session.keyword);
    }
    final query = session.cachedQuery;
    final sequence = DiaryPreviewSequence.fromItems(
      session.cachedItems,
      query: session.hasMore && query != null
          ? DiaryPreviewListQuery(
              keyword: query.keyword,
              requiredTagIds: query.requiredTagIds,
              sortMode: query.sortMode,
              scope: query.scope,
              matchComments: query.matchComments,
              includeArchived: query.includeArchived,
              filter: query.filter,
            )
          : null,
    );
    final result = await openDiaryPage(
      context,
      ref,
      diaryId: diary.diary.diaryId,
      initialDetail: diary,
      coverHero: coverHero,
      sequence: sequence,
    );
    if (result != null && mounted) {
      await offerDeletedDiaryUndo(context, ref, result.diaryId);
    }
  }

  /// 桌面右键菜单：搜索结果没有收起动画，写入后由结果查询自己刷新（归档的
  /// 日记也可能在结果里，按这篇的状态给“归档 / 取消归档”）。
  DiaryCardMenuActions _menuActions() {
    final notebooksEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.notebooks),
    );
    return DiaryCardMenuActions(
      onEdit: (diary) =>
          unawaited(editDiaryFromList(context, ref, diary.diary.diaryId)),
      onTogglePin: (diary) => unawaited(
        setDiaryPinned(
          context,
          ref,
          diary.diary.diaryId,
          pinned: !diary.diary.isPinned,
        ),
      ),
      onNotebooks: notebooksEnabled
          ? (diary) => unawaited(
              pickNotebooksForDiary(context, ref, diaryId: diary.diary.diaryId),
            )
          : null,
      onToggleArchive: (diary) => unawaited(
        setDiaryArchivedWithUndo(
          context,
          ref,
          diary.diary.diaryId,
          archived: !diary.diary.isArchived,
        ),
      ),
      onDelete: (diary) =>
          unawaited(deleteDiaryWithUndo(context, ref, diary.diary.diaryId)),
    );
  }

  /// 滚动接近底部时追加下一批结果。
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.metrics.extentAfter < _loadMoreTriggerExtent) {
      _session.requestLoadMore();
    }
    return false;
  }
}

/// 没有结果：沿用列表的搜索空态；有筛选时下面多一个“清除筛选”。
class _NoResults extends StatelessWidget {
  const _NoResults({required this.onClearFilters});

  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DiariesEmptyState(onCreate: () {}, isSearchResultEmpty: true),
        if (onClearFilters case final clear?)
          TextButton(
            key: const ValueKey<String>('search_clear_filters'),
            onPressed: clear,
            child: Text(context.l10n.diarySearchClearFilters),
          ),
      ],
    );
  }
}
