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
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

/// 日历“写给这一天的时间胶囊”：编辑页带着预设解封日打开，发布后即为在
/// 该日零点解封的胶囊，发表时间同为解封时间；从发布页返回时播放封存卡片。
void main() {
  testWidgets(
    'a preset unlock day publishes a capsule for that day',
    (tester) => _publishPresetCapsule(tester),
  );

  testWidgets(
    'back while the capsule is sealing is ignored',
    (tester) => _publishPresetCapsule(tester, pressBackWhileSealing: true),
  );
}

Future<void> _publishPresetCapsule(
  WidgetTester tester, {
  bool pressBackWhileSealing = false,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  final now = DateTime.now();
  final unlockDay = DateTime(now.year, now.month, now.day + 10);
  final results = <Object?>[];

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
              onPressed: () async {
                final result = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(
                    builder: (_) => EditDiaryPage(
                      entryMode: EditDiaryEntryMode.create,
                      createDateOverride: unlockDay,
                      // 带时分的值也按“日期”精度归一到当天零点。
                      createCapsuleUnlockAt: unlockDay.add(
                        const Duration(hours: 15, minutes: 30),
                      ),
                    ),
                  ),
                );
                results.add(result);
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

  await tester.enterText(find.byType(TextField).first, 'Dear future me');
  await tester.pump();
  final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
  await tester.tap(find.byTooltip(l10n.autoT0136));
  await tester.pump();
  // 进入发布页即发表：日记一写进库就是胶囊。
  await PublishPanelDriver(tester).waitUntilPublished();
  await tester.pumpAndSettle();
  expect(find.byType(PublishDiaryPage), findsOneWidget);
  final published = (await tester.runAsync(
    () => database.select(database.diaries).get(),
  ))!.single;
  expect(published.capsuleUnlockAt, unlockDay);
  expect(results, isEmpty);

  // 返回时播放封存卡片再退场；补存是真实异步，离开假时钟推进。
  await tester.binding.handlePopRoute();
  var pressedBack = false;
  for (var i = 0; i < 60 && results.isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    // 封存卡片停留期间再按返回：忽略，不会重复退场。
    if (pressBackWhileSealing &&
        !pressedBack &&
        find.text(l10n.timeCapsuleSealing).evaluate().isNotEmpty) {
      pressedBack = true;
      // 封存中面板锁定，改动不会再保存。
      final lock = tester.widget<AbsorbPointer>(
        find
            .ancestor(
              of: find.byType(PublishDiaryPanel),
              matching: find.byType(AbsorbPointer),
            )
            .first,
      );
      expect(lock.absorbing, isTrue);
      await tester.binding.handlePopRoute();
    }
  }
  expect(pressedBack, pressBackWhileSealing);
  await tester.pumpAndSettle();

  expect(results, hasLength(1));
  final stored = await tester.runAsync(
    () => database.getDiaryWithTagsByDiaryId(results.single! as String),
  );
  expect(stored?.diary.capsuleUnlockAt, unlockDay);
  expect(stored?.diary.capsuleLockedAt, isNotNull);
  expect(stored?.diary.createdAt, unlockDay);
  expect(find.byType(EditDiaryPage, skipOffstage: false), findsNothing);

  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}
