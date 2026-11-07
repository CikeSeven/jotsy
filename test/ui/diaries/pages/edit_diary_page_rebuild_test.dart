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
import 'package:node_diary/ui/widgets/keyboard_visibility.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

void main() {
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    diaryId = await database.createDiary(
      title: 'Rebuild probe',
      contentDocJson: '[{"insert":"line one\\nline two\\n"}]',
      contentText: 'line one\nline two',
      metadataJson: '{}',
    );
  });
  tearDown(() => database.close());

  Future<void> pumpEditPage(WidgetTester tester) async {
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // 与应用壳相同：键盘是否弹起经 KeyboardVisibility 交给页面。
          builder: (BuildContext context, Widget? child) =>
              KeyboardVisibility(child: child!),
          home: EditDiaryPage(diaryId: diaryId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  af.AppFlowyEditor currentEditor(WidgetTester tester) =>
      tester.widget<af.AppFlowyEditor>(find.byType(af.AppFlowyEditor));

  double editorBottomPadding(WidgetTester tester) => tester
      .widget<SizedBox>(find.byKey(const ValueKey('diary-editor-page-reserve')))
      .height!;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('keyboard inset animation does not recreate the Quill editor', (
    tester,
  ) async {
    await pumpEditPage(tester);
    final editorBefore = currentEditor(tester);

    // 模拟键盘逐帧弹出：页面会随 viewInsets 重建，body 高度也逐帧变化。
    for (final inset in <double>[80, 160, 240, 300]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(currentEditor(tester), editorBefore), isTrue);
    }
    await unmount(tester);
  });

  testWidgets('keyboard animation rebuilds the page only when the keyboard '
      'appears and never rebuilds the body blocks', (tester) async {
    await pumpEditPage(tester);
    var pageBuilds = 0;
    var blockBuilds = 0;
    debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
      final widget = element.widget;
      if (widget is EditDiaryPage) pageBuilds++;
      if (widget is af.ParagraphBlockComponentWidget) blockBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    // 键盘逐帧升起：整页只在“弹起”那一帧重建（悬浮工具栏等按键盘在不在
    // 切换），之后的逐帧高度变化不再重建整页；正文段落一次都不重建。
    for (final inset in <double>[60, 120, 180, 240, 300]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(pageBuilds, 1);
    expect(blockBuilds, 0);

    // 收起同理：只在键盘完全收起的那一帧重建一次。
    for (final inset in <double>[240, 180, 120, 60, 0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugOnRebuildDirtyWidget = null;
    expect(pageBuilds, 2);
    expect(blockBuilds, 0);
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('opening and dragging the info panel updates the spacer without '
      'rebuilding the editor', (tester) async {
    await pumpEditPage(tester);
    final editorBefore = currentEditor(tester);
    final paddingBefore = editorBottomPadding(tester);

    // 点信息栏打开面板：占位随面板升起而增长，编辑器实例不变。
    final panel = PublishPanelDriver(tester);
    await panel.open();
    final paddingOpen = editorBottomPadding(tester);
    expect(paddingOpen, greaterThan(paddingBefore));
    expect(identical(currentEditor(tester), editorBefore), isTrue);

    final gesture = await tester.startGesture(
      tester.getCenter(panel.expandedHeader),
    );
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // 往下拖一段（未收到底）：占位连续缩小，编辑器实例不变。
    expect(editorBottomPadding(tester), lessThan(paddingOpen));
    expect(identical(currentEditor(tester), editorBefore), isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets(
    'automatic saving preserves the editor and skips a reverted title',
    (tester) async {
      await pumpEditPage(tester);
      final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
      final editorBefore = currentEditor(tester);
      final titleField = find.widgetWithText(TextField, 'Rebuild probe');
      expect(find.byTooltip(l10n.commonSave), findsNothing);

      await tester.enterText(titleField, 'Rebuild probe!');
      await tester.pump();
      expect(identical(currentEditor(tester), editorBefore), isTrue);

      // 防抖窗口内改回原文，不应更新数据库的最后编辑时间。
      final before = await tester.runAsync(
        () => database.getDiaryWithTagsByDiaryId(diaryId),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Rebuild probe!'),
        'Rebuild probe',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final after = await tester.runAsync(
        () => database.getDiaryWithTagsByDiaryId(diaryId),
      );
      expect(after!.diary.updatedAt, before!.diary.updatedAt);
      expect(identical(currentEditor(tester), editorBefore), isTrue);
      await unmount(tester);
    },
  );
}
