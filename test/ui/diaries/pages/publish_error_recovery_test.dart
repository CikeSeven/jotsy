import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

/// 出错提示一出现，对应的加载/发布状态就要复位：提示条要显示约 4 秒，
/// 不能让按钮在这段时间里一直转圈或停用。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
  });
  tearDown(() => database.close());

  Future<void> openRoute(WidgetTester tester, WidgetBuilder builder) async {
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
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push<Object?>(MaterialPageRoute(builder: builder)),
                child: const Text('Open route'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();
  }

  /// 让真实异步（平台通道、写库）推进，直到提示条出现。
  Future<void> waitForSnackBar(WidgetTester tester) async {
    for (var i = 0; i < 20 && find.byType(SnackBar).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(SnackBar), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  // 测试环境没有天气配置：请求以“缺少配置”失败。
  const locatedDraft = NewDiaryDraft(
    title: 'A walk',
    contentDocJson: '[{"insert":"A walk\\n"}]',
    contentText: 'A walk',
    location: 'Park',
    locationFromAuto: true,
    locationLatitude: 39.98941,
    locationLongitude: 116.480881,
  );

  /// 打开发布页，等进入即发表完成，并让“已发表”提示条播完退场，后面的
  /// 提示条才是本次操作的结果。
  Future<void> openPublisher(WidgetTester tester) async {
    await openRoute(
      tester,
      (_) => const PublishDiaryPage(initialDraft: locatedDraft),
    );
    await PublishPanelDriver(tester).waitUntilPublished();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  }

  testWidgets('a weather error releases the publish page weather button', (
    tester,
  ) async {
    await openPublisher(tester);
    final panel = PublishPanelDriver(tester);

    panel.resolveWeather();
    await tester.pump();
    expect(panel.weatherLoading, isTrue);
    await waitForSnackBar(tester);
    expect(panel.weatherLoading, isFalse);
    // 服务层的中文诊断不直接出现在界面上。
    expect(find.text(panel.l10n.autoT0205), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a failed save on leaving keeps the page and unlocks it', (
    tester,
  ) async {
    await openPublisher(tester);
    await tester.runAsync(
      () => database.customStatement('''
        CREATE TRIGGER reject_diary_update BEFORE UPDATE ON diaries
        BEGIN SELECT RAISE(ABORT, 'disk unavailable'); END;
      '''),
    );
    final panel = PublishPanelDriver(tester);

    panel.setMood('🙂');
    await tester.binding.handlePopRoute();
    await waitForSnackBar(tester);
    expect(panel.busy, isFalse);
    // 原始异常（SQL 错误）只写调试日志，界面给可读的本地化提示。
    expect(find.text(panel.l10n.publishSaveFailed), findsOneWidget);
    expect(find.textContaining('disk unavailable'), findsNothing);
    expect(find.byType(PublishDiaryPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a weather error releases the edit page weather button', (
    tester,
  ) async {
    final diaryId = await tester.runAsync(
      () => database.createDiary(
        title: 'Located',
        contentDocJson: '[{"insert":"Located\\n"}]',
        contentText: 'Located',
        metadataJson:
            '{"context":{"location":"Park","geo":{"source":"amap_auto",'
            '"latitude":39.98941,"longitude":116.480881}}}',
      ),
    );
    await openRoute(tester, (_) => EditDiaryPage(diaryId: diaryId));
    final panel = PublishPanelDriver(tester);

    panel.resolveWeather();
    await tester.pump();
    expect(panel.weatherLoading, isTrue);
    await waitForSnackBar(tester);
    expect(panel.weatherLoading, isFalse);
    await unmount(tester);
  });
}
