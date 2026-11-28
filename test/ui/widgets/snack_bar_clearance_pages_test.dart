import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_video_fullscreen_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_floating_toolbar_surface.dart';
import 'package:node_diary/ui/diary_templates/pages/diary_template_editor_page.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/mind_maps/pages/mind_map_editor_page.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_dock.dart';
import 'package:node_diary/ui/settings/pages/recycle_bin_page.dart';
import 'package:node_diary/ui/settings/widgets/recycle_bin_selection_bar.dart';
import 'package:node_diary/ui/todos/pages/todos_page.dart';
import 'package:node_diary/ui/todos/sections/todo_selection_bar.dart';
import 'package:node_diary/ui/widgets/keyboard_visibility.dart';
import 'package:node_diary/ui/widgets/snack_bar_clearance.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_video_player.dart';

void main() {
  Finder snackBarCard() => find
      .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
      .first;

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 50);
    for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
      await tester.pump(step);
    }
  }

  Future<void> settleDb(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('EditDiaryPage places SnackBar above the floating toolbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_toolbar_always_visible': true,
    });
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    final hintController = HomeHintVisibilityController();
    addTearDown(hintController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => KeyboardVisibility(
            child: HomeHintVisibilityScope(
              controller: hintController,
              child: child!,
            ),
          ),
          home: const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
        ),
      ),
    );
    await settleDb(tester);
    await tester.pumpAndSettle();

    final toolbarFinder = find.byType(DiaryFloatingToolbarSurface);
    expect(toolbarFinder, findsOneWidget);
    final toolbarTop = tester.getRect(toolbarFinder).top;

    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: tester.element(find.byType(EditDiaryPage)),
        snackBar: const SnackBar(
          content: Text('已复制'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final snackRect = tester.getRect(snackBarCard());
    expect(
      snackRect.bottom,
      lessThanOrEqualTo(toolbarTop - SnackBarClearanceHost.defaultGap + 1.0),
    );

    await pumpFor(tester, const Duration(seconds: 3));
    await unmount(tester);
  });

  for (final width in <double>[400, 1100]) {
    testWidgets(
      'TodosPage long-press delete SnackBar stays above TodoSelectionActionBar (width=$width)',
      (tester) async {
        tester.view.physicalSize = Size(width, 860);
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = FakeViewPadding(bottom: width < 600 ? 24 : 0);
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues(<String, Object>{
          'app.settings.app_features': '{"todos":true}',
        });
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final settings = await SettingsService.create();
        final today = DateTime.now();
        final localToday = DateTime(today.year, today.month, today.day);
        await tester.runAsync(() async {
          await database.createTodo(
            TodoInput(title: '任务甲', dueDate: localToday),
          );
          await database.createTodo(
            TodoInput(title: '任务乙', dueDate: localToday),
          );
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              settingsServiceProvider.overrideWith((ref) async => settings),
            ],
            child: const NodeDiaryApp(),
          ),
        );
        await pumpFor(tester, const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();

        final l10n = tester.element(find.byType(HomePage)).l10n;
        await tester.tap(find.text(l10n.navTodos));
        await settleDb(tester);
        await pumpFor(tester, const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        expect(find.byType(TodosPage), findsOneWidget);

        // 长按待办进入多选，记录底部操作栏的顶边。
        await tester.longPress(find.text('任务甲'));
        await pumpFor(tester, const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        final barFinder = find.byType(TodoSelectionActionBar);
        expect(barFinder, findsOneWidget);
        final actionBarTop = tester.getRect(barFinder).top;

        // 点操作栏里的删除：撤销提示条立即停在操作栏上方，不压住正在沉下的栏。
        await tester.tap(
          find.descendant(
            of: barFinder,
            matching: find.text(l10n.commonDelete),
          ),
        );
        await settleDb(tester);
        await pumpFor(tester, const Duration(milliseconds: 350));
        final snackAfterDelete = tester.getRect(snackBarCard());
        expect(
          snackAfterDelete.bottom,
          lessThanOrEqualTo(
            actionBarTop - SnackBarClearanceHost.defaultGap + 1.0,
          ),
        );

        // 提示条仍在屏上时再长按另一条待办：操作栏完全露在提示条下方且可点。
        await tester.longPress(find.text('任务乙'));
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(barFinder, findsOneWidget);
        final reappearedTop = tester.getRect(barFinder).top;
        expect(
          tester.getRect(snackBarCard()).bottom,
          lessThanOrEqualTo(
            reappearedTop - SnackBarClearanceHost.defaultGap + 1.0,
          ),
        );
        expect(
          find
              .descendant(of: barFinder, matching: find.text(l10n.commonDelete))
              .hitTestable(),
          findsOneWidget,
        );

        await pumpFor(tester, const Duration(seconds: 6));
        await unmount(tester);
      },
    );
  }

  testWidgets('MindMapEditorPage places SnackBar above the bottom dock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
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
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => KeyboardVisibility(child: child!),
          home: MindMapEditorPage(
            document: MindMapDocument.blank(text: '主题'),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dockTop = tester.getRect(find.byType(MindMapDock)).top;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: tester.element(find.byType(MindMapEditorPage)),
        snackBar: const SnackBar(
          content: Text('已导出'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(snackBarCard()).bottom,
      lessThanOrEqualTo(dockTop - SnackBarClearanceHost.defaultGap + 1.0),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    await unmount(tester);
  });

  testWidgets('RecycleBinPage places SnackBar above the selection bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    await tester.runAsync(() async {
      final id = await database.createDiary(
        title: '旧日记',
        contentDocJson: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        metadataJson: '{}',
      );
      await database.softDeleteDiary(id);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RecycleBinPage(),
        ),
      ),
    );
    await settleDb(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('旧日记'));
    await tester.pumpAndSettle();
    final barTop = tester.getRect(find.byType(RecycleBinSelectionBar)).top;

    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: tester.element(find.byType(RecycleBinPage)),
        snackBar: const SnackBar(
          content: Text('提示'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(snackBarCard()).bottom,
      lessThanOrEqualTo(barTop - SnackBarClearanceHost.defaultGap + 1.0),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    await unmount(tester);
  });

  testWidgets('DiaryTemplateEditorPage places SnackBar above the toolbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_toolbar_always_visible': true,
    });
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
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => KeyboardVisibility(child: child!),
          home: const DiaryTemplateEditorPage(),
        ),
      ),
    );
    await settleDb(tester);
    await tester.pumpAndSettle();

    final toolbarTop = tester
        .getRect(find.byType(DiaryFloatingToolbarSurface))
        .top;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: tester.element(find.byType(DiaryTemplateEditorPage)),
        snackBar: const SnackBar(
          content: Text('保存失败'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(snackBarCard()).bottom,
      lessThanOrEqualTo(toolbarTop - SnackBarClearanceHost.defaultGap + 1.0),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    await unmount(tester);
  });

  testWidgets('DiaryVideoFullscreenPage shows SnackBar above playback bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final player = FakeVideoPlayer();
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.dark),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiaryVideoFullscreenPage(
          video: const DiaryFileAttachment(path: '/data/diary_videos/clip.mp4'),
          playerFactory: (_) => player,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sliderTop = tester.getRect(find.byType(Slider)).top;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: tester.element(find.byType(DiaryVideoFullscreenPage)),
        snackBar: const SnackBar(
          content: Text('视频已保存'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(snackBarCard()).bottom, lessThanOrEqualTo(sliderTop));
    await pumpFor(tester, const Duration(seconds: 3));
    await unmount(tester);
  });
}
