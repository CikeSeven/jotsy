import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_export_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 设置 → 数据管理 → 导出日记：按日期、标签与归档筛选，再进入导出面板。
void main() {
  late AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final travel = await database.createTag(name: '旅行', color: 0xFF1E6586);
    final now = DateTime.now();
    Future<String> diary(
      String title,
      DateTime createdAt, {
      List<int> tags = const <int>[],
    }) => database.createDiary(
      title: title,
      contentDocJson: '[{"insert":"$title\\n"}]',
      contentText: title,
      metadataJson: '{}',
      createdAtOverride: createdAt,
      tagIds: tags,
    );
    await diary('今天', now, tags: <int>[travel]);
    await diary('去年', DateTime(now.year - 1, 6, 1));
    final archived = await diary('归档', now.subtract(const Duration(days: 2)));
    await database.archiveDiary(archived, touchUpdatedAt: false);
    // 未解封的胶囊不出现在候选里。
    await database.createDiary(
      title: '胶囊',
      contentDocJson: '[{"insert":"x\\n"}]',
      contentText: 'x',
      metadataJson: '{}',
      capsuleLockedAt: now,
      capsuleUnlockAt: now.add(const Duration(days: 30)),
    );
  });
  tearDown(() => database.close());

  Future<void> pumpPage(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: expressiveTestTheme(brightness),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DiaryExportPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'filters by range, tag and archive, then opens the export sheet '
      '(${brightness.name})',
      (tester) async {
        await pumpPage(tester, brightness);
        expect(find.text('将导出 3 篇日记'), findsOneWidget);

        await tester.tap(find.text('今年'));
        await tester.pumpAndSettle();
        expect(find.text('将导出 2 篇日记'), findsOneWidget);

        await tester.tap(find.text('包含已归档的日记'));
        await tester.pumpAndSettle();
        expect(find.text('将导出 1 篇日记'), findsOneWidget);

        await tester.tap(find.text('全部日记'));
        await tester.tap(find.widgetWithText(FilterChip, '# 旅行'));
        await tester.pumpAndSettle();
        expect(find.text('将导出 1 篇日记'), findsOneWidget);

        await tester.tap(find.text('选择格式并导出'));
        await tester.pumpAndSettle();
        expect(find.text('共 1 篇'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _disposeTree(tester);
      },
    );
  }

  testWidgets('the export button is disabled when nothing matches', (
    tester,
  ) async {
    await database.createTag(name: '空', color: 0xFF1E6586);
    await pumpPage(tester, Brightness.light);
    await tester.tap(find.widgetWithText(FilterChip, '# 空'));
    await tester.pumpAndSettle();

    expect(find.text('将导出 0 篇日记'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('选择格式并导出'),
        matching: find.byWidgetPredicate((Widget w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    await _disposeTree(tester);
  });
}

/// 卸载页面后再推进一帧：drift 在取消查询流时排了一个零延时计时器，
/// 不跑完的话测试结束时计时器仍挂起，随后关闭数据库会一直等待。
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}
