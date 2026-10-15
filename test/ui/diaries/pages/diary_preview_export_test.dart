import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/widgets/action_loading_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 预览页“更多”菜单导出日记文件：先经可选密码弹窗，取消时不进入导出。
void main() {
  late AppDatabase database;
  late String diaryId;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    diaryId = await database.createDiary(
      title: '春日小记',
      contentDocJson: '[{"insert":"看花\\n"}]',
      contentText: '看花',
      metadataJson: '{}',
    );
  });
  tearDown(() => database.close());

  testWidgets(
    'the More menu exports a diary file behind an optional password',
    (tester) async {
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

      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      expect(find.text('导出为 PDF'), findsOneWidget);
      await tester.tap(find.text('导出为日记文件'));
      await tester.pumpAndSettle();

      // 与完整备份导出同一个密码弹窗，确认键换成“导出”。
      expect(find.text('设置导出密码（可选）'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '导出'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(find.text('设置导出密码（可选）'), findsNothing);
      expect(
        tester
            .widget<ActionLoadingOverlay>(find.byType(ActionLoadingOverlay))
            .visible,
        isFalse,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
