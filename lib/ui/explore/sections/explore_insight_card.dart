import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

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
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreSectionTitle(
            icon: FontAwesomeIcons.chartSimple,
            title: l10n.autoT0060,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: moodWeights30
                .map((value) {
                  return Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: _moodColor(value, colorScheme, isDark),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: energyValues7
                .map((value) {
                  final activeHeight = value == null
                      ? 0.0
                      : (8 + ((value.clamp(1, 5) - 1) / 4) * 36).clamp(
                          8.0,
                          44.0,
                        );
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        height: 44,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: value == null
                            ? const SizedBox.shrink()
                            : Container(
                                height: activeHeight,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.circleInfo,
                size: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.autoT0198,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _moodColor(double? value, ColorScheme colorScheme, bool isDark) {
    if (value == null) {
      return colorScheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.35 : 0.6,
      );
    }
    if (value <= 1.8) {
      return isDark ? const Color(0xFFEF5350) : const Color(0xFFE57373);
    }
    if (value <= 2.8) {
      return isDark ? const Color(0xFFFFA726) : const Color(0xFFFFB74D);
    }
    if (value <= 3.6) {
      return isDark ? const Color(0xFFFFEE58) : const Color(0xFFFFF176);
    }
    if (value <= 4.4) {
      return isDark ? const Color(0xFF66BB6A) : const Color(0xFF81C784);
    }
    return isDark ? const Color(0xFF43A047) : const Color(0xFF4CAF50);
  }
}
