import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/pages/anniversary_detail_page.dart';
import 'package:node_diary/ui/anniversaries/providers/anniversary_providers.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_diary_mini_card.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';

import '../../support/calendar_test_harness.dart';
import '../../support/expressive_test_theme.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // 三年前的十天后：下一次在十天后，是第 3 周年。
  final next = DateTime(today.year, today.month, today.day + 10);
  final base = DateTime(next.year - 3, next.month, next.day);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<String> seed(WidgetTester tester, {String? linkedDiaryId}) async {
    return (await tester.runAsync(
      () => db.createAnniversary(
        title: '搬进新家',
        baseDate: base,
        recurrence: AnniversaryRecurrence.solarYearly,
        linkedDiaryId: linkedDiaryId,
        note: '第一晚吃了火锅',
      ),
    ))!;
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    String id, {
    DiaryWithTags? linked,
    List<DiaryWithTags> past = const <DiaryWithTags>[],
    double width = 400,
    Brightness brightness = Brightness.light,
    bool withHost = false,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          anniversaryLinkedDiaryProvider.overrideWith(
            (ref, diaryId) => Stream.value(linked),
          ),
          anniversaryPastDiariesProvider.overrideWith(
            (ref, rule) => Stream.value(past),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          theme: expressiveTestTheme(brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: withHost
              ? Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AnniversaryDetailPage(anniversaryId: id),
                          ),
                        ),
                        child: const Text('open'),
                      ),
                    ),
                  ),
                )
              : AnniversaryDetailPage(anniversaryId: id),
        ),
      ),
    );
    await settle(tester);
    if (withHost) {
      await tester.tap(find.text('open'));
      await settle(tester);
    }
  }

  Future<void> openMore(WidgetTester tester) async {
    final l10n = tester.element(find.byType(AnniversaryDetailPage)).l10n;
    await tester.tap(find.byTooltip(l10n.anniversaryMoreActions));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('shows the countdown, the rule and the note', (tester) async {
    final id = await seed(tester);
    await pumpDetail(tester, id);
    final l10n = tester.element(find.byType(AnniversaryDetailPage)).l10n;
    expect(find.text('搬进新家'), findsOneWidget);
    expect(find.text(l10n.anniversaryDaysLeft(10)), findsOneWidget);
    expect(find.textContaining(l10n.anniversaryOrdinal(3)), findsOneWidget);
    expect(find.text(l10n.anniversaryRepeatSolar), findsOneWidget);
    expect(find.text('第一晚吃了火锅'), findsOneWidget);
    expect(find.text(l10n.anniversaryLinkPick), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a deleted linked diary can be unlinked', (tester) async {
    final id = await seed(tester, linkedDiaryId: 'gone');
    await pumpDetail(tester, id);
    final l10n = tester.element(find.byType(AnniversaryDetailPage)).l10n;
    expect(find.text(l10n.anniversaryLinkMissing), findsOneWidget);
    await tester.tap(find.text(l10n.anniversaryUnlink));
    await settle(tester);
    final row = await tester.runAsync(() => db.watchAnniversary(id).first);
    expect(row?.linkedDiaryId, isNull);
    expect(find.text(l10n.anniversaryLinkPick), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('lists past diaries but hides sealed capsules and the linked '
      'one', (tester) async {
    final linked = calendarTestDiary('linked', base, title: '第一天');
    final id = await seed(tester, linkedDiaryId: 'linked');
    final lastYear = DateTime(next.year - 1, next.month, next.day, 20);
    await pumpDetail(
      tester,
      id,
      linked: linked,
      past: <DiaryWithTags>[
        calendarTestDiary('last-year', lastYear, title: '一周年'),
        linked,
        calendarTestDiary(
          'capsule',
          lastYear,
          title: '秘密',
          capsuleUnlockAt: DateTime(today.year + 5),
        ),
      ],
    );
    final l10n = tester.element(find.byType(AnniversaryDetailPage)).l10n;
    expect(find.text(l10n.anniversaryPastDiariesTitle), findsOneWidget);
    final cards = tester
        .widgetList<CalendarDiaryMiniCard>(find.byType(CalendarDiaryMiniCard))
        .map((card) => card.diary.diary.diaryId)
        .toList();
    expect(cards, <String>['linked', 'last-year']);
    expect(find.textContaining(l10n.anniversaryOrdinal(2)), findsOneWidget);
    expect(find.text('秘密'), findsNothing);
    await unmount(tester);
  });

  testWidgets('more opens an anchored menu and pin toggles', (tester) async {
    final id = await seed(tester);
    await pumpDetail(tester, id);
    final l10n = tester.element(find.byType(AnniversaryDetailPage)).l10n;
    await openMore(tester);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(ExpressiveMenuItem), findsNWidgets(2));
    expect(find.byIcon(FontAwesomeIcons.thumbtack.data), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.trashCan.data), findsOneWidget);
    final delete = tester.widget<ExpressiveMenuItem>(
      find.ancestor(
        of: find.text(l10n.anniversaryDelete),
        matching: find.byType(ExpressiveMenuItem),
      ),
    );
    expect(delete.destructive, isTrue);

    await tester.tap(find.text(l10n.anniversaryPin));
    await settle(tester);
    expect(find.byType(ExpressiveMenuItem), findsNothing);
    final row = await tester.runAsync(() => db.watchAnniversary(id).first);
    expect(row?.isPinned, isTrue);

    await openMore(tester);
    expect(find.text(l10n.anniversaryUnpin), findsOneWidget);
    expect(find.text(l10n.anniversaryPin), findsNothing);
    await unmount(tester);
  });

  testWidgets('delete confirms, pops and offers undo on the previous page', (
    tester,
  ) async {
    final id = await seed(tester);
    await pumpDetail(tester, id, withHost: true);
    final l10n = tester.element(find.byType(AnniversaryDetailPage)).l10n;
    await openMore(tester);
    await tester.tap(find.text(l10n.anniversaryDelete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.anniversaryDeleteConfirmTitle), findsOneWidget);
    await tester.tap(find.text(l10n.commonDelete));
    await settle(tester);
    expect(find.byType(AnniversaryDetailPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(find.text(l10n.anniversaryDeleted), findsOneWidget);
    final row = await tester.runAsync(() => db.watchAnniversary(id).first);
    expect(row, isNull);
    await unmount(tester);
  });

  testWidgets('cancelling the delete keeps the page', (tester) async {
    final id = await seed(tester);
    await pumpDetail(tester, id, withHost: true);
    final l10n = tester.element(find.byType(AnniversaryDetailPage)).l10n;
    await openMore(tester);
    await tester.tap(find.text(l10n.anniversaryDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonCancel));
    await settle(tester);
    expect(find.text(l10n.anniversaryDeleteConfirmTitle), findsNothing);
    expect(find.byType(AnniversaryDetailPage), findsOneWidget);
    expect(find.text(l10n.anniversaryDeleted), findsNothing);
    final row = await tester.runAsync(() => db.watchAnniversary(id).first);
    expect(row, isNotNull);
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits 320dp (${brightness.name})', (tester) async {
      final id = await seed(tester);
      await pumpDetail(tester, id, width: 320, brightness: brightness);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
