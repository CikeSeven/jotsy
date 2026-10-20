import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/pages/anniversary_detail_page.dart';
import 'package:node_diary/ui/anniversaries/pages/anniversary_edit_page.dart';
import 'package:node_diary/ui/anniversaries/providers/anniversary_providers.dart';
import 'package:node_diary/ui/anniversaries/widgets/anniversary_linked_diary_button.dart';
import 'package:node_diary/ui/calendar/models/calendar_display_options.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_anniversary_section.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';

import '../../support/anniversary_fixtures.dart';
import '../../support/calendar_test_harness.dart';

const _optionsKey = 'app.settings.calendar_display_options';
const _featuresKey = 'app.settings.app_features';

void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  // 四年前的今天：闰日也存在，今天就是第 4 周年。
  final together = testAnniversary(
    id: 1,
    title: '在一起',
    baseDate: formatAnniversaryDate(
      DateTime(today.year - 4, today.month, today.day),
    ),
  );
  final otherDay = today.day == 1 ? 2 : 1;

  Finder cellOn(int day) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is CalendarDayCell &&
        widget.day.month == today.month &&
        widget.day.day == day,
  );

  for (final brightness in Brightness.values) {
    testWidgets('the card follows the selected day (${brightness.name})', (
      tester,
    ) async {
      await pumpCalendarPage(
        tester,
        brightness: brightness,
        anniversaries: <Anniversary>[together],
      );
      final l10n = tester.element(find.byType(CalendarPage)).l10n;
      expect(
        tester.widget<CalendarDayCell>(cellOn(today.day)).anniversary,
        '在一起',
      );
      final section = find.byType(CalendarAnniversarySection);
      expect(section, findsOneWidget);
      expect(
        find.descendant(of: section, matching: find.text('在一起')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: section,
          matching: find.text(l10n.anniversaryTodayOrdinal(4)),
        ),
        findsOneWidget,
      );

      await tester.tap(cellOn(otherDay));
      await tester.pumpAndSettle();
      expect(section, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('switching anniversaries off hides marks and the card', (
    tester,
  ) async {
    await pumpCalendarPage(
      tester,
      anniversaries: <Anniversary>[together],
      prefs: <String, Object>{
        _optionsKey: const CalendarDisplayOptions(
          showAnniversaries: false,
        ).encode(),
      },
    );
    expect(
      tester.widget<CalendarDayCell>(cellOn(today.day)).anniversary,
      isNull,
    );
    expect(find.byType(CalendarAnniversarySection), findsNothing);
  });

  testWidgets('long-pressing a day offers to add an anniversary', (
    tester,
  ) async {
    await pumpCalendarPage(tester);
    final l10n = tester.element(find.byType(CalendarPage)).l10n;
    await tester.longPress(cellOn(otherDay));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.calendarDayActionAnniversary));
    await tester.pumpAndSettle();
    expect(find.byType(AnniversaryEditPage), findsOneWidget);
    expect(find.text(l10n.anniversaryNewTitle), findsOneWidget);
  });

  testWidgets('the card opens the details; a linked diary gets a shortcut', (
    tester,
  ) async {
    final linked = together.copyWith(linkedDiaryId: const Value('diary-1'));
    await pumpCalendarPage(
      tester,
      anniversaries: <Anniversary>[linked],
      linkedDiaries: <String, DiaryWithTags>{
        'diary-1': calendarTestDiary('diary-1', today, title: '那天'),
      },
      extraOverrides: [
        anniversaryProvider.overrideWith((ref, id) => Stream.value(linked)),
        anniversaryPastDiariesProvider.overrideWith(
          (ref, rule) => Stream.value(const <DiaryWithTags>[]),
        ),
      ],
    );
    final section = find.byType(CalendarAnniversarySection);
    final shortcut = find.descendant(
      of: section,
      matching: find.byType(AnniversaryLinkedDiaryButton),
    );
    expect(
      find.descendant(of: shortcut, matching: find.byType(IconButton)),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: section, matching: find.text('在一起')));
    await tester.pumpAndSettle();
    expect(find.byType(AnniversaryDetailPage), findsOneWidget);
  });

  testWidgets('no shortcut when the linked diary is gone', (tester) async {
    final linked = together.copyWith(linkedDiaryId: const Value('gone'));
    await pumpCalendarPage(tester, anniversaries: <Anniversary>[linked]);
    expect(
      find.descendant(
        of: find.byType(AnniversaryLinkedDiaryButton),
        matching: find.byType(IconButton),
      ),
      findsNothing,
    );
  });

  group('with the anniversaries feature off', () {
    const featuresOff = <String, Object>{
      _featuresKey: '{"anniversaries":false}',
    };

    testWidgets('the grid has no marks and there is no day card', (
      tester,
    ) async {
      await pumpCalendarPage(
        tester,
        anniversaries: <Anniversary>[together],
        prefs: featuresOff,
      );
      expect(
        tester.widget<CalendarDayCell>(cellOn(today.day)).anniversary,
        isNull,
      );
      expect(find.byType(CalendarAnniversarySection), findsNothing);
    });

    testWidgets('the header has no anniversaries button', (tester) async {
      await pumpCalendarPage(tester, prefs: featuresOff);
      final l10n = tester.element(find.byType(CalendarPage)).l10n;
      expect(find.byTooltip(l10n.anniversaryListTitle), findsNothing);
    });

    testWidgets('long-pressing a day offers no anniversary action', (
      tester,
    ) async {
      await pumpCalendarPage(tester, prefs: featuresOff);
      final l10n = tester.element(find.byType(CalendarPage)).l10n;
      await tester.longPress(cellOn(otherDay));
      await tester.pumpAndSettle();
      expect(find.text(l10n.calendarDayActionWrite), findsOneWidget);
      expect(find.text(l10n.calendarDayActionRange), findsOneWidget);
      expect(find.text(l10n.calendarDayActionAnniversary), findsNothing);
    });

    testWidgets('the display options have no anniversaries row', (
      tester,
    ) async {
      await pumpCalendarPage(tester, prefs: featuresOff);
      final l10n = tester.element(find.byType(CalendarPage)).l10n;
      await tester.tap(find.byTooltip(l10n.calendarDisplayOptionsTooltip));
      await tester.pumpAndSettle();
      expect(find.text(l10n.calendarShowOnThisDay), findsOneWidget);
      expect(find.text(l10n.calendarShowAnniversaries), findsNothing);
    });
  });

  testWidgets('with the feature on, the header button and option are there', (
    tester,
  ) async {
    await pumpCalendarPage(tester);
    final l10n = tester.element(find.byType(CalendarPage)).l10n;
    expect(find.byTooltip(l10n.anniversaryListTitle), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.calendarDisplayOptionsTooltip));
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarShowAnniversaries), findsOneWidget);
  });
}
