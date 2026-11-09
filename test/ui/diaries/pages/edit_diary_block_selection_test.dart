import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_block_actions/diary_block_action_bar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 编辑页装配段落选择模式：模式里键盘收起也显示段落操作栏（工具都被隐藏时
/// 同样），返回键先退出模式、不离开页面。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
  });
  tearDown(() => database.close());

  Future<void> pumpCreatePage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets(
    'the block action bar shows without a keyboard and with every tool '
    'hidden, and Back leaves the mode before the page',
    (tester) async {
      await settings.setDiaryToolbarHiddenItemsRaw(
        encodeDiaryToolbarHiddenItems(DiaryToolbarItem.values.toSet()),
      );
      await pumpCreatePage(tester);
      final controller = tester
          .widget<DiaryEditor>(find.byType(DiaryEditor))
          .controller;
      // 键盘收着：平时没有工具栏。
      expect(find.byType(DiaryBlockActionBar), findsNothing);

      controller.blockSelection.enter([
        controller.document.root.children.first,
      ], keyboardVisible: false);
      await tester.pumpAndSettle();
      expect(find.byType(DiaryBlockActionBar), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(controller.blockSelection.isActive, isFalse);
      expect(find.byType(EditDiaryPage), findsOneWidget);
      expect(find.byType(DiaryBlockActionBar), findsNothing);
      await unmount(tester);
    },
  );
}
