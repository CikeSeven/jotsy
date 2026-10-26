import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/services/app_platform.dart';
import '../../widgets/expressive_button_group.dart';
import '../models/calendar_display_options.dart';
import '../viewmodels/calendar_day_summary.dart';
import 'calendar_year_palette.dart';

/// 年视图（Year in Pixels）：12 个迷你月份，每天一个小格，按心情、篇数或
/// 字数着色。
///
/// 输入：年份、整年逐日汇总、着色依据、一周起始日（与月视图一致）；输出
/// 网格与图例，点月份经 [onMonthTap] 回到该月的月视图，切换着色依据经
/// [onBasisChanged]、导出经 [onExport] 交给页面。无副作用。
///
/// [captureKey] 挂在“年份 + 网格 + 图例”外层的 RepaintBoundary 上，导出图片
/// 只截这一块：着色依据按钮与导出按钮不进图。截图区自带卡片底色，PNG 不会
/// 是透明底。
class CalendarYearView extends StatelessWidget {
  const CalendarYearView({
    super.key,
    required this.year,
    required this.summaries,
    required this.basis,
    required this.moodOptions,
    required this.firstWeekday,
    required this.captureKey,
    required this.exporting,
    required this.onMonthTap,
    required this.onBasisChanged,
    required this.onExport,
  });

  final int year;
  final Map<DateTime, CalendarDaySummary> summaries;
  final CalendarYearBasis basis;
  final List<String> moodOptions;

  /// 每周第一天（DateTime.monday … DateTime.sunday）。
  final int firstWeekday;
  final GlobalKey captureKey;
  final bool exporting;
  final ValueChanged<DateTime> onMonthTap;
  final ValueChanged<CalendarYearBasis> onBasisChanged;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: ExpressiveButtonGroup<CalendarYearBasis>(
            // 标签只有两三个字，320dp 屏上也能横排。
            minSegmentWidth: 72,
            segments: <ButtonSegment<CalendarYearBasis>>[
              for (final value in CalendarYearBasis.values)
                ButtonSegment<CalendarYearBasis>(
                  value: value,
                  label: Text(calendarYearBasisLabel(l10n, value)),
                ),
            ],
            selected: <CalendarYearBasis>{basis},
            onSelectionChanged: (Set<CalendarYearBasis> selection) =>
                onBasisChanged(selection.single),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        // 分享按钮叠在截图区右上角、但不在 RepaintBoundary 内：导出的图里
        // 只有年份、网格与图例。
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            RepaintBoundary(
              key: captureKey,
              child: ColoredBox(
                color: ExpressiveSurfaces.cardColor(colorScheme),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    AppSpacing.s,
                    AppSpacing.xs,
                    AppSpacing.s,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppSpacing.xs,
                          // 给右上角的分享按钮让位。
                          right: 40,
                        ),
                        child: Text(
                          '${DateFormat.y(l10n.localeName).format(DateTime(year))}'
                          ' · ${calendarYearBasisLabel(l10n, basis)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      _MonthGrid(
                        year: year,
                        summaries: summaries,
                        basis: basis,
                        firstWeekday: firstWeekday,
                        today: today,
                        onMonthTap: onMonthTap,
                      ),
                      const SizedBox(height: AppSpacing.m),
                      CalendarYearLegend(
                        basis: basis,
                        moodOptions: moodOptions,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -6,
              right: 0,
              child: IconButton(
                // 没有系统分享的平台（Linux）导出为保存图片，图标随之换成保存。
                tooltip: AppPlatform.supportsSystemFileShare
                    ? l10n.calendarYearExport
                    : l10n.calendarYearSaveImage,
                visualDensity: VisualDensity.compact,
                onPressed: exporting ? null : onExport,
                icon: FaIcon(
                  AppPlatform.supportsSystemFileShare
                      ? FontAwesomeIcons.shareNodes
                      : FontAwesomeIcons.download,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String calendarYearBasisLabel(AppLocalizations l10n, CalendarYearBasis basis) {
  return switch (basis) {
    CalendarYearBasis.mood => l10n.calendarYearBasisMood,
    CalendarYearBasis.entries => l10n.calendarYearBasisEntries,
    CalendarYearBasis.words => l10n.calendarYearBasisWords,
  };
}

/// 三列四行的迷你月份。
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.year,
    required this.summaries,
    required this.basis,
    required this.firstWeekday,
    required this.today,
    required this.onMonthTap,
  });

  static const int _columns = 3;

  final int year;
  final Map<DateTime, CalendarDaySummary> summaries;
  final CalendarYearBasis basis;
  final int firstWeekday;
  final DateTime today;
  final ValueChanged<DateTime> onMonthTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var row = 0; row < 12 ~/ _columns; row++) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var column = 0; column < _columns; column++)
              Expanded(
                child: _MiniMonth(
                  month: DateTime(year, row * _columns + column + 1),
                  summaries: summaries,
                  basis: basis,
                  firstWeekday: firstWeekday,
                  today: today,
                  onTap: onMonthTap,
                ),
              ),
          ],
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// 一个迷你月份：月份名 + 7 列日期小格。固定按 6 行占位，四行迷你月份
/// 同高对齐；整块可点，进入该月的月视图。
class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.month,
    required this.summaries,
    required this.basis,
    required this.firstWeekday,
    required this.today,
    required this.onTap,
  });

  final DateTime month;
  final Map<DateTime, CalendarDaySummary> summaries;
  final CalendarYearBasis basis;
  final int firstWeekday;
  final DateTime today;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final colors = <Color>[
      for (var day = 1; day <= daysInMonth; day++)
        CalendarYearPalette.pixelColor(
          colorScheme,
          summaries[DateTime(month.year, month.month, day)],
          basis,
        ),
    ];
    final label = DateFormat.MMM(l10n.localeName).format(month);
    return Semantics(
      button: true,
      label: DateFormat.yMMMM(l10n.localeName).format(month),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(month),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isCurrentMonth
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final cell = constraints.maxWidth / 7;
                  return CustomPaint(
                    size: Size(constraints.maxWidth, cell * 6),
                    painter: _MiniMonthPainter(
                      colors: colors,
                      leadingBlanks: (month.weekday - firstWeekday + 7) % 7,
                      todayIndex: isCurrentMonth ? today.day - 1 : null,
                      todayColor: colorScheme.onSurface,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一次画完一个月的小格：365 个格子用 Widget 搭会带来上千个元素，翻年时
/// 重建明显；CustomPainter 只在颜色或今天位置变化时重绘。
class _MiniMonthPainter extends CustomPainter {
  _MiniMonthPainter({
    required this.colors,
    required this.leadingBlanks,
    required this.todayIndex,
    required this.todayColor,
  });

  final List<Color> colors;
  final int leadingBlanks;
  final int? todayIndex;
  final Color todayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 7;
    final gap = (cell * 0.18).clamp(1.0, 2.5);
    final side = cell - gap;
    final radius = Radius.circular(side * 0.28);
    final fill = Paint();
    for (var index = 0; index < colors.length; index++) {
      final slot = index + leadingBlanks;
      final rect = Rect.fromLTWH(
        (slot % 7) * cell + gap / 2,
        (slot ~/ 7) * cell + gap / 2,
        side,
        side,
      );
      fill.color = colors[index];
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
      if (index == todayIndex) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(0.6), radius),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = todayColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MiniMonthPainter oldDelegate) {
    return oldDelegate.leadingBlanks != leadingBlanks ||
        oldDelegate.todayIndex != todayIndex ||
        oldDelegate.todayColor != todayColor ||
        !_sameColors(oldDelegate.colors, colors);
  }

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}
