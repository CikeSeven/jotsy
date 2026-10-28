import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/explore_module_config.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../models/explore_period.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_shared_widgets.dart';
import '../widgets/explore_tag_capsule.dart';

/// 周期回顾：本周 / 本月 / 今年的篇数、字数与记录天数（可与上一期对比），
/// 以及最常见的心情与最常用的标签。
class ExploreRecapCard extends StatelessWidget {
  const ExploreRecapCard({super.key, required this.config, required this.data});

  final ExploreModuleConfig config;
  final ExploreRecapData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final compare = config.toggle(ExploreOptions.recapCompare);
    final current = data.current;
    final previous = data.previous;
    final title = switch (data.period) {
      ExplorePeriod.week => l10n.exploreRecapTitleWeek,
      ExplorePeriod.year => l10n.exploreRecapTitleYear,
      _ => l10n.exploreRecapTitleMonth,
    };
    final range = data.range;
    final last = DateTime(range.end.year, range.end.month, range.end.day - 1);
    final format = DateFormat.MMMd(l10n.localeName);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    Widget stat(String label, int value, int before, {String? display}) {
      final diff = value - before;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: metaStyle,
            ),
            const SizedBox(height: 4),
            Text(
              display ?? look.formatNumber(value, l10n.localeName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: look.accentOf(scheme),
                fontWeight: FontWeight.w800,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            if (compare) _Delta(diff: diff),
          ],
        ),
      );
    }

    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreCardHeader(
            icon: FontAwesomeIcons.calendarCheck,
            title: title,
            trailing: ExploreHeaderNote(
              '${format.format(range.start)} – ${format.format(last)}',
            ),
          ),
          if (current.entries == 0 && !compare)
            ExploreInlineHint(message: l10n.explorePeriodEmpty)
          else ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                stat(
                  l10n.exploreMetricEntries,
                  current.entries,
                  previous.entries,
                ),
                stat(l10n.exploreMetricWords, current.words, previous.words),
                stat(
                  l10n.exploreMetricRecordedDays,
                  current.days,
                  previous.days,
                ),
              ],
            ),
            if (current.topMood != null || current.topTag != null) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (current.topMood case final mood?)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(l10n.exploreRecapTopMood, style: metaStyle),
                        const SizedBox(width: 6),
                        Text(mood, style: const TextStyle(fontSize: 18)),
                      ],
                    ),
                  if (current.topTag case final tag?)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(l10n.exploreRecapTopTag, style: metaStyle),
                        const SizedBox(width: 6),
                        Flexible(
                          child: ExploreTagCapsule(
                            name: tag.name,
                            color: tag.color,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// 与上一期的差值：多为强调色向上箭头，少为弱化色向下箭头，相同为横线。
class _Delta extends StatelessWidget {
  const _Delta({required this.diff});

  final int diff;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final color = diff > 0 ? look.accentOf(scheme) : scheme.onSurfaceVariant;
    final icon = diff > 0
        ? FontAwesomeIcons.caretUp
        : diff < 0
        ? FontAwesomeIcons.caretDown
        : FontAwesomeIcons.minus;
    final semantics = diff > 0
        ? l10n.exploreRecapMore(diff)
        : diff < 0
        ? l10n.exploreRecapFewer(-diff)
        : l10n.exploreRecapSame;
    return Semantics(
      label: semantics,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FaIcon(icon, size: 11, color: color),
            if (diff != 0) ...<Widget>[
              const SizedBox(width: 3),
              Text(
                look.formatNumber(diff.abs(), l10n.localeName),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
