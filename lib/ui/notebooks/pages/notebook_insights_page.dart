import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/controllers/diary_open_flow.dart';
import '../../diaries/controllers/diary_tag_search_flow.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../explore/sections/explore_memory_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../models/notebook_scope_resolver.dart';
import '../providers/notebook_insights_providers.dart';
import '../providers/notebook_providers.dart';
import '../sections/notebook_insights_cards.dart';
import '../sections/notebook_insights_charts.dart';
import '../viewmodels/notebook_insights_data.dart';
import '../viewmodels/notebook_tree.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_page_title.dart';
import '../widgets/notebook_switcher_chip.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 日记本统计页（首页头部卡片“统计”，普通与智能日记本都有）。
///
/// 自上而下：写作目标（设了目标时）、总览、心情分布（有心情时）、常用标签
/// （有标签时，点按在这本里按标签搜索）、写作节奏、那年今日（有时）、“随机
/// 翻一篇”。
///
/// 数据口径：本子里含归档、不含已删除与未解封胶囊的日记（与探索页同一条
/// 概览查询换成日记本范围），聚合在 [NotebookInsightsData]；照片数单独查。
/// 页面只负责组合与导航；聚合结果按输入列表的身份与日期缓存，数据流没有
/// 新推送时重建不再重算。
class NotebookInsightsPage extends ConsumerStatefulWidget {
  const NotebookInsightsPage({
    super.key,
    required this.notebookId,
    this.random,
  });

  final String notebookId;

  /// “随机翻一篇”的随机源；测试注入固定种子。
  final Random? random;

  static Route<void> route({required String notebookId}) =>
      MaterialPageRoute<void>(
        builder: (_) => NotebookInsightsPage(notebookId: notebookId),
      );

  @override
  ConsumerState<NotebookInsightsPage> createState() =>
      _NotebookInsightsPageState();
}

class _NotebookInsightsPageState extends ConsumerState<NotebookInsightsPage> {
  late final Random _random = widget.random ?? Random();
  List<ExploreDiaryOverview>? _cachedSource;
  String? _cachedKey;
  NotebookInsightsData? _cached;

