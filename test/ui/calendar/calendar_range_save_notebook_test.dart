import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cell.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_editor_page.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_rule_labels.dart';

import '../../support/calendar_test_harness.dart';

/// 日历范围统计“存为日记本”：智能（日期区间规则）与普通（收进这段日期里
/// 现在的日记）两条分支。
void main() {
  final now = DateTime.now();
  final first = DateTime(now.year, now.month, 3);
  final last = DateTime(now.year, now.month, 12);

  Finder cellOf(int day) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is CalendarDayCell && !widget.isOutside && widget.day.day == day,
  );

  AppLocalizations l10nOf(WidgetTester tester) =>
      tester.element(find.byType(CalendarPage)).l10n;

  /// 离开假时钟让 drift 读写完成，再补帧。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<(AppDatabase, Map<String, String>)> open(WidgetTester tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final ids = <String, String>{};
    await tester.runAsync(() async {
      for (final (title, day) in <(String, int)>[
        ('五日', 5),
        ('十日', 10),
        ('二十日', 20),
      ]) {
        ids[title] = await database.createDiary(
          title: title,
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
          createdAtOverride: DateTime(now.year, now.month, day, 9),
        );
      }
    });
    await pumpCalendarPage(
      tester,
      extraOverrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    // 选 3 日 – 12 日。
    await tester.longPress(cellOf(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nOf(tester).calendarDayActionRange));
    await tester.pumpAndSettle();
    await tester.tap(cellOf(12));
    await tester.pumpAndSettle();
    return (database, ids);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  testWidgets('saving as a regular notebook files the diaries in range', (
    tester,
  ) async {
    final (database, ids) = await open(tester);
    final l10n = l10nOf(tester);
    await tester.tap(find.widgetWithText(TextButton, '存为日记本'));
    await settle(tester);
    expect(find.text('收进现在这 2 篇'), findsOneWidget);

    await tester.tap(find.text('普通日记本'));
    await settle(tester);
    expect(find.byType(NotebookEditorPage), findsOneWidget);
    final name = notebookDateRangeLabel(l10n, first, last, now: now);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      name,
    );
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await settle(tester);

    final row = (await tester.runAsync(database.getNotebooks))!.single;
    expect(row.name, name);
    expect(row.notebookKind, NotebookKind.manual);
    expect(row.parsedPayload.rules, isNull);
    final members = (await tester.runAsync(
      () => database.getActiveDiaryIds(
        scope: DiaryNotebookScope(notebookId: row.notebookId, bookOrder: true),
      ),
    ))!;
    expect(members, <String>[ids['五日']!, ids['十日']!]);
    await unmount(tester);
  });

  testWidgets('saving as a smart notebook stores the date range rule', (
    tester,
  ) async {
    final (database, _) = await open(tester);
    final l10n = l10nOf(tester);
    await tester.tap(find.widgetWithText(TextButton, '存为日记本'));
    await settle(tester);
    await tester.tap(find.text('智能日记本'));
    await settle(tester);

    final range = notebookDateRangeLabel(l10n, first, last, now: now);
    await tester.scrollUntilVisible(
      find.text('条件'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    // 名称与规则摘要是同一段日期。
    expect(find.widgetWithText(ListTile, range), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await settle(tester);

    final row = (await tester.runAsync(database.getNotebooks))!.single;
    expect(row.notebookKind, NotebookKind.smart);
    expect(
      NotebookRuleSet.decode(row.parsedPayload.rules).rules,
      <NotebookRule>[NotebookDateRule.between(first, last)],
    );
    await unmount(tester);
  });

  testWidgets('the button only appears once the range is complete', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await pumpCalendarPage(
      tester,
      extraOverrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    await tester.longPress(cellOf(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nOf(tester).calendarDayActionRange));
    await tester.pumpAndSettle();
    expect(find.text('存为日记本'), findsNothing);
    await tester.tap(cellOf(5));
    await tester.pumpAndSettle();
    expect(find.text('存为日记本'), findsOneWidget);
    await unmount(tester);
  });
}
