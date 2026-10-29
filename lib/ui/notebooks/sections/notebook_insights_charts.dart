import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../explore/models/explore_view_data.dart';
import '../../explore/widgets/charts/explore_column_chart.dart';
import '../../explore/widgets/charts/explore_reveal.dart';
import '../../explore/widgets/charts/explore_share_bars.dart';
import '../../explore/widgets/explore_shared_widgets.dart';
import '../../explore/widgets/explore_tag_capsule.dart';
import '../viewmodels/notebook_insights_data.dart';

/// 统计页的图表区块：心情分布、常用标签、写作节奏。
///
/// 配色只用 `primary` 的不透明度档位与表面色（DESIGN §5.7，无渐变）；条与柱
/// 首次出现时按探索页的节奏错峰生长（[ExploreReveal]，long），之后数据变化
/// 直接落位。条、柱与标签胶囊都是探索页的共用组件，两处外观一致。

/// 心情分布：每种用过的心情一行横条，按次数从多到少；条的长度按次数相对最多
/// 的那种，颜色按占比取 `primary` 的四档不透明度（与日历年视图热力同一组
/// 档位），右侧写次数与百分比。
class NotebookInsightsMoodCard extends StatelessWidget {
  const NotebookInsightsMoodCard({super.key, required this.moods});

  final List<NotebookMoodShare> moods;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExploreCard(
      child: ExploreReveal(
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreSectionTitle(
              icon: FontAwesomeIcons.faceSmile,
              title: l10n.notebookInsightsMoods,
            ),
            const SizedBox(height: AppSpacing.m),
            ExploreShareBars(
              reveal: reveal,
              rows: <ExploreShareRow>[
                for (final mood in moods)
                  ExploreShareRow(
                    leading: Text(
                      mood.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                    count: mood.count,
                    share: mood.share,
                    trailing: l10n.notebookInsightsMoodShare(
                      mood.count,
                      mood.percent,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 常用标签：次数最多的几个标签的微胶囊（DESIGN §5.2：`# ` 前缀、标签色淡底、
/// 无描边无阴影），胶囊里写次数；给了 [onOpenTag] 时点按胶囊交给它（统计页：
/// 在这本里按这个标签搜索）。
class NotebookInsightsTagsCard extends StatelessWidget {
  const NotebookInsightsTagsCard({
    super.key,
    required this.tags,
    this.onOpenTag,
  });

  final List<ExploreTagUsage> tags;

  /// 点按某个标签，参数为标签 id；null 时胶囊不可点。
  final ValueChanged<int>? onOpenTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreSectionTitle(
            icon: FontAwesomeIcons.tags,
            title: l10n.notebookInsightsTopTags,
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final tag in tags)
                ExploreTagCapsule(
                  name: tag.name,
                  color: tag.color,
                  count: tag.count,
                  onTap: onOpenTag == null ? null : () => onOpenTag!(tag.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 写作节奏：最近 12 个月（第一篇更晚时从第一篇所在月起）每月篇数的柱状图，
/// `primary` 柱、柱顶写篇数、柱下写月份；1 月的柱下写年份，跨年时看得出
/// 分界。窄屏（320dp）下 12 根柱每根约 20dp，文字经 [FittedBox] 缩小不换行。
class NotebookInsightsRhythmCard extends StatelessWidget {
  const NotebookInsightsRhythmCard({super.key, required this.months});

  final List<NotebookMonthCount> months;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final monthFormat = DateFormat.MMM(l10n.localeName);
    final yearMonthFormat = DateFormat.yMMM(l10n.localeName);
    return ExploreCard(
      child: ExploreReveal(
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreSectionTitle(
              icon: FontAwesomeIcons.chartColumn,
              title: l10n.notebookInsightsRhythm,
            ),
            const SizedBox(height: AppSpacing.m),
            ExploreColumnChart(
              reveal: reveal,
              semanticsLabel: <String>[
                for (final m in months)
                  l10n.notebookInsightsRhythmBar(
                    yearMonthFormat.format(m.month),
                    m.count,
                  ),
              ].join(', '),
              columns: <ExploreColumn>[
                for (var i = 0; i < months.length; i++)
                  ExploreColumn(
                    value: months[i].count,
                    label: monthFormat.format(months[i].month),
                    sublabel: i == 0 || months[i].month.month == 1
                        ? '${months[i].month.year}'
                        : '',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
