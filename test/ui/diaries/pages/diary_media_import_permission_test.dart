import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_media_import_controller.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  const gallery = MethodChannel('com.jotsy.diary/video_gallery');
  const camera = MethodChannel('com.jotsy.diary/camera_capture');

  testWidgets(
    'the toolbar camera menu keeps the editor focused and reports a refused '
    'camera permission',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = await SettingsService.create();
      final requests = <Object?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(camera, (call) async {
            requests.add(call.arguments);
            throw PlatformException(code: 'camera_permission_denied');
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(camera, null);
      });
      await _pumpEditPage(tester, database, settings, Brightness.light);
      final editor = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
      final original = editor.controller.contentJson;
      expect(editor.onCameraCommand, isNotNull);
      final focus = FocusManager.instance.primaryFocus;
      expect(focus, isNotNull);

      if (find.byTooltip('插入图片').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('更多工具'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('插入图片'));
      await tester.pumpAndSettle();
      // 打开菜单不抢焦点：正文仍在编辑，工具栏（菜单的锚点）不会卸载。
      expect(find.text('拍照'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(find.byType(DiaryFloatingToolbar), findsOneWidget);

      await tester.tap(find.text('拍照'));
      final importer = tester
          .widget<DiaryFloatingToolbar>(find.byType(DiaryFloatingToolbar))
          .mediaImportController!;
      // 菜单项的动作在下一帧执行；等这次拍摄开始后再等它结束。
      for (var i = 0; i < 10 && !importer.isBusy; i++) {
        await tester.pump();
      }
      expect(importer.isBusy, isTrue);
      await _waitUntilIdle(tester, importer);
      await tester.pumpAndSettle();

      expect(requests, [
        {'kind': 'image'},
      ]);
      final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
      expect(find.text(l10n.diaryMediaCameraPermissionDenied), findsOneWidget);
      expect(editor.controller.contentJson, original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  for (final brightness in Brightness.values) {
    for (final code in ['permission_denied', 'gallery_unavailable']) {
      testWidgets(
        '$brightness video import $code shows a hint and permits retry',
        (tester) async {
          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues({});
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          final settings = await SettingsService.create();
          var calls = 0;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(gallery, (_) async {
                if (calls++ == 0) throw PlatformException(code: code);
                return null;
              });
          addTearDown(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(gallery, null);
          });
          await _pumpEditPage(tester, database, settings, brightness);
          final editor = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
          final original = editor.controller.contentJson;
          await _requestVideo(tester);
          final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
          expect(
            find.text(
              code == 'permission_denied'
                  ? l10n.diaryMediaImportPermissionDenied
                  : l10n.diaryMediaPickerUnavailable,
            ),
            findsOneWidget,
          );
          expect(editor.controller.contentJson, original);
          await _requestVideo(tester);
          expect(calls, 2);
          expect(find.byType(EditDiaryPage), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }
  }
}

/// 新建编辑页，软键盘按弹起 240dp 模拟（工具栏随键盘出现）。
Future<void> _pumpEditPage(
  WidgetTester tester,
  AppDatabase database,
  SettingsService settings,
  Brightness brightness,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: Locale(brightness == Brightness.light ? 'zh' : 'en'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          af.AppFlowyEditorLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: const EdgeInsets.only(bottom: 240)),
          child: child!,
        ),
        home: const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 等一次已经开始的导入结束（取消订阅等在真实事件循环上完成）。
Future<void> _waitUntilIdle(
  WidgetTester tester,
  DiaryMediaImportController importer,
) async {
  await tester.runAsync(() async {
    if (!importer.isBusy) return;
    final idle = Completer<void>();
    void onChanged() {
      if (!importer.isBusy && !idle.isCompleted) idle.complete();
    }

    importer.addListener(onChanged);
    try {
      await idle.future.timeout(const Duration(seconds: 5));
    } finally {
      importer.removeListener(onChanged);
    }
  });
}

Future<void> _requestVideo(WidgetTester tester) async {
  final toolbar = tester.widget<DiaryFloatingToolbar>(
    find.byType(DiaryFloatingToolbar),
  );
  final importer = toolbar.mediaImportController!;
  // Stream cancellation can complete on the real event loop; pumping fake
  // animation frames alone does not guarantee that the import has finished.
  await tester.runAsync(() async {
    final idle = Completer<void>();
    void onChanged() {
      if (!importer.isBusy && !idle.isCompleted) idle.complete();
    }

    importer.addListener(onChanged);
    try {
      toolbar.onMediaPressed!(DiaryMediaKind.video);
      await idle.future.timeout(const Duration(seconds: 5));
    } finally {
      importer.removeListener(onChanged);
    }
  });
  await tester.pumpAndSettle();
}
