import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/explore_module_config.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../viewmodels/explore_labels.dart';
import '../widgets/charts/explore_bar.dart';
import '../widgets/charts/explore_reveal.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_shared_widgets.dart';

/// 里程碑：每一类一行，写当前值、向下一档的进度条与“下一站 … 还差 …”；
/// 开了“含已达成”时在类名旁写已达成的个数。
class ExploreMilestonesCard extends StatelessWidget {
  const ExploreMilestonesCard({
    super.key,
    required this.config,
    required this.milestones,
  });

  final ExploreModuleConfig config;
  final List<ExploreMilestone> milestones;

  static FaIconData _iconOf(ExploreMilestoneKind kind) => switch (kind) {
    ExploreMilestoneKind.entries => FontAwesomeIcons.bookOpen,
    ExploreMilestoneKind.words => FontAwesomeIcons.penNib,
    ExploreMilestoneKind.streak => FontAwesomeIcons.fire,
    ExploreMilestoneKind.days => FontAwesomeIcons.calendarCheck,
    ExploreMilestoneKind.years => FontAwesomeIcons.seedling,
  };

  static String formatValue(
    AppLocalizations l10n,
    ExploreMilestoneKind kind,
    int value,
    String Function(int value) number,
  ) => switch (kind) {
    ExploreMilestoneKind.entries => l10n.exploreUnitEntries(value),
    ExploreMilestoneKind.words => l10n.exploreUnitWords(number(value)),
    ExploreMilestoneKind.streak ||
    ExploreMilestoneKind.days => l10n.notebookInsightsDays(value),
    ExploreMilestoneKind.years => l10n.exploreUnitYears(value),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final showAchieved = config.toggle(ExploreOptions.milestoneAchieved);
    String number(int value) => look.formatNumber(value, l10n.localeName);
    return ExploreCard(
      child: ExploreReveal(
        enabled: look.animations,
        builder: (BuildContext context, double reveal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreCardHeader(
              icon: FontAwesomeIcons.trophy,
              title: l10n.exploreModuleMilestones,
            ),
            for (var i = 0; i < milestones.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 14),
              _row(
                context,
                milestones[i],
                theme: theme,
                scheme: scheme,
                accent: look.accentOf(scheme),
                showAchieved: showAchieved,
                number: number,
                grow: ExploreReveal.staggered(reveal, i, milestones.length),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ExploreMilestone milestone, {
    required ThemeData theme,
    required ColorScheme scheme,
    required Color accent,
    required bool showAchieved,
    required String Function(int value) number,
    required double grow,
  }) {
    final l10n = context.l10n;
    final kind = milestone.kind;
    final next = milestone.next;
    final caption = next == null
        ? l10n.exploreMilestoneAllDone
        : l10n.exploreMilestoneNext(
            formatValue(l10n, kind, next, number),
            formatValue(l10n, kind, next - milestone.value, number),
          );
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            FaIcon(_iconOf(kind), size: 12, color: accent),
            const SizedBox(width: 8),
            Text(
              ExploreLabels.milestone(l10n, kind),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showAchieved && milestone.achievedCount > 0) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                l10n.exploreMilestoneAchieved(milestone.achievedCount),
                style: metaStyle,
              ),
            ],
            const Spacer(),
            Text(
              formatValue(l10n, kind, milestone.value, number),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ExploreBar(
          fraction: milestone.progress * grow,
          color: accent,
          track: ExploreChartColors.track(scheme),
          height: 8,
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: metaStyle,
        ),
      ],
    );
  }
}
