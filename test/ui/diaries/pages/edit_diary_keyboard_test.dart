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
import '../../../support/soft_keyboard_keys.dart';

/// 编辑页正文与手机键盘的配合：在底部打字时新内容跟着上升、离工具栏留出
/// 空隙；点了屏幕下部的字再弹起键盘，那一行随键盘一起被顶上去；软键盘
/// “选择”模式能扩展正文选区；只改格式不拽动视口。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
  });
  tearDown(() => database.close());

  Future<void> pumpCreatePage(
    WidgetTester tester, {
    double keyboardHeight = 300,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
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

  DiaryEditorController bodyController(WidgetTester tester) =>
      tester.widget<DiaryEditor>(find.byType(DiaryEditor)).controller;

  ScrollPosition bodyScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      )
      .position;

  double caretBottom(WidgetTester tester) {
    return bodyController(tester).state.selectionRects().first.bottom;
  }

  double toolbarTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(DiaryFloatingToolbar)).dy;

  // 与编辑页的光标空隙一致：光标不贴着工具栏。
  const caretClearance = 40.0;

  /// 正文写满 [lines] 行，光标停在末尾。
  Future<void> fillBody(WidgetTester tester, {int lines = 40}) async {
    final controller = bodyController(tester);
    controller.replaceText(
      0,
      0,
      List<String>.generate(lines, (index) => 'line $index').join('\n'),
      null,
    );
    controller.updateSelection(
      TextSelection.collapsed(offset: controller.document.length - 1),
      'local',
    );
    await tester.pumpAndSettle();
  }

  /// 经输入法在光标处输入，与真机打字走同一条 updateEditingValue 链路。
  Future<void> typeAtCaret(WidgetTester tester, String text) async {
    final value = TextEditingValue.fromJSON(tester.testTextInput.editingState!);
    final offset = value.selection.extentOffset;
    tester.testTextInput.updateEditingValue(
      value.copyWith(
        text: value.text.replaceRange(offset, offset, text),
        selection: TextSelection.collapsed(offset: offset + text.length),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('typing at the bottom keeps new lines above the toolbar', (
    tester,
  ) async {
    await pumpCreatePage(tester);
    await fillBody(tester);
    final position = bodyScroll(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final offsetBefore = position.pixels;

    for (var index = 0; index < 5; index += 1) {
      await typeAtCaret(tester, '\nnew line $index');
      expect(
        toolbarTop(tester) - caretBottom(tester),
        greaterThanOrEqualTo(caretClearance),
      );
    }
    expect(position.pixels, greaterThan(offsetBefore));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('tapped bottom text rides up with the rising keyboard', (
    tester,
  ) async {
    await pumpCreatePage(tester, keyboardHeight: 0);
    await fillBody(tester);
    final position = bodyScroll(tester);
    position.jumpTo(position.maxScrollExtent / 2);
    await tester.pumpAndSettle();

    // 键盘未弹起时点屏幕下部的一行：弹起后这一块会被键盘盖住。
    await tester.tapAt(const Offset(40, 700));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(caretBottom(tester), greaterThan(900 - 300));

    // 键盘逐帧升高：每一帧光标都在键盘上方，而不是等停稳后才跳上来。
    for (var step = 1; step <= 10; step += 1) {
      final inset = 30.0 * step;
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
      expect(caretBottom(tester), lessThanOrEqualTo(900 - inset));
    }
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(
      toolbarTop(tester) - caretBottom(tester),
      greaterThanOrEqualTo(caretClearance),
    );
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('soft keyboard select mode extends the body selection', (
    tester,
  ) async {
    await pumpCreatePage(tester);
    final controller = bodyController(tester);
    controller.replaceText(0, 0, 'hello world', null);
    controller.updateSelection(
      const TextSelection.collapsed(offset: 11),
      'local',
    );
    await tester.pumpAndSettle();

    await sendSoftKeyboardKey(
      tester,
      SoftKeyboardKey.arrowLeft,
      selecting: true,
    );
    await sendSoftKeyboardKey(
      tester,
      SoftKeyboardKey.arrowLeft,
      selecting: true,
    );
    expect(
      controller.flatSelection,
      const TextSelection(baseOffset: 11, extentOffset: 9),
    );

    // 关掉“选择”后方向键回到移动光标。
    await sendSoftKeyboardKey(tester, SoftKeyboardKey.arrowRight);
    expect(controller.selection!.isCollapsed, isTrue);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('formatting does not pull the view back to the caret', (
    tester,
  ) async {
    await pumpCreatePage(tester);
    await fillBody(tester);
    final position = bodyScroll(tester);
    position.jumpTo(0);
    await tester.pumpAndSettle();

    bodyController(tester).formatSelection(const MapEntry('bold', true));
    await tester.pumpAndSettle();

    expect(position.pixels, 0);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
