import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_filter_bar.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_filter_sheet.dart';

import '../../support/calendar_test_harness.dart';

const _moods = SettingsService.defaultMoodOptions;
const _travel = Tag(id: 1, name: '旅行', color: 0xFF2E7D32);
const _work = Tag(id: 2, name: '工作', color: 0xFF1565C0);

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(CalendarPage)).l10n;

CalendarDayCell _cell(WidgetTester tester, int day) =>
    tester.widget<CalendarDayCell>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is CalendarDayCell &&
            !widget.isOutside &&
            widget.day.day == day,
      ),
    );

bool _hasEntries(WidgetTester tester, int day) =>
    _cell(tester, day).summary?.hasEntries ?? false;

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(CalendarFilterSheet), matching: finder);

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(200, 40));
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime.now();
  DiaryCalendarMarker entry(
    String id,
    int day, {
    required String mood,
    List<int> tags = const <int>[],
    DateTime? unlockAt,
  }) => DiaryCalendarMarker(
    diaryId: id,
    createdAt: DateTime(now.year, now.month, day, 9),
    moodEmoji: mood,
    tagIds: tags,
    capsuleUnlockAt: unlockAt,
  );
  final markers = <DiaryCalendarMarker>[
    entry('happy-travel', 5, mood: _moods[0], tags: <int>[1]),
    entry('sad-work', 6, mood: _moods[9], tags: <int>[2]),
    entry('happy-plain', 7, mood: _moods[0]),
    entry(
      'locked',
      8,
      mood: _moods[9],
      tags: <int>[2],
      unlockAt: DateTime(now.year + 2),
    ),
  ];

  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      testWidgets('filtering by mood and tag narrows cells and stats', (
        tester,
      ) async {
        await pumpCalendarPage(
          tester,
          brightness: brightness,
          markers: markers,
          tags: const <Tag>[_travel, _work],
        );
        final l10n = _l10n(tester);
        expect(find.byTooltip(l10n.calendarSummaryEntries(3)), findsOneWidget);
        expect(find.byType(CalendarFilterBar), findsNothing);

        await tester.tap(find.byTooltip(l10n.calendarFilterTooltip));
        await tester.pumpAndSettle();
        await tester.tap(_inSheet(find.text(_moods[0])));
        await tester.pumpAndSettle();

        // 面板保持打开，网格在遮罩后方已经只剩开心的两天。
        expect(find.byType(CalendarFilterSheet), findsOneWidget);
        expect(_hasEntries(tester, 5), isTrue);
        expect(_hasEntries(tester, 6), isFalse);
        expect(_hasEntries(tester, 7), isTrue);
        // 未解封胶囊不参与筛选：锁照常显示。
        expect(_cell(tester, 8).summary?.hasLockedCapsule, isTrue);
        expect(find.byTooltip(l10n.calendarSummaryEntries(2)), findsOneWidget);

        // 心情与标签同时满足：开心且带“工作”的日记没有。
        await tester.tap(_inSheet(find.text(_work.name)));
        await tester.pumpAndSettle();
        expect(_hasEntries(tester, 5), isFalse);
        expect(_hasEntries(tester, 7), isFalse);
        expect(find.text(l10n.calendarSummaryEmpty), findsOneWidget);

        await tester.tap(_inSheet(find.text(_travel.name)));
        await tester.pumpAndSettle();
        expect(_hasEntries(tester, 5), isTrue);
        await _closeSheet(tester);

        expect(find.byType(CalendarFilterBar), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.ancestor(
                  of: find.byTooltip(l10n.calendarFilterTooltip),
                  matching: find.byType(IconButton),
                ),
              )
              .isSelected,
          isTrue,
        );

        await tester.tap(
          find.descendant(
            of: find.byType(CalendarFilterBar),
            matching: find.byTooltip(l10n.calendarFilterClear),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CalendarFilterBar), findsNothing);
        expect(_hasEntries(tester, 6), isTrue);
        expect(find.byTooltip(l10n.calendarSummaryEntries(3)), findsOneWidget);
      });

      testWidgets('the year view and its summary follow the filter', (
        tester,
      ) async {
        await pumpCalendarPage(
          tester,
          brightness: brightness,
          markers: markers,
          tags: const <Tag>[_travel, _work],
        );
        final l10n = _l10n(tester);
        await tester.tap(find.byTooltip(l10n.calendarFilterTooltip));
        await tester.pumpAndSettle();
        await tester.tap(_inSheet(find.text(_work.name)));
        await tester.pumpAndSettle();
        await _closeSheet(tester);

        await tester.tap(find.byTooltip(l10n.calendarYearViewTooltip));
        await tester.pumpAndSettle();
        expect(find.byTooltip(l10n.calendarSummaryEntries(1)), findsOneWidget);
        expect(find.byType(CalendarFilterBar), findsOneWidget);
      });

      testWidgets('the sheet explains when there are no tags', (tester) async {
        await pumpCalendarPage(tester, brightness: brightness);
        final l10n = _l10n(tester);
        await tester.tap(find.byTooltip(l10n.calendarFilterTooltip));
        await tester.pumpAndSettle();
        expect(_inSheet(find.text(l10n.calendarFilterNoTags)), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(
                _inSheet(
                  find.widgetWithText(TextButton, l10n.calendarFilterClear),
                ),
              )
              .onPressed,
          isNull,
        );
      });
    });
  }
}
