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
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_hex_input.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_spectrum.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 编辑页与悬浮工具栏「更多」面板的装配：面板展开时正文让位、光标被推到
/// 面板上方，收起后额外留白归零。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
  });
  tearDown(() => database.close());

  Future<void> pumpCreatePage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    // 悬浮工具栏只在软键盘弹起且正文有焦点时出现。
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('expanding More pushes the caret above the panel', (
    tester,
  ) async {
    await pumpCreatePage(tester);
    final controller = tester
        .widget<DiaryEditor>(find.byType(DiaryEditor))
        .controller;
    controller.replaceText(
      0,
      0,
      List<String>.generate(40, (index) => 'line $index').join('\n'),
      null,
    );
    controller.updateSelection(
      TextSelection.collapsed(offset: controller.document.length - 1),
      'local',
    );
    await tester.pumpAndSettle();

    // 停在正文末尾：最后一行刚好露在工具栏上方。
    final body = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final position = tester.state<ScrollableState>(body.first).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    double caretBottom() => controller.state.selectionRects().first.bottom;

    double toolbarTop() =>
        tester.getTopLeft(find.byType(DiaryFloatingToolbar)).dy;

    expect(caretBottom(), lessThanOrEqualTo(toolbarTop()));
    final offsetBefore = position.pixels;

    await tester.tap(find.byTooltip('更多工具'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('插入图片'), findsOneWidget);
    expect(position.pixels, greaterThan(offsetBefore));
    expect(caretBottom(), lessThanOrEqualTo(toolbarTop()));

    await tester.tap(find.byTooltip('收起更多工具'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('插入图片'), findsNothing);
    expect(tester.getSize(find.byType(DiaryToolbarPanelReserve)).height, 0);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('More does not scroll the body while the title is edited', (
    tester,
  ) async {
    await pumpCreatePage(tester);
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    final body = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final position = tester.state<ScrollableState>(body.first).position;
    final offsetBefore = position.pixels;

    await tester.tap(find.byTooltip('更多工具'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('插入图片'), findsOneWidget);
    expect(position.pixels, offsetBefore);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a custom color is saved and offered on the swatches page', (
    tester,
  ) async {
    await pumpCreatePage(tester);
    await tester.tap(find.byTooltip('更多工具'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('文字颜色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();

    // 点饱和度 / 亮度面的右上角：起始色相 210°，饱和度与亮度取满。
    final area = tester.getRect(find.byType(DiaryColorSaturationValueArea));
    final gesture = await tester.startGesture(
      area.topRight + const Offset(-1, 1),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(settings.diarySavedColorsRaw, contains('#FF0080FF'));
    await tester.tap(find.text('色板'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('我的颜色 #0080FF'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the color code input survives the keyboard closing briefly', (
    tester,
  ) async {
    await pumpCreatePage(tester);
    await tester.tap(find.byTooltip('更多工具'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('文字颜色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    final hexField = find.descendant(
      of: find.byType(DiaryColorHexField),
      matching: find.byType(TextField),
    );
    await tester.tap(hexField);
    await tester.pumpAndSettle();

    FocusNode hexFocus() => tester.widget<TextField>(hexField).focusNode!;
    expect(hexFocus().hasFocus, isTrue);

    // 焦点交接时输入法可能先收起再弹出：键盘高度短暂归零，工具栏与输入框
    // 都不能因此卸载。
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(hexField, findsOneWidget);
    expect(hexFocus().hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(hexField, findsOneWidget);
    expect(hexFocus().hasFocus, isTrue);

    // 按“完成”应用后焦点回到正文，工具栏照旧跟着键盘：键盘收起就不再显示。
    await tester.enterText(hexField, '3A7BD5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(hexFocus().hasFocus, isFalse);
    expect(find.byType(DiaryFloatingToolbar), findsOneWidget);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.byType(DiaryFloatingToolbar), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
