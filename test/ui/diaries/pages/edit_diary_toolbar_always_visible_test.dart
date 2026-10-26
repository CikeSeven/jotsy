import '../../../support/diary_content_test_helpers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/publish_panel_driver.dart';

/// 编辑器设置“始终显示工具栏”：接实体键盘时软键盘不弹出，工具栏也要在。
/// 新建页常驻底部；编辑页键盘收起时叠在信息面板收起栏上方、两者都能用，
/// 键盘弹起时只有工具栏；面板展开时让位。默认关闭时行为不变。
void main() {
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    diaryId = await database.createDiary(
      title: 'Toolbar probe',
      contentDocJson: '[{"insert":"line one\\nline two\\n"}]',
      contentText: 'line one\nline two',
      metadataJson: '{}',
    );
  });
  tearDown(() => database.close());

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding.zero;
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
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Finder toolbar() => find.byType(DiaryFloatingToolbar);

  double editorBottomPadding(WidgetTester tester) => tester
      .widget<SizedBox>(find.byKey(const ValueKey('diary-editor-page-reserve')))
      .height!;

  testWidgets('by default the toolbar waits for the on-screen keyboard', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
    );
    // 新建页进场后正文已有焦点，但没有软键盘（实体键盘输入时就是这样）。
    expect(find.byType(DiaryEditor), findsOneWidget);
    expect(toolbar(), findsNothing);

    // 在设置里打开后，回到编辑页立即生效。
    await settings.setDiaryToolbarAlwaysVisible(true);
    await tester.pumpAndSettle();
    expect(toolbar(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets(
    'the create page keeps the toolbar without a keyboard or focus and leaves room for it',
    (tester) async {
      await settings.setDiaryToolbarAlwaysVisible(true);
      await pumpPage(
        tester,
        const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
      );
      expect(toolbar(), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(toolbar(), findsOneWidget);
      // 正文末尾的留白盖过工具栏与光标空隙，最后一行能滚到工具栏上方。
      final toolbarTop = tester.getTopLeft(toolbar()).dy;
      expect(
        editorBottomPadding(tester),
        greaterThanOrEqualTo(900 - toolbarTop + 40),
      );

      // 不聚焦也能排版：工具按钮直接作用在正文的选区上。
      final controller = tester
          .widget<DiaryEditor>(find.byType(DiaryEditor))
          .controller;
      controller.replaceText(0, 0, 'hello', null);
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        'local',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: toolbar(),
          matching: find.byTooltip(tester.element(toolbar()).l10n.autoT0008),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        controller.selectionAttributes,
        contains(const MapEntry('bold', true).key),
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'the edit page stacks the toolbar above the collapsed info panel when the keyboard is down',
    (tester) async {
      await settings.setDiaryToolbarAlwaysVisible(true);
      await pumpPage(tester, EditDiaryPage(diaryId: diaryId));
      final panel = PublishPanelDriver(tester);

      // 键盘收起：工具栏与收起栏同时在，工具栏在收起栏上方、不重叠。
      expect(toolbar(), findsOneWidget);
      expect(panel.collapsedHeader, findsOneWidget);
      final summaryTop = tester.getTopLeft(panel.collapsedHeader).dy;
      expect(
        tester.getBottomLeft(toolbar()).dy,
        lessThanOrEqualTo(summaryTop - 8),
      );
      // 留白同时让开工具栏与光标空隙。
      expect(
        editorBottomPadding(tester),
        greaterThanOrEqualTo(900 - tester.getTopLeft(toolbar()).dy + 40),
      );
      final toolbarState = tester.state(toolbar());

      // 点进正文、软键盘弹起：与默认一致，只剩工具栏贴着键盘。
      await tester.tap(find.byType(DiaryEditor));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(panel.collapsedHeader, findsNothing);
      expect(toolbar(), findsOneWidget);
      expect(
        tester.getBottomLeft(toolbar()).dy,
        moreOrLessEquals(900 - 300 - 8, epsilon: 0.5),
      );

      // 键盘收起：收起栏回来，工具栏升回它上方；工具栏没有被重建（「更多」
      // 与颜色面板的状态还在）。
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(panel.collapsedHeader, findsOneWidget);
      expect(
        tester.getBottomLeft(toolbar()).dy,
        lessThanOrEqualTo(tester.getTopLeft(panel.collapsedHeader).dy - 8),
      );
      expect(identical(tester.state(toolbar()), toolbarState), isTrue);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets('expanding the info panel hides the stacked toolbar', (
    tester,
  ) async {
    await settings.setDiaryToolbarAlwaysVisible(true);
    await pumpPage(tester, EditDiaryPage(diaryId: diaryId));
    final panel = PublishPanelDriver(tester);
    expect(toolbar(), findsOneWidget);

    await panel.expand();
    expect(panel.expandedHeader, findsOneWidget);
    expect(toolbar(), findsNothing);

    // 系统返回先收起面板。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(panel.collapsedHeader, findsOneWidget);
    expect(toolbar(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('by default the edit page keeps only the info panel', (
    tester,
  ) async {
    await pumpPage(tester, EditDiaryPage(diaryId: diaryId));
    await tester.tap(find.byType(DiaryEditor));
    await tester.pumpAndSettle();
    expect(PublishPanelDriver(tester).collapsedHeader, findsOneWidget);
    expect(toolbar(), findsNothing);
    await unmount(tester);
  });
}
