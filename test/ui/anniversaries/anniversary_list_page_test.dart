import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/pages/anniversary_list_page.dart';
import 'package:node_diary/ui/anniversaries/providers/anniversary_providers.dart';
import 'package:node_diary/ui/anniversaries/widgets/anniversary_list_card.dart';
import 'package:node_diary/ui/widgets/list_item_presence.dart';

import '../../support/anniversary_fixtures.dart';
import '../../support/expressive_test_theme.dart';

void main() {
  final today = DateTime.now();
  String daysFromToday(int days) => formatAnniversaryDate(
    DateTime(today.year, today.month, today.day + days),
  );

  // 每年重复的日子取“几年前的 N 天后”，下一次就在 N 天后。
  String yearlyIn(int days) {
    final next = DateTime(today.year, today.month, today.day + days);
    return formatAnniversaryDate(DateTime(next.year - 3, next.month, next.day));
  }

  Future<StreamController<List<Anniversary>>> pumpList(
    WidgetTester tester,
    List<Anniversary> rows, {
    Locale locale = const Locale('zh'),
    Brightness brightness = Brightness.light,
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = StreamController<List<Anniversary>>();
    addTearDown(controller.close);
    controller.add(rows);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anniversaryListProvider.overrideWith((ref) => controller.stream),
        ],
        child: MaterialApp(
          locale: locale,
          theme: expressiveTestTheme(brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnniversaryListPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  List<String> titles(WidgetTester tester) => tester
      .widgetList<AnniversaryListCard>(find.byType(AnniversaryListCard))
      .map((card) => card.row.title)
      .toList();

  final rows = <Anniversary>[
    testAnniversary(
      id: 1,
      title: 'passed',
      baseDate: daysFromToday(-5),
      recurrence: AnniversaryRecurrence.once,
    ),
    testAnniversary(id: 2, title: 'far', baseDate: yearlyIn(40)),
    testAnniversary(id: 3, title: 'soon', baseDate: yearlyIn(3)),
    testAnniversary(
      id: 4,
      title: 'pinned',
      baseDate: yearlyIn(100),
      isPinned: true,
    ),
    testAnniversary(
      id: 5,
      title: 'countdown',
      baseDate: daysFromToday(10),
      recurrence: AnniversaryRecurrence.once,
    ),
  ];

  testWidgets('pinned first, then by the next time, passed days last', (
    tester,
  ) async {
    await pumpList(tester, rows);
    expect(titles(tester), <String>[
      'pinned',
      'soon',
      'countdown',
      'far',
      'passed',
    ]);
    final l10n = tester.element(find.byType(AnniversaryListPage)).l10n;
    expect(find.text(l10n.anniversaryPinnedBadge), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text(l10n.anniversaryDaysToGo(10)), findsWidgets);
    expect(find.text(l10n.anniversaryDaysAgo(5)), findsOneWidget);
  });

  testWidgets('an empty list explains how to add one', (tester) async {
    await pumpList(tester, const <Anniversary>[]);
    final l10n = tester.element(find.byType(AnniversaryListPage)).l10n;
    expect(find.text(l10n.anniversaryEmpty), findsOneWidget);
    expect(find.text(l10n.calendarDayActionAnniversary), findsOneWidget);
  });

  testWidgets('a new item grows in, existing ones do not', (tester) async {
    final controller = await pumpList(tester, rows.take(2).toList());
    bool appearing(String title) => tester
        .widget<ListItemPresence>(
          find.ancestor(
            of: find.text(title),
            matching: find.byType(ListItemPresence),
          ),
        )
        .appearing;
    expect(appearing('far'), isFalse);

    controller.add(rows.take(3).toList());
    await tester.pumpAndSettle();
    expect(appearing('soon'), isTrue);
    expect(appearing('far'), isFalse);
  });

  for (final brightness in Brightness.values) {
    for (final locale in const <Locale>[Locale('zh'), Locale('en')]) {
      testWidgets('fits 320dp (${locale.languageCode}, ${brightness.name})', (
        tester,
      ) async {
        await pumpList(
          tester,
          <Anniversary>[
            ...rows,
            testAnniversary(
              id: 6,
              title: 'A very long anniversary name that never ends',
              baseDate: '1900-01-01',
              recurrence: AnniversaryRecurrence.lunarYearly,
              isPinned: true,
            ),
          ],
          locale: locale,
          brightness: brightness,
          width: 320,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
