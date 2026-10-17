import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/soft_keyboard_keys.dart';

/// 编辑页正文与手机键盘的配合：软键盘“选择”模式能扩展正文选区。
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
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
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
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EditDiaryPage(
            entryMode: EditDiaryEntryMode.create,
            restoreCreateDraft: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  quill.QuillController bodyController(WidgetTester tester) => tester
      .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
      .controller;

  testWidgets('soft keyboard select mode extends the body selection', (
    tester,
  ) async {
    await pumpCreatePage(tester);
    final controller = bodyController(tester);
    controller.replaceText(0, 0, 'hello world', null);
    controller.updateSelection(
      const TextSelection.collapsed(offset: 11),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await sendSoftKeyboardKey(
      tester,
      SoftKeyboardKey.arrowLeft,
      selecting: true,
    );
    await sendSoftKeyboardKey(
      tester,
      SoftKeyboardKey.arrowLeft,
      selecting: true,
    );
    expect(
      controller.selection,
      const TextSelection(baseOffset: 11, extentOffset: 9),
    );

    // 关掉“选择”后方向键回到移动光标。
    await sendSoftKeyboardKey(tester, SoftKeyboardKey.arrowRight);
    expect(controller.selection.isCollapsed, isTrue);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
