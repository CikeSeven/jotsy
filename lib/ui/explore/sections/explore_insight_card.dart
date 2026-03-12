import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../widgets/explore_shared_widgets.dart';

/// 情绪与精力趋势卡片。
class ExploreInsightCard extends StatelessWidget {
  const ExploreInsightCard({
    super.key,
    required this.moodWeights30,
    required this.energyValues7,
  });

  final List<double?> moodWeights30;
  final List<double?> energyValues7;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ExploreSectionTitle(
            icon: FontAwesomeIcons.chartSimple,
            title: '情绪与精力趋势',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                moodWeights30.map((value) {
                  return Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _moodColor(value, colorScheme),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }).toList(growable: false),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children:
                energyValues7.map((value) {
                  final height =
                      value == null
                          ? 8.0
                          : 8 + ((value.clamp(1, 5) - 1) / 4) * 34;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        height: height,
                        decoration: BoxDecoration(
                          color:
                              value == null
                                  ? colorScheme.surfaceContainerHighest.withValues(
                                    alpha: 0.7,
                                  )
                                  : colorScheme.primary.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
          ),
          const SizedBox(height: 8),
          Text(
            '继续记录天气、标签和心情后，这里会出现更具体的关联洞察。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Color _moodColor(double? value, ColorScheme colorScheme) {
    if (value == null) {
      return colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    }
    if (value <= 1.8) {
      return const Color(0xFFE57373);
    }
    if (value <= 2.8) {
      return const Color(0xFFFFB74D);
    }
    if (value <= 3.6) {
      return const Color(0xFFFFF176);
    }
    if (value <= 4.4) {
      return const Color(0xFF81C784);
    }
    return const Color(0xFF4CAF50);
  }
}
