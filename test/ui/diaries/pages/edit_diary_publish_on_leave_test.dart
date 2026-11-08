import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_create_prefs.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 新建页“返回时直接发表”（#196）：打开后按返回直接写成日记、删掉草稿，
/// 不经发布页；没写东西照常离开；带胶囊的经发布页；写库失败时留在草稿箱。
/// 默认（关闭）时返回照旧存进草稿箱。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  Object? openerResult;

  Future<void> setUpStores(
    WidgetTester tester, {
    bool publishOnLeave = true,
    AppDatabase? db,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = db ?? AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    settings = await SettingsService.create();
    if (publishOnLeave) {
      await settings.setDiaryCreatePrefsRaw(
        const DiaryCreatePrefs(
          leaveAction: DiaryCreateLeaveAction.publish,
        ).encode(),
      );
    }
    openerResult = null;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<String> seedDraft(
    WidgetTester tester,
    String title, {
    DateTime? capsuleUnlockAt,
  }) async {
    final snapshot = NewDiaryDraft(
      title: title,
      contentDocJson: '',
      contentText: '',
      capsuleUnlockAt: capsuleUnlockAt,
      capsulePrecision: capsuleUnlockAt == null ? null : 'date',
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

  /// 打开者页面 → 新建编辑页；编辑页退场时的结果记在 [openerResult]。
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
                onPressed: () async {
                  openerResult = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute<Object?>(
                      builder: (_) => EditDiaryPage(
                        entryMode: EditDiaryEntryMode.create,
                        createDraftId: draftId,
                      ),
                    ),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await settle(tester);
  }

  Finder titleField() => find.byType(TextField).first;

  Future<List<DiaryDraftRow>> drafts(WidgetTester tester) async =>
      (await tester.runAsync(() => database.watchDiaryDrafts().first))!;

  Future<List<DiaryWithTags>> diaries(WidgetTester tester) async =>
      (await tester.runAsync(() => database.watchDiaries().first))!;

  Future<void> goBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  testWidgets('going back publishes the new diary and drops its draft', (
    tester,
  ) async {
    await setUpStores(tester);
    await openEditor(tester);

    await tester.enterText(titleField(), 'Straight to the list');
    // 防抖窗口里就返回：草稿可能已经写了一份，发表后一并删掉。
    await tester.pump(const Duration(milliseconds: 1400));
    await settle(tester);
    expect((await drafts(tester)).single.title, 'Straight to the list');

    await goBack(tester);
    expect(find.byType(EditDiaryPage), findsNothing);
    expect(find.byType(PublishDiaryPage), findsNothing);
    final rows = await diaries(tester);
    expect(rows.single.diary.title, 'Straight to the list');
    // 与发布页退场一样，以新日记 id 回到打开者（列表据此播放出现动画）。
    expect(openerResult, rows.single.diary.diaryId);
    expect(await drafts(tester), isEmpty);
    await unmount(tester);
  });

  testWidgets('continuing a draft and going back publishes that draft', (
    tester,
  ) async {
    await setUpStores(tester);
    final target = await seedDraft(tester, 'Half written');
    await seedDraft(tester, 'Someone else');
    await openEditor(tester, draftId: target);
    expect(find.text('Half written'), findsOneWidget);

    await goBack(tester);
    expect(find.byType(EditDiaryPage), findsNothing);
    expect((await diaries(tester)).single.diary.title, 'Half written');
    expect((await drafts(tester)).single.title, 'Someone else');
    await unmount(tester);
  });

  testWidgets('an empty new entry just leaves without a diary or a draft', (
    tester,
  ) async {
    await setUpStores(tester);
    await openEditor(tester);

    await goBack(tester);
    expect(find.byType(EditDiaryPage), findsNothing);
    expect(await diaries(tester), isEmpty);
    expect(await drafts(tester), isEmpty);
    expect(openerResult, isNull);
    await unmount(tester);
  });

  testWidgets('with the setting off going back keeps the draft', (
    tester,
  ) async {
    await setUpStores(tester, publishOnLeave: false);
    await openEditor(tester);

    await tester.enterText(titleField(), 'Keep me as a draft');
    await tester.pump(const Duration(milliseconds: 200));
    await goBack(tester);
    expect(find.byType(EditDiaryPage), findsNothing);
    expect(await diaries(tester), isEmpty);
    expect((await drafts(tester)).single.title, 'Keep me as a draft');
    await unmount(tester);
  });

  testWidgets('a time capsule goes through the publish page to be sealed', (
    tester,
  ) async {
    await setUpStores(tester);
    final id = await seedDraft(
      tester,
      'Open me next year',
      capsuleUnlockAt: DateTime.now().add(const Duration(days: 365)),
    );
    await openEditor(tester, draftId: id);

    await goBack(tester);
    // 与点“发表”一样进了发布页（进入即发表，返回时播放封存卡片）。
    expect(find.byType(PublishDiaryPage), findsOneWidget);
    final rows = await diaries(tester);
    expect(rows.single.diary.title, 'Open me next year');
    expect(rows.single.diary.capsuleUnlockAt, isNotNull);
    await unmount(tester);
  });

  testWidgets('a failed publish leaves the entry in drafts and says so', (
    tester,
  ) async {
    await setUpStores(
      tester,
      db: _FailingCreateDatabase(NativeDatabase.memory()),
    );
    await openEditor(tester);

    await tester.enterText(titleField(), 'Disk is full');
    await tester.pump(const Duration(milliseconds: 200));
    await goBack(tester);

    expect(find.byType(EditDiaryPage), findsNothing);
    expect(
      find.text("Couldn't publish the diary. It's kept in Drafts."),
      findsOne,
    );
    expect(await diaries(tester), isEmpty);
    expect((await drafts(tester)).single.title, 'Disk is full');
    await unmount(tester);
  });
}

/// 新建日记一律失败的库（草稿照常写）。
class _FailingCreateDatabase extends AppDatabase {
  _FailingCreateDatabase(super.executor) : super.forTesting();

  @override
  Future<String> createDiary({
    required String title,
    required String contentDocJson,
    required String contentText,
    required String metadataJson,
    String? cover,
    List<int> tagIds = const <int>[],
    DateTime? createdAtOverride,
    DateTime? capsuleUnlockAt,
    DateTime? capsuleLockedAt,
    List<String>? notebookIds,
    Map<String, String> notebookChapterIds = const <String, String>{},
  }) async {
    throw StateError('disk full');
  }
}
