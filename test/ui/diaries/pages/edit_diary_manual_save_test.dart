import 'dart:convert';
import 'dart:ui' show AppExitResponse;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/diary_content_test_helpers.dart';
import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

/// 设置为“手动保存修改”时编辑已有日记：改动不写库，顶栏“保存”（桌面
/// Ctrl + S）才写；有未保存的修改时返回先问“取消 / 退出 / 保存并退出”，
/// 没改过时照常直接返回；切后台、被盖住都不写，别处的修改不会冲掉没存的
/// 内容。
///
/// 标题拿到焦点后光标闪烁，pumpAndSettle 等不到静止，这里一律固定帧数。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    await settings.setDiaryEditPrefsRaw('{"save":"manual"}');
    diaryId = await database.createDiary(
      title: 'Original title',
      contentDocJson: '[{"insert":"Original body\\n"}]',
      contentText: 'Original body',
      metadataJson: '{}',
    );
  });
  tearDown(() => database.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openEditor(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(brightness),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => EditDiaryPage(diaryId: diaryId),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await settle(tester);
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      tester.element(find.byType(EditDiaryPage)).l10n;

  Finder saveButton(WidgetTester tester, {bool saved = false}) => find.ancestor(
    of: find.byTooltip(
      saved ? l10nOf(tester).diaryEditSaved : l10nOf(tester).commonSave,
    ),
    matching: find.byType(IconButton),
  );

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(saveButton(tester)).onPressed != null;

  Finder titleField() => find.widgetWithText(TextField, 'Original title');

  Future<void> typeTitle(WidgetTester tester, String text) async {
    await tester.enterText(titleField(), text);
    // 远超防抖（500ms）：手动保存时也不能写库。
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<DiaryWithTags> storedDiary(WidgetTester tester) async => (await tester
      .runAsync(() => database.getDiaryWithTagsByDiaryId(diaryId)))!;

  Finder dialogButton(String label) =>
      find.widgetWithText(TextButton, label).last;

  Future<void> back(WidgetTester tester, {required bool systemBack}) async {
    if (systemBack) {
      await tester.binding.handlePopRoute();
    } else {
      await tester.tap(find.byTooltip(l10nOf(tester).commonBack));
    }
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  for (final brightness in Brightness.values) {
    testWidgets('edits wait for the save button in ${brightness.name} theme', (
      tester,
    ) async {
      await openEditor(tester, brightness: brightness);
      final l10n = l10nOf(tester);
      expect(saveButton(tester), findsOneWidget);
      expect(saveEnabled(tester), isFalse);

      await typeTitle(tester, 'Saved by hand');
      expect((await storedDiary(tester)).diary.title, 'Original title');
      expect(saveEnabled(tester), isTrue);

      await tester.tap(saveButton(tester));
      await tester.pump();
      await tester.pump();
      expect((await storedDiary(tester)).diary.title, 'Saved by hand');
      await tester.pump(const Duration(milliseconds: 300));
      // 保存成功：对勾（主色）停留 1 秒再换回停用的保存按钮。
      expect(saveButton(tester, saved: true), findsOneWidget);
      final check = tester.widget<FaIcon>(
        find.descendant(
          of: saveButton(tester, saved: true),
          matching: find.byType(FaIcon),
        ),
      );
      expect(
        check.color,
        Theme.of(
          tester.element(saveButton(tester, saved: true)),
        ).colorScheme.primary,
      );
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(saveButton(tester), findsOneWidget);
      expect(saveEnabled(tester), isFalse);

      // 存过之后返回不再询问。
      await back(tester, systemBack: false);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(EditDiaryPage), findsNothing);
      expect(find.text(l10n.autoT0207), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  for (final systemBack in [false, true]) {
    final how = systemBack ? 'system' : 'toolbar';
    testWidgets('$how back with unsaved edits asks; cancel stays, '
        'exit discards them', (tester) async {
      await openEditor(tester);
      final l10n = l10nOf(tester);
      await typeTitle(tester, 'Not kept');

      await back(tester, systemBack: systemBack);
      expect(find.text(l10n.autoT0131), findsOneWidget);
      expect(find.text(l10n.autoT0207), findsOneWidget);
      // 对话框按钮规范：取消灰色、退出 error 色、保存并退出主色。
      final scheme = Theme.of(
        tester.element(find.byType(AlertDialog)),
      ).colorScheme;
      Color? colorOf(String label) => tester
          .widget<TextButton>(dialogButton(label))
          .style
          ?.foregroundColor
          ?.resolve(<WidgetState>{});
      expect(colorOf(l10n.commonCancel), scheme.onSurfaceVariant);
      expect(colorOf(l10n.autoT0132), scheme.error);
      expect(colorOf(l10n.editSaveAndExit), scheme.primary);

      await tester.tap(dialogButton(l10n.commonCancel));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(EditDiaryPage), findsOneWidget);
      expect(find.text('Not kept'), findsOneWidget);
      expect((await storedDiary(tester)).diary.title, 'Original title');

      await back(tester, systemBack: systemBack);
      await tester.tap(dialogButton(l10n.autoT0132));
      await settle(tester);
      expect(find.byType(EditDiaryPage), findsNothing);
      expect(find.text('Open editor'), findsOneWidget);
      expect((await storedDiary(tester)).diary.title, 'Original title');
      await unmount(tester);
    });
  }

  testWidgets('save and exit writes the edits, then leaves', (tester) async {
    await openEditor(tester);
    final l10n = l10nOf(tester);
    await typeTitle(tester, 'Kept on exit');
    await back(tester, systemBack: true);
    await tester.tap(dialogButton(l10n.editSaveAndExit));
    await settle(tester);
    expect((await storedDiary(tester)).diary.title, 'Kept on exit');
    expect(find.byType(EditDiaryPage), findsNothing);
    await unmount(tester);
  });

  testWidgets('back without changes leaves without asking', (tester) async {
    await openEditor(tester);
    final before = await storedDiary(tester);
    // 只把光标放进标题、移动一下：不是修改。
    await tester.tap(titleField());
    await tester.pump(const Duration(milliseconds: 400));
    expect(saveEnabled(tester), isFalse);

    await back(tester, systemBack: false);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(EditDiaryPage), findsNothing);
    final after = await storedDiary(tester);
    expect(after.diary.updatedAt, before.diary.updatedAt);
    await unmount(tester);
  });

  testWidgets('typing back the original text needs no save', (tester) async {
    await openEditor(tester);
    await typeTitle(tester, 'Changed');
    expect(saveEnabled(tester), isTrue);
    await tester.enterText(
      find.widgetWithText(TextField, 'Changed'),
      'Original title',
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(saveEnabled(tester), isFalse);
    await back(tester, systemBack: true);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(EditDiaryPage), findsNothing);
    await unmount(tester);
  });

  testWidgets('panel edits wait for saving too', (tester) async {
    await openEditor(tester);
    final l10n = l10nOf(tester);
    final panel = PublishPanelDriver(tester);
    await panel.open();
    panel.setMood('🙂');
    await tester.pump(const Duration(milliseconds: 700));
    final metadata = jsonDecode((await storedDiary(tester)).diary.metadata);
    expect((metadata as Map)['context'], isNull);
    expect(saveEnabled(tester), isTrue);

    // 先收起面板，再询问。
    await back(tester, systemBack: true);
    await back(tester, systemBack: true);
    expect(find.text(l10n.autoT0207), findsOneWidget);
    await tester.tap(dialogButton(l10n.editSaveAndExit));
    await settle(tester);
    final saved = jsonDecode((await storedDiary(tester)).diary.metadata) as Map;
    expect((saved['context'] as Map)['moodEmoji'], '🙂');
    await unmount(tester);
  });

  testWidgets('going to the background or opening a page does not save', (
    tester,
  ) async {
    await openEditor(tester);
    await typeTitle(tester, 'Unsaved draft');
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect((await storedDiary(tester)).diary.title, 'Original title');
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }

    final navigator = Navigator.of(tester.element(find.byType(EditDiaryPage)));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covering page')),
      ),
    );
    await settle(tester);
    expect((await storedDiary(tester)).diary.title, 'Original title');
    navigator.pop();
    await settle(tester);
    expect(find.text('Unsaved draft'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a change made elsewhere does not wipe unsaved edits', (
    tester,
  ) async {
    await openEditor(tester);
    final l10n = l10nOf(tester);
    await typeTitle(tester, 'Mine, not saved');

    final navigator = Navigator.of(tester.element(find.byType(EditDiaryPage)));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covering page')),
      ),
    );
    await settle(tester);
    await tester.runAsync(
      () => database.updateDiary(
        diaryId: diaryId,
        title: 'Changed elsewhere',
        contentDocJson: '[{"insert":"Other body\\n"}]',
        contentText: 'Other body',
        metadataJson: '{}',
        tagIds: const <int>[],
      ),
    );
    navigator.pop();
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester);
    expect(find.text('Mine, not saved'), findsOneWidget);
    expect(find.text(l10n.diaryReadingReloaded), findsNothing);
    await unmount(tester);
  });

  testWidgets('a failed save keeps the edits and stays on the page', (
    tester,
  ) async {
    await openEditor(tester);
    final l10n = l10nOf(tester);
    await tester.runAsync(
      () => database.customStatement('''
        CREATE TRIGGER reject_diary_update BEFORE UPDATE ON diaries
        BEGIN SELECT RAISE(ABORT, 'disk unavailable'); END;
      '''),
    );
    await typeTitle(tester, 'Keep this input');
    await back(tester, systemBack: false);
    await tester.tap(dialogButton(l10n.editSaveAndExit));
    await settle(tester);
    expect(find.byType(EditDiaryPage), findsOneWidget);
    expect(find.text('Keep this input'), findsOneWidget);
    expect(find.textContaining('Save failed:'), findsOneWidget);
    expect(saveEnabled(tester), isTrue);
    expect((await storedDiary(tester)).diary.title, 'Original title');

    await tester.runAsync(
      () => database.customStatement('DROP TRIGGER reject_diary_update'),
    );
    await tester.tap(saveButton(tester));
    await settle(tester);
    expect((await storedDiary(tester)).diary.title, 'Keep this input');
    await unmount(tester);
  });

  testWidgets('switching back to automatic saving writes the edits', (
    tester,
  ) async {
    await openEditor(tester);
    await typeTitle(tester, 'Now automatic');
    expect((await storedDiary(tester)).diary.title, 'Original title');

    // 不经 runAsync：切换时排下的自动保存计时器要在测试的假时钟里。
    await settings.setDiaryEditPrefsRaw(null);
    await tester.pump();
    expect(saveButton(tester), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    expect((await storedDiary(tester)).diary.title, 'Now automatic');
    await unmount(tester);
  });

  testWidgets('automatic saving shows no save button', (tester) async {
    await settings.setDiaryEditPrefsRaw(null);
    await openEditor(tester);
    expect(saveButton(tester), findsNothing);
    await unmount(tester);
  });

  testWidgets(
    'desktop: Ctrl+S saves and closing the window with unsaved edits asks',
    (tester) async {
      await openEditor(tester, size: const Size(1280, 900));
      final l10n = l10nOf(tester);
      await typeTitle(tester, 'Saved with keys');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect((await storedDiary(tester)).diary.title, 'Saved with keys');
      expect(find.text('Saved with keys'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Saved with keys'),
        'Closing',
      );
      await tester.pump(const Duration(milliseconds: 400));
      var exit = tester.binding.handleRequestAppExit();
      await settle(tester);
      expect(find.text(l10n.autoT0207), findsOneWidget);
      await tester.tap(dialogButton(l10n.commonCancel));
      await settle(tester);
      expect(await exit, AppExitResponse.cancel);
      expect((await storedDiary(tester)).diary.title, 'Saved with keys');

      exit = tester.binding.handleRequestAppExit();
      await settle(tester);
      await tester.tap(dialogButton(l10n.editSaveAndExit));
      await settle(tester);
      expect(await exit, AppExitResponse.exit);
      expect((await storedDiary(tester)).diary.title, 'Closing');
      await unmount(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('desktop: Ctrl+S also saves while typing in the body', (
    tester,
  ) async {
    await openEditor(tester, size: const Size(1280, 900));
    final editor = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
    editor.focusNode!.requestFocus();
    await settle(tester);
    final content = editor.controller;
    // 焦点在正文编辑器里（不是标题）：快捷键要能从编辑器冒泡上来。
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<DiaryEditor>(),
      isNotNull,
    );
    content.replaceText(
      0,
      content.document.length - 1,
      'Body by hand',
      const TextSelection.collapsed(offset: 12),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect((await storedDiary(tester)).diary.contentText, 'Original body');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect((await storedDiary(tester)).diary.contentText, 'Body by hand');
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
