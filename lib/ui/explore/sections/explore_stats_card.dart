import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';

/// 顶部轻量数据看板。
class ExploreStatsCard extends StatelessWidget {
  const ExploreStatsCard({super.key, required this.stats});

  final ExploreStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return ExploreCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: ExploreStatTile(
              icon: FontAwesomeIcons.bookOpen,
              label: l10n.autoT0066,
              value: '${stats.totalRecords}',
            ),
          ),
          _buildDivider(colorScheme),
          Expanded(
            child: ExploreStatTile(
              icon: FontAwesomeIcons.fire,
              label: l10n.autoT0067,
              value: '${stats.streakDays}',
            ),
          ),
          _buildDivider(colorScheme),
          Expanded(
            child: ExploreStatTile(
              icon: FontAwesomeIcons.penNib,
              label: l10n.autoT0068,
              value: '${stats.currentMonthChars}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
    );
  }
}
