import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../explore/widgets/explore_shared_widgets.dart';
import '../viewmodels/notebook_goal_progress.dart';
import '../viewmodels/notebook_header_meta.dart';
import '../viewmodels/notebook_insights_data.dart';
import '../viewmodels/notebook_labels.dart';
import '../widgets/notebook_goal_row.dart';

/// 统计页总览：2 列 × 3 行的数字格（篇数、字数、记录天数、时间跨度、照片数、
/// 最长连续）。数字格复用探索页的 [ExploreStatTile]：首次出现从 0 递增
/// （long + effects，等宽数字），之后数据变化从当前值补间（DESIGN §4.3）。
class NotebookInsightsOverviewCard extends StatelessWidget {
  const NotebookInsightsOverviewCard({
    super.key,
    required this.data,
    required this.photoCount,
  });

  final NotebookInsightsData data;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = data.first;
    String days(int value) => l10n.notebookInsightsDays(value);
    final rows = <List<Widget>>[
      <Widget>[
        ExploreStatTile(
          icon: FontAwesomeIcons.bookOpen,
          label: l10n.notebookInsightsEntries,
          value: data.entryCount,
        ),
        ExploreStatTile(
          icon: FontAwesomeIcons.penNib,
          label: l10n.notebookInsightsWords,
          value: data.wordCount,
          format: (int value) => formatNotebookWords(value, l10n.localeName),
        ),
      ],
      <Widget>[
        ExploreStatTile(
          icon: FontAwesomeIcons.calendarCheck,
          label: l10n.notebookInsightsRecordedDays,
          value: data.recordedDays,
        ),
        ExploreStatTile(
          icon: FontAwesomeIcons.hourglassHalf,
          label: l10n.notebookInsightsSpan,
          value: data.spanDays,
          format: first == null
              ? days
              : (int value) => notebookSpanDurationLabel(l10n, first, value),
        ),
      ],
      <Widget>[
        ExploreStatTile(
          icon: FontAwesomeIcons.image,
          label: l10n.notebookInsightsPhotos,
          value: photoCount,
        ),
        ExploreStatTile(
          icon: FontAwesomeIcons.fire,
          label: l10n.notebookInsightsLongestStreak,
          value: data.longestStreak,
          format: days,
        ),
      ],
    ];
    // 数字递增期间只重绘本卡。
    return RepaintBoundary(
      child: ExploreCard(
        child: Column(
          children: <Widget>[
            for (var i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: AppSpacing.l),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: rows[i][0]),
                  const SizedBox(width: AppSpacing.l),
                  Expanded(child: rows[i][1]),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 统计页顶部的写作目标卡（只在设了目标时出现）：目标原话、当前周期进度与
/// 连续达成（与首页头部同一组件），以及最近 8 个周期的圆点（达成 `primary`，
/// 未达成 `outlineVariant`，最右为当前周期）。
class NotebookInsightsGoalCard extends StatelessWidget {
  const NotebookInsightsGoalCard({super.key, required this.progress});

  final NotebookGoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metCount = progress.recent.where((bool met) => met).length;
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreSectionTitle(
            icon: FontAwesomeIcons.bullseye,
            title: notebookGoalSummary(
              l10n,
              progress.goal.period,
              progress.target,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          NotebookGoalProgressView(progress: progress),
          const SizedBox(height: AppSpacing.m),
          Semantics(
            label: l10n.notebookInsightsGoalRecent(
              metCount,
              progress.recent.length,
            ),
            child: ExcludeSemantics(
              child: Row(
                children: <Widget>[
                  for (final met in progress.recent)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: AnimatedContainer(
                        duration: ExpressiveMotion.duration(
                          context,
                          ExpressiveMotion.fast,
                        ),
                        curve: ExpressiveMotion.effects,
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: met ? scheme.primary : scheme.outlineVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      l10n.notebookInsightsGoalRecentCaption(
                        progress.recent.length,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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
  }
}
