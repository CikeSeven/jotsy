import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/controllers/diary_open_flow.dart';
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
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_page_title.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 日记本统计页（首页头部卡片“统计”，普通与智能日记本都有）。
///
/// 自上而下：写作目标（设了目标时）、总览、心情分布（有心情时）、常用标签
/// （有标签时）、写作节奏、那年今日（有时）、“随机翻一篇”。
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
    final scope = notebookStatsScope(
      notebook,
      tree: ref.watch(notebookTreeProvider),
    );
    final diaries = ref.watch(notebookInsightsOverviewsProvider(scope)).value;
    final photoCount = ref.watch(notebookPhotoCountProvider(scope)).value ?? 0;
    final goal = watchNotebookGoalProgress(context, ref, notebook);
    // 普通日记本按成书顺序翻（目录页同一条查询）；智能日记本按发表时间新→旧。
    final bookOrder = notebook.isManual
        ? ref.watch(notebookContentsProvider(notebook.id)).value
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
                NotebookInsightsTagsCard(tags: data.topTags),
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

  /// 随机打开一篇，左右翻页的顺序为整本（见 [notebookInsightsRandomOrder]）。
  void _openRandom(
    NotebookView notebook,
    List<ExploreDiaryOverview> diaries,
    List<NotebookContentsEntry>? bookOrder,
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

/// “随机翻一篇”的候选与翻页顺序：只取统计口径里的日记（[diaries]：不含
/// 未解封的胶囊与回收站），普通日记本按成书顺序（[bookOrder]，目录页的
/// 查询），智能日记本（[bookOrder] 为 null）按发表时间新 → 旧。
List<String> notebookInsightsRandomOrder(
  List<ExploreDiaryOverview> diaries, {
  List<NotebookContentsEntry>? bookOrder,
}) {
  final visible = <String>{for (final diary in diaries) diary.diaryId};
  if (bookOrder != null) {
    return <String>[
      for (final entry in bookOrder)
        if (visible.contains(entry.diaryId)) entry.diaryId,
    ];
  }
  final sorted = <ExploreDiaryOverview>[...diaries]
    ..sort((a, b) {
      final byCreated = b.createdAt.compareTo(a.createdAt);
      return byCreated != 0 ? byCreated : b.diaryId.compareTo(a.diaryId);
    });
  return <String>[for (final diary in sorted) diary.diaryId];
}
