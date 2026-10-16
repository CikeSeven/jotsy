import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/controllers/anniversary_edit_controller.dart';
import 'package:node_diary/ui/anniversaries/controllers/anniversary_navigation.dart';
import 'package:node_diary/ui/anniversaries/models/anniversary_draft.dart';
import 'package:node_diary/ui/anniversaries/pages/anniversary_edit_page.dart';
import 'package:node_diary/ui/anniversaries/viewmodels/anniversary_rule.dart';

import '../../support/expressive_test_theme.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  // Drift 的查询调度走真实事件队列，widget 测试的虚拟时钟里直接 await 会
  // 一直等下去：测试体里的读写经 runAsync，页面触发的写入用 [settle] 让出
  // 真实时间并泵帧，直到写入与随后的导航完成。
  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<List<Anniversary>> rows(WidgetTester tester) =>
      real(tester, () => db.select(db.anniversaries).get());

  // 卸载后冲刷 drift 流取消时排入的零时长计时器。
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  /// 宿主页一个按钮打开编辑页，记下带回的结果。
  Future<List<AnniversaryEditResult?>> pumpHost(
    WidgetTester tester, {
    required AnniversaryDraft draft,
    Anniversary? editing,
    Brightness brightness = Brightness.light,
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <AnniversaryEditResult?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: const Locale('zh'),
          theme: expressiveTestTheme(brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async => results.add(
                  await openAnniversaryEditor(
                    context,
                    database: db,
                    draft: draft,
                    editing: editing,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  TextButton saveButton(WidgetTester tester, AppLocalizations l10n) =>
      tester.widget<TextButton>(
        find.ancestor(
          of: find.text(l10n.commonSave),
          matching: find.byType(TextButton),
        ),
      );

  AppLocalizations l10nOf(WidgetTester tester) =>
      tester.element(find.byType(AnniversaryEditPage)).l10n;

  testWidgets('a lunar birthday saves with its lunar snapshot', (tester) async {
    final results = await pumpHost(
      tester,
      draft: AnniversaryDraft.forDay(
        DateTime(2020, 5, 23),
        today: DateTime(2026, 10, 16),
      ),
    );
    final l10n = l10nOf(tester);
    expect(saveButton(tester, l10n).onPressed, isNull, reason: '名称为空不能保存');
    expect(
      find.text(l10n.anniversaryRepeatSolarDescription('5月23日')),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, '  外婆生日 ');
    await tester.tap(find.text(l10n.anniversaryRepeatLunar));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.anniversaryRepeatLunarDescription('闰四月初一')),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.commonSave));
    await settle(tester);
    final row = (await rows(tester)).single;
    expect(row.title, '外婆生日');
    expect(row.recurrence, AnniversaryRecurrence.lunarYearly.name);
    expect(AnniversaryRule.fromRow(row)?.lunar, const LunarYmd(2020, -4, 1));
    expect(results.single, isA<AnniversaryCreated>());
    expect(find.text(l10n.anniversaryCreated), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('clearing the name shows an error and blocks saving', (
    tester,
  ) async {
    await pumpHost(
      tester,
      draft: AnniversaryDraft.forDay(
        DateTime(2026, 12, 31),
        today: DateTime(2026, 10, 16),
      ),
    );
    final l10n = l10nOf(tester);
    // 未来的日子默认“不重复”。
    expect(find.text(l10n.anniversaryRepeatOnceDescription), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '考试');
    await tester.pump();
    expect(saveButton(tester, l10n).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField).first, ' ');
    await tester.pump();
    expect(find.text(l10n.anniversaryNameRequired), findsOneWidget);
    expect(saveButton(tester, l10n).onPressed, isNull);
    await unmount(tester);
  });

  testWidgets('leaving with changes asks first', (tester) async {
    await pumpHost(
      tester,
      draft: AnniversaryDraft.forDay(
        DateTime(2026, 1, 1),
        today: DateTime(2026, 10, 16),
      ),
    );
    final l10n = l10nOf(tester);
    await tester.enterText(find.byType(TextField).first, '元旦');
    await tester.tap(find.byTooltip(l10n.commonBack));
    await tester.pumpAndSettle();
    expect(find.text(l10n.autoT0131), findsOneWidget);
    await tester.tap(find.text(l10n.autoT0132));
    await tester.pumpAndSettle();
    expect(find.byType(AnniversaryEditPage), findsNothing);
    expect(await rows(tester), isEmpty);
    await unmount(tester);
  });

  testWidgets('deleting asks, then undo restores the anniversary', (
    tester,
  ) async {
    await real(
      tester,
      () => db.createAnniversary(
        title: '搬家',
        baseDate: DateTime(2021, 3, 1),
        recurrence: AnniversaryRecurrence.solarYearly,
      ),
    );
    final row = (await rows(tester)).single;
    final results = await pumpHost(
      tester,
      draft: AnniversaryDraft.fromRow(row),
      editing: row,
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.anniversaryEditTitle), findsOneWidget);
    await tester.ensureVisible(find.text(l10n.anniversaryDelete));
    await tester.tap(find.text(l10n.anniversaryDelete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.anniversaryDeleteConfirmTitle), findsOneWidget);
    await tester.tap(find.text(l10n.commonDelete));
    await settle(tester);

    expect(results.single, isA<AnniversaryDeleted>());
    expect(await rows(tester), isEmpty);
    await tester.tap(find.text(l10n.commonUndo));
    await settle(tester);
    expect((await rows(tester)).single, row);
    await unmount(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits a 320dp screen (${brightness.name})', (tester) async {
      await real(
        tester,
        () => db.createAnniversary(
          title: '我们在一起的第一天，值得一直记住',
          baseDate: DateTime(2020, 2, 29),
          recurrence: AnniversaryRecurrence.solarYearly,
          note: '备注',
          isPinned: true,
        ),
      );
      final row = (await rows(tester)).single;
      await pumpHost(
        tester,
        draft: AnniversaryDraft.fromRow(row),
        editing: row,
        brightness: brightness,
        width: 320,
      );
      expect(
        find.text(l10nOf(tester).anniversaryRepeatLeapDayDescription),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
