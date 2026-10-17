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
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/soft_keyboard_keys.dart';

/// 编辑页正文与手机键盘的配合：在底部打字时新内容跟着上升、离工具栏留出
/// 空隙；软键盘弹起时光标不被盖住、软键盘“选择”模式能扩展正文选区；只改
/// 格式不拽动视口。
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
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EditDiaryPage(
            entryMode: EditDiaryEntryMode.create,
            restoreCreateDraft: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  quill.QuillController bodyController(WidgetTester tester) => tester
      .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
      .controller;

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
    final renderEditor = tester
        .state<quill.QuillRawEditorState>(find.byType(quill.QuillRawEditor))
        .renderEditor;
    final caret = renderEditor.getLocalRectForCaret(
      bodyController(tester).selection.extent,
    );
    return renderEditor.localToGlobal(caret.bottomLeft).dy;
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
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();
  }

  /// 经输入法在光标处输入，与真机打字走同一条 updateEditingValue 链路。
  Future<void> typeAtCaret(WidgetTester tester, String text) async {
    final value = tester
        .state<quill.QuillRawEditorState>(find.byType(quill.QuillRawEditor))
        .currentTextEditingValue!;
    final offset = value.selection.extentOffset;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
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

  testWidgets('raising the keyboard reveals the caret it would cover', (
    tester,
  ) async {
    await pumpCreatePage(tester, keyboardHeight: 0);
    await fillBody(tester);
    // 键盘未弹起时光标在屏幕下部；弹起后这一块会被键盘与工具栏盖住。
    expect(caretBottom(tester), greaterThan(900 - 300));

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    // 等键盘高度停稳的去抖，再等揭示滚动结束。
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(caretBottom(tester), lessThanOrEqualTo(toolbarTop(tester)));
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
      quill.ChangeSource.local,
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
      controller.selection,
      const TextSelection(baseOffset: 11, extentOffset: 9),
    );

    // 关掉“选择”后方向键回到移动光标。
    await sendSoftKeyboardKey(tester, SoftKeyboardKey.arrowRight);
    expect(controller.selection.isCollapsed, isTrue);
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

    bodyController(tester).formatSelection(quill.Attribute.bold);
    await tester.pumpAndSettle();

    expect(position.pixels, 0);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
