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

void main() {
  testWidgets('a new diary focuses its body only after the page slid in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const EditDiaryPage(
                      entryMode: EditDiaryEntryMode.create,
                      restoreCreateDraft: false,
                    ),
                  ),
                ),
                child: const Text('New'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('New'));
    await tester.pump();
    bool bodyFocused() => tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .focusNode
        .hasFocus;

    // 页面仍在滑入：此时聚焦会让键盘与转场同时弹出、逐帧挤压布局。
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(bodyFocused(), isFalse, reason: 'frame $frame');
    }
    await tester.pumpAndSettle();
    expect(bodyFocused(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
