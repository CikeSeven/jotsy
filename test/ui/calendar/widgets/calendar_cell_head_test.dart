import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_day_summary.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_lunar_day.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_cell_head.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_mood_tile.dart';
import 'package:node_diary/ui/widgets/qweather_icon.dart';

import '../../../support/expressive_test_theme.dart';

/// 角标的外接框四角都在圆角矩形 [shape] 之内（容差 0.01dp）。
bool _inside(RRect shape, Rect box) {
  final tolerant = shape.inflate(0.01);
  return <Offset>[
    box.topLeft,
    box.topRight,
    box.bottomLeft,
    box.bottomRight,
  ].every(tolerant.contains);
}

void main() {
  const options = CalendarDisplayOptions(showWeatherBadge: true);

  CalendarDaySummary weatherSummary(DateTime day) {
    return CalendarDaySummary.groupByDay(
      <DiaryCalendarMarker>[
        DiaryCalendarMarker(
          diaryId: 'cloudy',
          createdAt: day.add(const Duration(hours: 8)),
          weather: '多云',
          weatherIconCode: '101',
        ),
      ],
      now: day.add(const Duration(hours: 12)),
      moodOptions: SettingsService.defaultMoodOptions,
    )[day]!;
  }

  Future<void> pumpCell(
    WidgetTester tester, {
    required DateTime day,
    required Size size,
    CalendarDaySummary? summary,
    bool lunar = true,
    String? anniversary,
    DayMood? dayMood,
    double? highlightMaxWidth,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: SizedBox.fromSize(
            size: size,
            child: CalendarDayCell(
              day: day,
              options: options,
              isToday: false,
              isSelected: true,
              isOutside: false,
              isWeekend: false,
              summary: summary,
              lunar: lunar ? CalendarLunarDay.of(day) : null,
              anniversary: anniversary,
              dayMood: dayMood,
              highlightMaxWidth: highlightMaxWidth,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 填充形态的底色：外层 AnimatedContainer，14dp 圆角。
  RRect fillShape(WidgetTester tester) => RRect.fromRectAndRadius(
    tester.getRect(find.byType(AnimatedContainer).first),
    const Radius.circular(14),
  );

  group('CalendarCellHead in day cells', () {
    testWidgets('a weather badge on a narrow phone cell stays inside the '
        'rounded fill and beside the number', (tester) async {
      // 窄屏手机（约 360dp）显示农历时的一格：默认挂法会把天气图标挂到
      // 左上圆角之外（#312）。
      final day = DateTime(2026, 11, 5);
      await pumpCell(
        tester,
        day: day,
        size: const Size(42.7, 60),
        summary: weatherSummary(day),
      );

      final badge = tester.getRect(find.byType(QWeatherIcon));
      final number = tester.getRect(find.text('5'));
      expect(_inside(fillShape(tester), badge), isTrue);
      // 往下挪而不缩小，仍贴着数字左侧、不压住数字。
      expect(badge.width, moreOrLessEquals(9, epsilon: 0.01));
      expect(
        badge.right,
        moreOrLessEquals(number.left - CalendarCellHead.badgeGap),
      );
      expect(badge.top, greaterThan(number.top - CalendarCellHead.leadingRise));
      expect(badge.center.dy, lessThanOrEqualTo(number.center.dy + 0.01));
    });

    testWidgets('badges keep their place beside the number when the cell '
        'has room', (tester) async {
      final day = DateTime(2026, 11, 14);
      await pumpCell(
        tester,
        day: day,
        size: const Size(90, 84),
        summary: weatherSummary(day),
        highlightMaxWidth: 64,
      );

      final badge = tester.getRect(find.byType(QWeatherIcon));
      final number = tester.getRect(find.text('14'));
      expect(badge.size, const Size(9, 9));
      expect(
        badge.right,
        moreOrLessEquals(number.left - CalendarCellHead.badgeGap),
      );
      expect(
        badge.top,
        moreOrLessEquals(number.top - CalendarCellHead.leadingRise),
      );
    });

    testWidgets('a badge on a narrow mood tile stays inside the mood colour', (
      tester,
    ) async {
      // 心情格的数字贴顶，纪念日心形默认挂在格子上沿之外。
      await pumpCell(
        tester,
        day: DateTime(2026, 11, 5),
        size: const Size(42.7, 60),
        lunar: false,
        anniversary: '纪念日',
        dayMood: DayMood.good,
      );

      final heart = tester.getRect(find.byType(FaIcon));
      final number = tester.getRect(find.text('5'));
      final tile = RRect.fromRectAndRadius(
        tester.getRect(find.byType(CalendarMoodTile)),
        const Radius.circular(10),
      );
      expect(_inside(tile, heart), isTrue);
      expect(heart.right, lessThanOrEqualTo(number.left));
      expect(heart.overlaps(number), isFalse);
    });
  });

  group('CalendarCellHead.placeBadge', () {
    // 手机格子内容区里的安全区：填充底色比内容区大 2dp、14dp 圆角，再内缩 1dp。
    final safe = Rect.fromLTRB(-1, -1, 35.7, 51);
    const radius = 13.0;
    final safeShape = RRect.fromRectAndRadius(
      safe,
      const Radius.circular(radius),
    );

    Rect badgeRect(CalendarCellBadgePlacement placement, Size badge) =>
        placement.topLeft & badge * placement.scale;

    test('leaves a badge that already fits where it is', () {
      final number = Rect.fromLTWH(10, 20, 16, 15);
      final placement = CalendarCellHead.placeBadge(
        number: number,
        badge: const Size(9, 9),
        gap: 1.5,
        rise: 5,
        safe: safe,
        radius: radius,
        leading: true,
      );
      expect(placement.scale, 1);
      expect(placement.topLeft, const Offset(-0.5, 15));
    });

    test('moves a badge down out of the corner before shrinking it', () {
      final number = Rect.fromLTWH(10.35, 5.6, 14, 15.4);
      const badge = Size(9, 9);
      final placement = CalendarCellHead.placeBadge(
        number: number,
        badge: badge,
        gap: 1.5,
        rise: 5,
        safe: safe,
        radius: radius,
        leading: true,
      );
      final rect = badgeRect(placement, badge);
      expect(placement.scale, 1);
      expect(rect.top, greaterThan(number.top - 5));
      expect(rect.right, moreOrLessEquals(number.left - 1.5));
      expect(_inside(safeShape, rect), isTrue);
    });

    test('shrinks a badge towards the number when the cell is too narrow', () {
      // 数字很宽：原大的角标连左侧直边都越过了。
      final number = Rect.fromLTWH(8, 3, 18.7, 18.7);
      const badge = Size(9, 9);
      final placement = CalendarCellHead.placeBadge(
        number: number,
        badge: badge,
        gap: 1.5,
        rise: 5,
        safe: safe,
        radius: radius,
        leading: true,
      );
      final rect = badgeRect(placement, badge);
      expect(placement.scale, lessThan(1));
      expect(
        placement.scale,
        greaterThanOrEqualTo(CalendarCellHead.minBadgeScale),
      );
      expect(rect.right, moreOrLessEquals(number.left - 1.5));
      expect(_inside(safeShape, rect), isTrue);
      expect(rect.center.dy, lessThanOrEqualTo(number.center.dy + 0.01));
    });

    test('stops shrinking at the minimum scale when nothing fits', () {
      final number = Rect.fromLTWH(1, 0, 34, 18);
      final placement = CalendarCellHead.placeBadge(
        number: number,
        badge: const Size(9, 9),
        gap: 1.5,
        rise: 5,
        safe: safe,
        radius: radius,
        leading: true,
      );
      expect(placement.scale, CalendarCellHead.minBadgeScale);
    });

    test('keeps the count a superscript instead of dropping it beside the '
        'number', () {
      // 右上角挤：上标最多挪到数字字形顶部，再不够就缩小，不会挪到数字中部。
      final number = Rect.fromLTWH(6, 1.75, 21, 20);
      const badge = Size(5.6, 9);
      final placement = CalendarCellHead.placeBadge(
        number: number,
        badge: badge,
        gap: 1.5,
        rise: 2,
        safe: Rect.fromLTRB(-2, -2, 36.7, 52),
        radius: 14,
        leading: false,
      );
      final rect = badgeRect(placement, badge);
      expect(rect.left, moreOrLessEquals(number.right + 1.5));
      expect(
        rect.top,
        lessThanOrEqualTo(
          number.top + number.height * CalendarCellHead.trailingMaxDrop + 0.01,
        ),
      );
    });
  });
}
