import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/pages/anniversary_edit_page.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 预览页“更多”菜单“设为纪念日”：以这篇日记的日期与标题预填，并关联它。
void main() {
  late AppDatabase database;
  late String diaryId;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    diaryId = await database.createDiary(
      title: '第一次见面',
      contentDocJson: '[{"insert":"咖啡馆\\n"}]',
      contentText: '咖啡馆',
      metadataJson: '{}',
      createdAtOverride: DateTime(2019, 11, 20, 15),
    );
  });
  tearDown(() => database.close());

  testWidgets('the More menu makes the diary an anniversary', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiaryPreviewPage(diaryId: diaryId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(DiaryPreviewPage)).l10n;

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.previewSetAsAnniversary));
    await tester.pumpAndSettle();

    final page = tester.widget<AnniversaryEditPage>(
      find.byType(AnniversaryEditPage),
    );
    expect(page.initialDraft.title, '第一次见面');
    expect(page.initialDraft.date, DateTime(2019, 11, 20));
    expect(page.initialDraft.linkedDiaryId, diaryId);
    expect(page.editing, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
