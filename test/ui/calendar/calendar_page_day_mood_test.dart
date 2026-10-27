import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/providers/day_mood_providers.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_mood_tile.dart';
import 'package:node_diary/ui/calendar/widgets/day_mood_picker.dart';

import '../../support/calendar_test_harness.dart';

const _optionsKey = 'app.settings.calendar_display_options';

/// 长按日期设定这天的心情：日期格整格换成心情，清除可撤销；显示选项关掉后
/// 日期格与长按面板都不再出现心情。
void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  final otherDay = today.day == 1 ? 2 : 1;

  Finder cellOn(int day) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is CalendarDayCell &&
        widget.day.month == today.month &&
        widget.day.day == day,
  );

  AppLocalizations l10nOf(WidgetTester tester) =>
      tester.element(find.byType(CalendarPage)).l10n;

  DayMood? moodOn(WidgetTester tester, int day) =>
      tester.widget<CalendarDayCell>(cellOn(day)).dayMood;

  /// 等 drift 的写入与 watch 推送落地（真实异步）再重建页面。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('a recorded mood fills its date cell (${brightness.name})', (
      tester,
    ) async {
      await pumpCalendarPage(
        tester,
        brightness: brightness,
        dayMoods: <DateTime, DayMood>{today: DayMood.great},
      );
      expect(moodOn(tester, today.day), DayMood.great);
      expect(
        find.descendant(
          of: cellOn(today.day),
          matching: find.byType(CalendarMoodTile),
        ),
        findsOneWidget,
      );
      expect(moodOn(tester, otherDay), isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('switching day moods off hides the tiles and the picker', (
    tester,
  ) async {
    await pumpCalendarPage(
      tester,
      dayMoods: <DateTime, DayMood>{today: DayMood.great},
      prefs: <String, Object>{
        _optionsKey: const CalendarDisplayOptions(showDayMoods: false).encode(),
      },
    );
    expect(moodOn(tester, today.day), isNull);
    expect(find.byType(CalendarMoodTile), findsNothing);

    await tester.longPress(cellOn(otherDay));
    await tester.pumpAndSettle();
    expect(find.byType(DayMoodPicker), findsNothing);
    expect(find.text(l10nOf(tester).calendarDayActionWrite), findsOneWidget);
  });

  testWidgets('long-press picks a mood, and clearing it can be undone', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await pumpCalendarPage(
      tester,
      dayMoods: null,
      extraOverrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    final l10n = l10nOf(tester);
    final day = DateTime(today.year, today.month, otherDay);
    Future<Map<DateTime, DayMood>> stored() async => indexDayMoods(
      (await tester.runAsync(() => database.select(database.dayMoods).get()))!,
    );

    // 设定：点“不错”即收起面板，日期格换成心情格。
    await tester.longPress(cellOn(otherDay));
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarDayMoodTitle), findsOneWidget);
    expect(find.text(l10n.calendarDayMoodClear), findsNothing);
    await tester.tap(find.text(l10n.dayMoodGood));
    await settle(tester);
    expect(find.byType(DayMoodPicker), findsNothing);
    expect(await stored(), <DateTime, DayMood>{day: DayMood.good});
    expect(moodOn(tester, otherDay), DayMood.good);

    // 换一个：面板里标出当前心情，选别的即覆盖。
    await tester.longPress(cellOn(otherDay));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DayMoodPicker>(find.byType(DayMoodPicker)).selected,
      DayMood.good,
    );
    await tester.tap(find.text(l10n.dayMoodAwful));
    await settle(tester);
    expect(moodOn(tester, otherDay), DayMood.awful);

    // 清除后撤销：原样写回。
    await tester.longPress(cellOn(otherDay));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.calendarDayMoodClear));
    await settle(tester);
    expect(moodOn(tester, otherDay), isNull);
    expect(find.text(l10n.calendarDayMoodCleared), findsOneWidget);
    await tester.tap(find.text(l10n.commonUndo));
    await settle(tester);
    expect(await stored(), <DateTime, DayMood>{day: DayMood.awful});
    expect(moodOn(tester, otherDay), DayMood.awful);
    await unmount(tester);
  });
}