  NotebookInsightsData _resolve(
    List<ExploreDiaryOverview> diaries,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final key = '${l10n.localeName}|${now.year}-${now.month}-${now.day}';
    final cached = _cached;
    if (cached != null &&
        identical(diaries, _cachedSource) &&
        key == _cachedKey) {
      return cached;
    }
    _cachedSource = diaries;
    _cachedKey = key;
    return _cached = NotebookInsightsData.build(diaries, now: now, l10n: l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notebookAsync = ref.watch(notebookProvider(widget.notebookId));
    final notebook = notebookAsync.value;
    final Widget body;
    if (notebook == null) {
      body = notebookAsync.hasValue
          ? EmptyHint(
              icon: FontAwesomeIcons.book,
              message: l10n.notebookMissing,
            )
          : const DelayedLoadingIndicator();
    } else {
      body = _buildBody(context, notebook);
    }
    return AppPageBackground(
      area: AppBackgroundArea.other,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
            title: NotebookPageTitle(
              title: l10n.notebookInsights,
              subtitle: notebook?.name,
            ),
          ),
          body: body,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotebookView notebook) {
    final l10n = context.l10n;
    final tree = ref.watch(notebookTreeProvider);
    final scope = notebookStatsScope(notebook, tree: tree);
    final diaries = ref.watch(notebookInsightsOverviewsProvider(scope)).value;
    final photoCount = ref.watch(notebookPhotoCountProvider(scope)).value ?? 0;
    final goal = watchNotebookGoalProgress(context, ref, notebook);
    // 普通日记本按成书顺序翻（连同子本，见 [_watchBookOrder]）；智能日记本
    // 按发表时间新→旧。
    final bookOrder = notebook.isManual
        ? _watchBookOrder(notebook, tree)
        : null;
    if (diaries == null) return const DelayedLoadingIndicator();
    final data = _resolve(diaries, l10n);
    if (data.isEmpty && goal == null) {
      return EmptyHint(
        icon: FontAwesomeIcons.chartSimple,
        message: l10n.notebookInsightsEmpty,
      );
    }
    const gap = SizedBox(height: AppSpacing.m);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final side = FormWidth.gutter(constraints.maxWidth);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            side,
            AppSpacing.s,
            side,
            AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            if (goal != null) ...<Widget>[
              NotebookInsightsGoalCard(progress: goal),
              gap,
            ],
            if (data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                child: EmptyHint(
                  icon: FontAwesomeIcons.chartSimple,
                  message: l10n.notebookInsightsEmpty,
                ),
              )
            else ...<Widget>[
              NotebookInsightsOverviewCard(data: data, photoCount: photoCount),
              if (data.moods.isNotEmpty) ...<Widget>[
                gap,
                NotebookInsightsMoodCard(moods: data.moods),
              ],
              if (data.topTags.isNotEmpty) ...<Widget>[
                gap,
                NotebookInsightsTagsCard(
                  tags: data.topTags,
                  // 在这本里按标签搜（与统计同一范围，连同子本）；搜索页里
                  // 可移除日记本条件，改在全部日记中找。
                  onOpenTag: (int tagId) => unawaited(
                    openDiaryTagSearch(
                      context,
                      tagId,
                      scope: scope,
                      scopeLabel: NotebookSwitcherChip.labelFor(
                        context,
                        notebook,
                      ),
                      scopeIcon: notebook.icon.data,
                    ),
                  ),
                ),
              ],
              gap,
              NotebookInsightsRhythmCard(months: data.months),
              if (data.onThisDay.isNotEmpty) ...<Widget>[
                gap,
                ExploreMemoryCard(
                  items: data.onThisDay,
                  onOpenDiary: (String diaryId) => _openPreview(
                    diaryId,
                    <String>[for (final item in data.onThisDay) item.diaryId],
                  ),
                  // 只在有回忆时显示本卡，空态的“补写今天”不会出现。
                  onCreateToday: () {},
                ),
              ],
              const SizedBox(height: AppSpacing.l),
              FilledButton.tonalIcon(
                key: const ValueKey<String>('notebook_insights_random'),
                onPressed: () => _openRandom(notebook, diaries, bookOrder),
                style: AppGlassField.tonalButtonStyle(context),
                icon: const FaIcon(FontAwesomeIcons.shuffle, size: 14),
                label: Text(l10n.notebookInsightsRandom),
              ),
            ],
          ],
        );
      },
    );
  }

  /// 普通日记本连同子本的成书顺序（日记业务 id）：本子自己的目录在前，再按
  /// 树序接上各本汇总的手动子本的目录（与首页书序同一口径：一篇在好几本里
  /// 时按最靠前的那本排）。智能子本没有目录，它们的日记由
  /// [notebookInsightsRandomOrder] 排在最后。本子自己的目录还没读到时为 null；
  /// 某本子本还没读到时它的日记暂时同样排在最后。
  List<String>? _watchBookOrder(NotebookView notebook, NotebookTree? tree) {
    final own = ref.watch(notebookContentsProvider(notebook.id)).value;
    if (own == null) return null;
    final subs = <NotebookView>[
      if (tree != null)
        for (final sub in tree.aggregatedDescendantsOf(notebook.id))
          if (sub.isManual) sub,
    ];
    final seen = <String>{};
    return <String>[
      for (final entry in own)
        if (seen.add(entry.diaryId)) entry.diaryId,
      for (final sub in subs)
        for (final entry
            in ref.watch(notebookContentsProvider(sub.id)).value ??
                const <NotebookContentsEntry>[])
          if (seen.add(entry.diaryId)) entry.diaryId,
    ];
  }

  /// 随机打开一篇，左右翻页的顺序为整本（见 [notebookInsightsRandomOrder]）。
  void _openRandom(
    NotebookView notebook,
    List<ExploreDiaryOverview> diaries,
    List<String>? bookOrder,
  ) {
    final ids = notebookInsightsRandomOrder(diaries, bookOrder: bookOrder);
    if (ids.isEmpty) return;
    _openPreview(ids[_random.nextInt(ids.length)], ids);
  }

  /// 打开预览页（“打开日记时直接编辑”开启时为编辑页，见 [openDiaryPage]）。
  void _openPreview(String diaryId, List<String> ids) {
    unawaited(
      openDiaryPage(
        context,
        ref,
        diaryId: diaryId,
        sequence: DiaryPreviewSequence(ids: ids),
      ),
    );
  }
}

/// “随机翻一篇”的候选与翻页顺序：统计口径里的每一篇（[diaries]：连同汇总的
/// 子本，不含未解封的胶囊与回收站）都在其中，且只出现一次。
///
/// 普通日记本按成书顺序（[bookOrder]：本子与手动子本的目录，日记业务 id），
/// 目录里没有的（只因智能子本的规则而在、或那本子本的目录还没读到）接在后面；
/// 智能日记本（[bookOrder] 为 null）整本按发表时间新 → 旧。
List<String> notebookInsightsRandomOrder(
  List<ExploreDiaryOverview> diaries, {
  List<String>? bookOrder,
}) {
  final visible = <String>{for (final diary in diaries) diary.diaryId};
  final ordered = <String>[
    if (bookOrder != null)
      for (final id in bookOrder)
        if (visible.remove(id)) id,
  ];
  final rest =
      <ExploreDiaryOverview>[
        for (final diary in diaries)
          if (visible.remove(diary.diaryId)) diary,
      ]..sort((a, b) {
        final byCreated = b.createdAt.compareTo(a.createdAt);
        return byCreated != 0 ? byCreated : b.diaryId.compareTo(a.diaryId);
      });
  return <String>[...ordered, for (final diary in rest) diary.diaryId];
}
