import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 新建日记与草稿箱：每次新建是独立的一份草稿，续写只改那一份，离开时
/// 不等防抖也会落盘。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  Future<void> setUpStores(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    settings = await SettingsService.create();
  }

  Future<String> seedDraft(
    WidgetTester tester,
    String title, {
    Set<int> tagIds = const <int>{},
  }) async {
    final snapshot = NewDiaryDraft(
      title: title,
      contentDocJson: '',
      contentText: '',
      selectedTagIds: tagIds,
    ).toSnapshot();
    return (await tester.runAsync(
      () => database.saveDiaryDraft(
        title: snapshot.title,
        contentText: snapshot.contentText,
        payload: snapshot.payload,
        now: DateTime(2026, 10, 1, 8),
      ),
    ))!;
  }

  Future<List<DiaryDraftRow>> drafts(WidgetTester tester) async {
    return (await tester.runAsync(() => database.watchDiaryDrafts().first))!;
  }

  /// 打开者页面 → 新建编辑页（[draftId] 不为 null 时续写那一份）。
  Future<void> openEditor(WidgetTester tester, {String? draftId}) async {
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
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(
                    builder: (_) => EditDiaryPage(
                      entryMode: EditDiaryEntryMode.create,
                      createDraftId: draftId,
                    ),
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
    await tester.pumpAndSettle();
    // 续写的草稿从数据库读出：离开假时钟等它填进标题栏。
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  Finder titleField() => find.byType(TextField).first;

  Future<void> waitForDebouncedSave(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  testWidgets('a new blank entry becomes its own draft beside older ones', (
    tester,
  ) async {
    await setUpStores(tester);
    final older = await seedDraft(tester, 'Older draft');
    await openEditor(tester);

    await tester.enterText(titleField(), 'Fresh entry');
    await waitForDebouncedSave(tester);

    final rows = await drafts(tester);
    expect(rows.map((row) => row.title), ['Fresh entry', 'Older draft']);
    expect(rows.last.draftId, older);
    await unmount(tester);
  });

  testWidgets('going back inside the debounce window still saves', (
    tester,
  ) async {
    await setUpStores(tester);
    await openEditor(tester);

    await tester.enterText(titleField(), 'Typed right before leaving');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(EditDiaryPage), findsNothing);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );

    final rows = await drafts(tester);
    expect(rows.single.title, 'Typed right before leaving');
    await unmount(tester);
  });

  testWidgets('continuing a draft updates only that draft', (tester) async {
    await setUpStores(tester);
    final target = await seedDraft(tester, 'Keep writing me');
    final other = await seedDraft(tester, 'Leave me alone');
    await openEditor(tester, draftId: target);
    expect(find.text('Keep writing me'), findsOneWidget);

    await tester.enterText(titleField(), 'Keep writing me, more');
    await waitForDebouncedSave(tester);

    final rows = {for (final row in await drafts(tester)) row.draftId: row};
    expect(rows.keys, unorderedEquals([target, other]));
    expect(rows[target]!.title, 'Keep writing me, more');
    expect(rows[other]!.title, 'Leave me alone');
    await unmount(tester);
  });

  testWidgets('opening a draft without editing keeps its edit time', (
    tester,
  ) async {
    await setUpStores(tester);
    final id = await seedDraft(tester, 'Just looking');
    await openEditor(tester, draftId: id);
    await waitForDebouncedSave(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );

    expect((await drafts(tester)).single.updatedAt, DateTime(2026, 10, 1, 8));
    await unmount(tester);
  });

  testWidgets('clearing a draft down to nothing removes it', (tester) async {
    await setUpStores(tester);
    final id = await seedDraft(tester, 'Remove me');
    await openEditor(tester, draftId: id);

    await tester.enterText(titleField(), '');
    await waitForDebouncedSave(tester);

    expect(await drafts(tester), isEmpty);
    await unmount(tester);
  });

  testWidgets('tags deleted since the draft was saved are dropped', (
    tester,
  ) async {
    await setUpStores(tester);
    final tagId = (await tester.runAsync(
      () => database.createTag(name: 'Trip', color: 0xff3366aa),
    ))!;
    final id = await seedDraft(tester, 'Tagged', tagIds: {tagId, 9999});
    await openEditor(tester, draftId: id);

    await tester.enterText(titleField(), 'Tagged, edited');
    await waitForDebouncedSave(tester);

    final payload =
        jsonDecode((await drafts(tester)).single.payload)
            as Map<String, Object?>;
    expect(payload['selectedTagIds'], [tagId]);
    await unmount(tester);
  });
}
