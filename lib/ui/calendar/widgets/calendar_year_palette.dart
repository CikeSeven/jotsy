import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../widgets/mood_band_palette.dart';
import '../models/calendar_display_options.dart';
import '../viewmodels/calendar_day_summary.dart';

/// 年视图小格的配色。
///
/// 只取 colorScheme 语义色，按档位分色而不是渐变（DESIGN.md 禁用渐变）：
/// - 篇数/字数：primary 的四档不透明度，比月视图热力更实，8~12dp 的小格
///   在最浅一档也看得出来；
/// - 心情：十档心情合并成五段——低落用 error、偏低用 tertiary、平静用
///   outline、不错与开心用两档 primary；写了日记但没选心情用浅 secondary，
///   与“没写”的空格区分开。长按日期记下的“这天的心情”优先于当天日记的
///   平均心情（五档即五段），没写日记的日子也按它着色。
abstract final class CalendarYearPalette {
  static const List<double> _heatAlphas = <double>[0, 0.3, 0.5, 0.72, 1];

  /// 心情五段的代表档位（1~10 中每段的上沿），图例用它取对应 emoji。
  static const List<int> moodBandWeights = MoodBandPalette.bandWeights;

  static Color emptyColor(ColorScheme colorScheme) =>
      colorScheme.surfaceContainerHighest.withValues(
        alpha: colorScheme.brightness == Brightness.light ? 0.9 : 0.7,
      );

  static Color noMoodColor(ColorScheme colorScheme) =>
      colorScheme.secondary.withValues(alpha: 0.35);

  static Color heatColor(ColorScheme colorScheme, int level) => level <= 0
      ? emptyColor(colorScheme)
      : colorScheme.primary.withValues(alpha: _heatAlphas[level.clamp(1, 4)]);

  /// 心情第 [band] 段（0~4，由低到高）的颜色；与日记卡片的心情色同源。
  static Color moodBandColor(ColorScheme colorScheme, int band) =>
      MoodBandPalette.color(colorScheme, band);

  static Color pixelColor(
    ColorScheme colorScheme,
    CalendarDaySummary? summary,
    CalendarYearBasis basis, {
    DayMood? dayMood,
  }) {
    if (basis == CalendarYearBasis.mood && dayMood != null) {
      return moodBandColor(colorScheme, dayMood.index);
    }
    if (summary == null || !summary.hasEntries) {
      return emptyColor(colorScheme);
    }
    return switch (basis) {
      CalendarYearBasis.entries => heatColor(
        colorScheme,
        summary.heatLevel(CalendarHeatBasis.entries),
      ),
      CalendarYearBasis.words => heatColor(
        colorScheme,
        summary.heatLevel(CalendarHeatBasis.words),
      ),
      CalendarYearBasis.mood => switch (summary.averageMoodWeight) {
        null => noMoodColor(colorScheme),
        final weight => moodBandColor(
          colorScheme,
          MoodBandPalette.bandForWeight(weight),
        ),
      },
    };
  }
}

/// 年视图图例：心情为五段 emoji + “未选心情”；篇数/字数为“少 ▢▢▢▢ 多”。
class CalendarYearLegend extends StatelessWidget {
  const CalendarYearLegend({
    super.key,
    required this.basis,
    required this.moodOptions,
  });

  final CalendarYearBasis basis;
  final List<String> moodOptions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    if (basis == CalendarYearBasis.mood) {
      return Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (var band = 0; band < 5; band++)
            _LegendItem(
              color: CalendarYearPalette.moodBandColor(colorScheme, band),
              label: Text(
                SettingsService.moodForWeight(
                  CalendarYearPalette.moodBandWeights[band],
                  moodOptions,
                ),
                style: const TextStyle(fontSize: 12, height: 1),
              ),
            ),
          _LegendItem(
            color: CalendarYearPalette.noMoodColor(colorScheme),
            label: Text(l10n.calendarYearLegendNoMood, style: labelStyle),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(l10n.calendarYearLegendLess, style: labelStyle),
        const SizedBox(width: 6),
        for (var level = 1; level <= 4; level++) ...<Widget>[
          _Swatch(color: CalendarYearPalette.heatColor(colorScheme, level)),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 3),
        Text(l10n.calendarYearLegendMore, style: labelStyle),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Swatch(color: color),
        const SizedBox(width: 4),
        label,
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
