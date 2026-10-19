import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../explore/models/explore_view_data.dart';
import '../../explore/sections/explore_insight_card.dart';
import '../../explore/widgets/explore_shared_widgets.dart';
import '../viewmodels/notebook_insights_data.dart';

/// 统计页的图表区块：心情分布、常用标签、写作节奏。
///
/// 配色只用 `primary` 的不透明度档位与表面色（DESIGN §5.7，无渐变）；条与柱
/// 首次出现时按探索页的节奏错峰生长（[ExploreInsightCard.staggered]，long），
/// 之后数据变化直接落位；生长期间以 [RepaintBoundary] 隔离重绘。

/// 首次构建时从 0 走到 1 的共享进度（减少动画时直接为 1）。
class _Reveal extends StatelessWidget {
  const _Reveal({required this.builder});

  final Widget Function(BuildContext context, double reveal) builder;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.long),
        builder: (BuildContext context, double reveal, Widget? _) =>
            builder(context, reveal),
      ),
    );
  }
}

/// 条形 / 柱形的空轨道色（与探索页能量柱的底一致）。
Color _trackColor(ColorScheme scheme) =>
    scheme.surfaceContainerHighest.withValues(alpha: 0.45);

/// 心情分布：每种用过的心情一行横条，按次数从多到少；条的长度按次数相对最多
/// 的那种，颜色按占比取 `primary` 的四档不透明度（与日历年视图热力同一组
/// 档位），右侧写次数与百分比。
class NotebookInsightsMoodCard extends StatelessWidget {
  const NotebookInsightsMoodCard({super.key, required this.moods});

  final List<NotebookMoodShare> moods;

  /// 占比 → 不透明度档位：<15% / <30% / <50% / 其余。
  static double alphaForShare(double share) {
    if (share < 0.15) return 0.3;
    if (share < 0.3) return 0.5;
    if (share < 0.5) return 0.72;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxCount = moods.isEmpty ? 1 : moods.first.count;
    return ExploreCard(
      child: _Reveal(
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreSectionTitle(
              icon: FontAwesomeIcons.faceSmile,
              title: l10n.notebookInsightsMoods,
            ),
            const SizedBox(height: AppSpacing.m),
            for (var i = 0; i < moods.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 28,
                      child: Text(
                        moods[i].emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    Expanded(
                      child: _Bar(
                        fraction:
                            moods[i].count /
                            maxCount *
                            ExploreInsightCard.staggered(
                              reveal,
                              i,
                              moods.length,
                            ),
                        color: scheme.primary.withValues(
                          alpha: alphaForShare(moods[i].share),
                        ),
                        track: _trackColor(scheme),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    SizedBox(
                      width: 72,
                      child: Text(
                        l10n.notebookInsightsMoodShare(
                          moods[i].count,
                          moods[i].percent,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 横条：圆角轨道里按 [fraction] 填充。
class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(6);
    return Container(
      height: 12,
      decoration: BoxDecoration(color: track, borderRadius: radius),
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0.0, 1.0),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: radius),
        ),
      ),
    );
  }
}

/// 常用标签：次数最多的几个标签的微胶囊（DESIGN §5.2：`# ` 前缀、标签色淡底、
/// 无描边无阴影），胶囊里写次数。
class NotebookInsightsTagsCard extends StatelessWidget {
  const NotebookInsightsTagsCard({super.key, required this.tags});

  final List<ExploreTagUsage> tags;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
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
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(
                      tag.color,
                    ).withValues(alpha: isLight ? 0.12 : 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '# ',
                            style: TextStyle(
                              color: Color(tag.color),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(text: tag.name),
                          TextSpan(
                            text: '  ${tag.count}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
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

  static const double _chartHeight = 72;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxCount = months.fold<int>(
      1,
      (int max, NotebookMonthCount m) => m.count > max ? m.count : max,
    );
    final monthFormat = DateFormat.MMM(l10n.localeName);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      color: scheme.onSurfaceVariant,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    Widget smallText(String text, TextStyle? style) => SizedBox(
      height: 14,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, style: style),
      ),
    );
    return ExploreCard(
      child: _Reveal(
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreSectionTitle(
              icon: FontAwesomeIcons.chartColumn,
              title: l10n.notebookInsightsRhythm,
            ),
            const SizedBox(height: AppSpacing.m),
            Semantics(
              label: <String>[
                for (final m in months)
                  l10n.notebookInsightsRhythmBar(
                    DateFormat.yMMM(l10n.localeName).format(m.month),
                    m.count,
                  ),
              ].join(', '),
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (var i = 0; i < months.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            children: <Widget>[
                              smallText(
                                months[i].count > 0 ? '${months[i].count}' : '',
                                labelStyle?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                height: _chartHeight,
                                alignment: Alignment.bottomCenter,
                                decoration: BoxDecoration(
                                  color: _trackColor(scheme),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: months[i].count == 0
                                    ? null
                                    : Container(
                                        // 有篇数的月份至少露出 6dp，看得出来。
                                        height:
                                            (6 +
                                                (_chartHeight - 6) *
                                                    months[i].count /
                                                    maxCount) *
                                            ExploreInsightCard.staggered(
                                              reveal,
                                              i,
                                              months.length,
                                            ),
                                        decoration: BoxDecoration(
                                          color: scheme.primary,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 4),
                              smallText(
                                monthFormat.format(months[i].month),
                                labelStyle,
                              ),
                              smallText(
                                i == 0 || months[i].month.month == 1
                                    ? '${months[i].month.year}'
                                    : '',
                                labelStyle,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
