import 'dart:ui' show AppExitResponse;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.create();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    diaryId = await database.createDiary(
      title: 'Original title',
      contentDocJson: 'Original body',
      contentText: 'Original body',
      metadataJson: '{}',
    );
  });
  tearDown(() => database.close());

  final desktops = TargetPlatformVariant({
    TargetPlatform.linux,
    TargetPlatform.windows,
  });

  Future<void> open(WidgetTester tester, {bool create = false}) async {
    tester.view.physicalSize = const Size(1280, 900);
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
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: create
              ? const EditDiaryPage(entryMode: EditDiaryEntryMode.create)
              : EditDiaryPage(diaryId: diaryId),
        ),
      ),
    );
    // 桌面工具栏与光标不会停止重绘；固定帧数等详情回填，不等光标闪烁结束。
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<AppExitResponse> closeRequest(WidgetTester tester) async =>
      (await tester.runAsync(tester.binding.handleRequestAppExit))!;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('closing immediately after typing saves the title and body '
      'before exit is allowed', (tester) async {
    await open(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Original title'),
      'Last title',
    );
    final editor = tester
        .widget<DiaryEditor>(find.byType(DiaryEditor))
        .controller;
    final node = editor.document.root.children.first;
    editor.apply(
      editor.state.transaction..insertText(node, node.delta!.length, ' latest'),
    );
    expect(await closeRequest(tester), AppExitResponse.exit);
    final saved = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!;
    expect(saved.diary.title, 'Last title');
    expect(saved.diary.contentText, 'Original body latest');
    await unmount(tester);
  }, variant: desktops);

  testWidgets('a failed save cancels closing and preserves input for a retry', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Original title'),
      'Keep my input',
    );
    await tester.runAsync(
      () => database.customStatement('PRAGMA query_only = ON'),
    );
    expect(await closeRequest(tester), AppExitResponse.cancel);
    expect(find.widgetWithText(TextField, 'Keep my input'), findsOneWidget);
    await tester.runAsync(
      () => database.customStatement('PRAGMA query_only = OFF'),
    );
    expect(await closeRequest(tester), AppExitResponse.exit);
    final saved = (await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(diaryId),
    ))!;
    expect(saved.diary.title, 'Keep my input');
    await unmount(tester);
  }, variant: desktops);

  testWidgets(
    'closing a new diary saves its draft before the debounce expires',
    (tester) async {
      await open(tester, create: true);
      await tester.enterText(
        find.byType(TextField).first,
        'Unpublished last title',
      );
      expect(await closeRequest(tester), AppExitResponse.exit);
      final drafts = (await tester.runAsync(
        () => database.getRecentDiaryDrafts(10),
      ))!;
      expect(drafts, hasLength(1));
      expect(drafts.single.title, 'Unpublished last title');
      expect(await closeRequest(tester), AppExitResponse.exit);
      expect((await tester.runAsync(database.countDiaryDrafts))!, 1);
      await unmount(tester);
    },
    variant: desktops,
  );
}
