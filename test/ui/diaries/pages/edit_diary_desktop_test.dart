import '../../../support/diary_content_test_helpers.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_floating_toolbar_surface.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

/// 桌面与宽窗口的编辑页：工具栏不等键盘与焦点一直显示、与正文列同宽居中；
/// 标题与正文收成最宽 760 的一列；Linux 上没有录音；Esc 与返回按钮相同。
///
/// 编辑器拿到焦点后光标闪烁，pumpAndSettle 等不到静止，这里一律固定帧数。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    diaryId = await database.createDiary(
      title: 'Desktop probe',
      contentDocJson: '[{"insert":"line one\\nline two\\n"}]',
      contentText: 'line one\nline two',
      metadataJson: '{}',
    );
  });
  tearDown(() => database.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// 首页一个按钮推入 [page]：Esc 返回要有上一页可回。
  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(1280, 900),
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
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => page)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Finder toolbar() => find.byType(DiaryFloatingToolbar);

  Finder recordingTool(WidgetTester tester) => find.descendant(
    of: toolbar(),
    matching: find.byTooltip(
      tester.element(toolbar()).l10n.diaryToolbarRecording,
    ),
  );

  testWidgets(
    'the desktop create page shows a centred toolbar without focus or keyboard',
    (tester) async {
      await pumpPage(
        tester,
        const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      expect(toolbar(), findsOneWidget);
      final bar = tester.getRect(toolbar());
      expect(bar.width, closeTo(760, 0.5));
      expect(bar.center.dx, closeTo(640, 0.5));

      // 标题与正文是最宽 760 的一列、居中。
      final title = tester.getRect(find.byType(TextField).first);
      expect(title.left, closeTo((1280 - 760) / 2, 0.5));
      expect(title.width, closeTo(760, 0.5));
      final editor = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
      expect(editor.padding, const EdgeInsets.symmetric(horizontal: 260));
      // 编辑器本身仍铺满窗口：滚动条留在窗口边缘。
      expect(tester.getRect(find.byType(DiaryEditor)).width, 1280);

      // 顶栏返回键随正文列内收（AppTopBar.contentMaxWidth），不再贴窗口左缘。
      final back = tester.getRect(
        find.byTooltip(tester.element(toolbar()).l10n.commonBack),
      );
      expect(back.left, greaterThan(200));
      expect(back.left, lessThan(260));

      // Linux 不支持录音：工具栏里没有录音。
      expect(recordingTool(tester), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('Windows keeps the recording tool in the toolbar', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
    );
    expect(toolbar(), findsOneWidget);
    expect(recordingTool(tester), findsOneWidget);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'the desktop edit page stacks the toolbar above the collapsed panel',
    (tester) async {
      await pumpPage(tester, EditDiaryPage(diaryId: diaryId));
      expect(toolbar(), findsOneWidget);
      expect(find.byType(PublishDiaryPanel), findsOneWidget);
      final bar = tester.getRect(toolbar());
      final summary = tester.getRect(
        PublishPanelDriver(tester).collapsedHeader,
      );
      expect(bar.bottom, lessThanOrEqualTo(summary.top - 8));
      // 面板卡片（圆角裁切那一层）与工具栏卡片同宽同边：都是居中的 760。
      Rect card() => tester.getRect(
        find
            .descendant(
              of: find.byType(PublishDiaryPanel),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      final surface = tester.getRect(find.byType(DiaryFloatingToolbarSurface));
      expect(surface.width, closeTo(760, 0.5));
      expect(surface.center.dx, closeTo(640, 0.5));
      expect(card().left, closeTo(surface.left, 0.5));
      expect(card().width, closeTo(surface.width, 0.5));

      // 展开后仍是同一列（工具栏让位）。
      final panel = PublishPanelDriver(tester);
      await tester.tap(panel.collapsedHeader);
      await settle(tester);
      expect(panel.expandedHeader, findsOneWidget);
      expect(card().left, closeTo(surface.left, 0.5));
      expect(card().width, closeTo(760, 0.5));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'escape leaves the editor like the back button, even while typing',
    (tester) async {
      await pumpPage(
        tester,
        const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
      );
      expect(find.byType(EditDiaryPage), findsOneWidget);
      // 新建页进场后正文已有焦点：Esc 不被编辑器的“退出编辑”吞掉。
      final body = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
      expect(body.focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(EditDiaryPage), findsNothing);
      expect(find.text('open'), findsOneWidget);

      await unmount(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('escape on the edit page saves and leaves like the back button', (
    tester,
  ) async {
    await pumpPage(tester, EditDiaryPage(diaryId: diaryId));
    expect(find.byType(EditDiaryPage), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(EditDiaryPage), findsNothing);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'the desktop publish page centres the preview and panel and leaves on escape',
    (tester) async {
      await pumpPage(
        tester,
        const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
      );
      await tester.enterText(find.byType(TextField).first, 'Wide sunset');
      await tester.pump();
      final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
      await tester.tap(find.byTooltip(l10n.autoT0136));
      await tester.pump();
      await tester.pump();
      final panel = PublishPanelDriver(tester);
      await panel.waitUntilPublished();
      await settle(tester);
      expect(find.byType(PublishDiaryPage), findsOneWidget);

      // 正文预览自带 16 的边距：外框 752、可见内容 720，居中。
      final preview = tester.getRect(find.byType(PublishDiaryPreview));
      expect(preview.width, closeTo(720 + 32, 0.5));
      expect(preview.center.dx, closeTo(640, 0.5));
      final sheet = tester.getRect(find.byType(PublishDiaryPanel));
      expect(sheet.width, closeTo(760, 0.5));
      expect(sheet.center.dx, closeTo(640, 0.5));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      for (var i = 0; i < 20 && find.text('open').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await settle(tester);
      expect(find.byType(PublishDiaryPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
      await unmount(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('the standard desktop shortcuts format and undo in the body', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
    );
    final body = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
    expect(body.focusNode!.hasFocus, isTrue);
    final controller = body.controller;
    controller.replaceText(0, 0, 'hello', null);
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      'local',
    );
    await settle(tester);

    Future<void> chord(LogicalKeyboardKey key, {bool shift = false}) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
    }

    await chord(LogicalKeyboardKey.keyB);
    expect(controller.selectionAttributes['bold'], isTrue);
    await chord(LogicalKeyboardKey.keyI);
    expect(controller.selectionAttributes['italic'], isTrue);
    await chord(LogicalKeyboardKey.keyZ);
    expect(controller.selectionAttributes['italic'], isNot(true));
    await chord(LogicalKeyboardKey.keyZ, shift: true);
    expect(controller.selectionAttributes['italic'], isTrue);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets(
    'a phone width keeps the 16dp margins and the keyboard-bound toolbar',
    (tester) async {
      await pumpPage(
        tester,
        const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
        size: const Size(400, 900),
      );
      expect(toolbar(), findsNothing);
      final editor = tester.widget<DiaryEditor>(find.byType(DiaryEditor));
      expect(editor.padding, const EdgeInsets.symmetric(horizontal: 16));
      expect(tester.getRect(find.byType(TextField).first).left, 16);
      await unmount(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
