import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_media_cleanup_service.dart';
import 'package:node_diary/core/services/diary_media_sweeper.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'expressive_test_theme.dart';

/// 草稿箱相关页面测试的公共环境：内存 drift 库、真实设置服务、记录回收
/// 次数的假媒体清理（不碰文件系统与 isolate）。
///
/// drift 写入在 widget 测试的假时钟下要经 `tester.runAsync`，[seed] /
/// [drafts] 已包好；页面卸载后调用 [unmount]，否则 drift 的计时器会触发
/// “Timer is still pending”。
class DiaryDraftsHarness {
  DiaryDraftsHarness._(this.tester, this.database, this.settings);

  final WidgetTester tester;
  final AppDatabase database;
  final SettingsService settings;
  final FakeDiaryMediaCleanupService mediaCleanup =
      FakeDiaryMediaCleanupService();

  static Future<DiaryDraftsHarness> create(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    return DiaryDraftsHarness._(tester, database, settings);
  }

  /// 写入一份只有标题与纯文本的草稿，返回它的 id。
  Future<String> seed(
    String title, {
    String contentText = '',
    required DateTime updatedAt,
  }) async {
    final snapshot = NewDiaryDraft(
      title: title,
      contentDocJson: '',
      contentText: contentText,
    ).toSnapshot();
    return (await tester.runAsync(
      () => database.saveDiaryDraft(
        title: snapshot.title,
        contentText: snapshot.contentText,
        payload: snapshot.payload,
        now: updatedAt,
      ),
    ))!;
  }

  Future<List<DiaryDraftRow>> drafts() async =>
      (await tester.runAsync(() => database.watchDiaryDrafts().first))!;

  /// 离开假时钟让 drift 的读写与数据流推送完成，再补几帧。
  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  /// [overrides] 追加在公共 override 之后（如假的相册）。
  Future<void> pump(Widget home, {List<Override> overrides = const []}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
          diaryMediaCleanupServiceProvider.overrideWithValue(mediaCleanup),
          ...overrides,
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await settle();
  }

  AppLocalizations get l10n => lookupAppLocalizations(const Locale('zh'));

  Future<void> unmount() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
}

/// 只记录回收次数的媒体清理服务。
class FakeDiaryMediaCleanupService extends Fake
    implements DiaryMediaCleanupService {
  int sweeps = 0;

  @override
  Future<DiaryMediaSweepReport?> sweep() async {
    sweeps++;
    return null;
  }

  @override
  void scheduleStartupSweep() {}

  @override
  void dispose() {}
}
