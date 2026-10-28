import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../widgets/charts/explore_reveal.dart';
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
    // 首次出现时心情格依次着色、能量柱从底部错峰长出，共用一个 0→1 进度（long）：
    // 只插值颜色与高度，不为 30 个格子各叠一层 Opacity。进度只在首次构建时播放，
    // 之后数据变化直接落位；减少动画时直接显示。整卡包 RepaintBoundary，生长
    // 期间只重绘本卡。
    return RepaintBoundary(
      child: ExploreCard(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.long),
          builder: (BuildContext context, double reveal, Widget? footer) {
            return Column(
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
                  children: <Widget>[
                    for (var index = 0; index < moodWeights30.length; index++)
                      Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            _moodColor(null, colorScheme, isDark),
                            _moodColor(
                              moodWeights30[index],
                              colorScheme,
                              isDark,
                            ),
                            staggered(reveal, index, moodWeights30.length),
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (var index = 0; index < energyValues7.length; index++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _buildEnergyBar(
                            colorScheme,
                            energyValues7[index],
                            staggered(reveal, index, energyValues7.length),
                          ),
                        ),
                      ),
                  ],
                ),
                footer!,
              ],
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
        ),
      ),
    );
  }

  /// 共享进度下第 [index] 项的局部进度，见 [ExploreReveal.staggered]。
  static double staggered(double reveal, int index, int count) =>
      ExploreReveal.staggered(reveal, index, count);

  Widget _buildEnergyBar(ColorScheme colorScheme, double? value, double grow) {
    final activeHeight = value == null
        ? 0.0
        : (8 + ((value.clamp(1, 5) - 1) / 4) * 36).clamp(8.0, 44.0);
    return Container(
      height: 44,
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: value == null
          ? const SizedBox.shrink()
          : Container(
              height: activeHeight * grow,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
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
