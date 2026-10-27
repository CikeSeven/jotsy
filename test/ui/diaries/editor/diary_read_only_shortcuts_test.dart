import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/widgets/desktop_page_arrows.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  late SettingsService settings;
  late DiaryEditorController controller;
  String? copied;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.create();
    controller = DiaryEditorController.fromContent(
      'copy me\nnext line',
      readOnly: true,
    );
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });
  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester, {
    bool selectable = true,
    VoidCallback? onNext,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DesktopPageKeys(
              onNext: onNext,
              child: SingleChildScrollView(
                child: DiaryEditor(
                  controller: controller,
                  appearance: const DiaryTextAppearance(
                    typography: DiaryTypography(),
                  ),
                  shrinkWrap: true,
                  textSelection: selectable,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shortcut(WidgetTester tester, LogicalKeyboardKey key) async {
    final modifier = AppPlatform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'selecting readonly text enables copy and select all without '
    'connecting an input method or changing the document',
    (tester) async {
      await pump(tester);
      final original = controller.contentJson;
      controller.select(
        af.Selection.single(path: [0], startOffset: 0, endOffset: 4),
      );
      await tester.pump();
      await shortcut(tester, LogicalKeyboardKey.keyC);
      expect(copied, 'copy');
      expect(tester.testTextInput.hasAnyClients, isFalse);

      await shortcut(tester, LogicalKeyboardKey.keyA);
      await shortcut(tester, LogicalKeyboardKey.keyC);
      expect(copied, 'copy me\nnext line');
      await shortcut(tester, LogicalKeyboardKey.keyX);
      await shortcut(tester, LogicalKeyboardKey.keyV);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      expect(controller.contentJson, original);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('readonly shortcuts leave paging keys to the page', (
    tester,
  ) async {
    var pages = 0;
    await pump(tester, onNext: () => pages++);
    controller.select(
      af.Selection.single(path: [0], startOffset: 0, endOffset: 4),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(pages, 1);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('disabled text selection does not offer keyboard copying', (
    tester,
  ) async {
    await pump(tester, selectable: false);
    controller.select(
      af.Selection.single(path: [0], startOffset: 0, endOffset: 4),
    );
    await tester.pump();
    await shortcut(tester, LogicalKeyboardKey.keyC);
    expect(copied, isNull);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
