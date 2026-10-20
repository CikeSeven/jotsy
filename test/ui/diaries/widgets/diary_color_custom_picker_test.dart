import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_saved_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_hex_input.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_spectrum.dart';

import '../../../support/diary_color_panel_harness.dart';

/// 颜色面板的「自定义」页：拖动只预览、松手写入一次；色相 / 不透明度条；
/// 颜色代码用普通文字键盘、组字时不改写；焦点交接；跟随选区的颜色；写入的
/// 颜色存进我的颜色（同一次调色只留最后一个）。
void main() {
  setUpAll(loadColorPanelFonts);

  final hexField = find.descendant(
    of: find.byType(DiaryColorHexField),
    matching: find.byType(TextField),
  );
  String hexText(WidgetTester tester) =>
      tester.widget<TextField>(hexField).controller!.text;
  FocusNode hexFocus(WidgetTester tester) =>
      tester.widget<TextField>(hexField).focusNode!;

  Future<ColorPanelHarness> openCustom(
    WidgetTester tester, {
    quill.QuillController? controller,
    String tool = colorPanelTextTool,
    DiarySavedColors savedColors = DiarySavedColors.empty,
  }) async {
    final harness = await pumpColorPanel(
      tester,
      controller: controller,
      savedColors: savedColors,
    );
    harness.editorFocus.requestFocus();
    await tester.pump();
    await tester.tap(find.byTooltip(tool));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    return harness;
  }

  Future<void> tapAt(WidgetTester tester, Offset position) async {
    final gesture = await tester.startGesture(position);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('dragging previews live and writes once on release', (
    tester,
  ) async {
    final harness = await openCustom(tester);
    final area = tester.getRect(find.byType(DiaryColorSaturationValueArea));

    final gesture = await tester.startGesture(area.center);
    await tester.pump();
    // 右上角：饱和度、亮度都取满，色相是起始的 210°。
    await gesture.moveTo(area.topRight + const Offset(-1, 1));
    await tester.pump();
    expect(colorPanelAttributesAt(harness.controller, 0), isNull);
    expect(hexText(tester), '0080FF');
    expect(harness.saved.value.isEmpty, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FF0080FF',
    });
    expect(harness.saved.value.text, <Color>[const Color(0xFF0080FF)]);
    // 一次拖动只是一步撤销。
    harness.controller.undo();
    await tester.pumpAndSettle();
    expect(colorPanelAttributesAt(harness.controller, 0), isNull);
    expect(harness.editorFocus.hasFocus, isTrue);
  });

  testWidgets('the hue bar changes only the hue', (tester) async {
    final controller = colorPanelController();
    controller.formatSelection(const quill.ColorAttribute('#FF3A7BD5'));
    final harness = await openCustom(tester, controller: controller);
    expect(hexText(tester), '3A7BD5');

    final hue = tester.getRect(find.byType(DiaryColorHueSlider));
    await tapAt(tester, hue.topCenter + const Offset(0, 1));

    final expected = HSVColor.fromColor(
      const Color(0xFF3A7BD5),
    ).withHue(0).toColor();
    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': encodeDiaryColor(expected),
    });
  });

  testWidgets('background colors get an opacity bar that writes the alpha', (
    tester,
  ) async {
    final controller = colorPanelController();
    controller.formatSelection(const quill.BackgroundAttribute('#4D5B9BFF'));
    final harness = await openCustom(
      tester,
      controller: controller,
      tool: colorPanelBackgroundTool,
    );
    expect(hexText(tester), '5B9BFF');

    final alpha = tester.getRect(find.byType(DiaryColorAlphaSlider));
    await tapAt(tester, alpha.topCenter + const Offset(0, 1));

    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'background': '#FF5B9BFF',
    });
    expect(harness.saved.value.background, <Color>[const Color(0xFF5B9BFF)]);
    expect(harness.saved.value.text, isEmpty);

    // 文字色没有不透明度条。
    await tester.tap(find.byTooltip(colorPanelTextTool));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorAlphaSlider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the code field asks for the normal text keyboard', (
    tester,
  ) async {
    final harness = await openCustom(tester);
    await tester.tap(hexField);
    await tester.pumpAndSettle();

    expect(hexFocus(tester).hasFocus, isTrue);
    expect(harness.editorFocus.hasFocus, isFalse);
    // 发给平台的输入配置：普通文字、联想开着（Android 上关联想就是“可见
    // 密码”框，会被换成密码键盘）。
    final args = tester.testTextInput.setClientArgs!;
    expect(
      (args['inputType'] as Map<String, dynamic>)['name'],
      'TextInputType.text',
    );
    expect(args['enableSuggestions'], isTrue);
    expect(args['obscureText'], isFalse);
    expect(args['autocorrect'], isFalse);
    expect(tester.getSize(find.byType(InputDecorator)).height, 40);
  });

  testWidgets('a typed code previews, and Done writes it and returns focus', (
    tester,
  ) async {
    final harness = await openCustom(tester);
    await tester.tap(hexField);
    await tester.pumpAndSettle();

    await tester.enterText(hexField, '12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    // 无效代码：不写入，留在输入框里。
    expect(colorPanelAttributesAt(harness.controller, 0), isNull);
    expect(hexFocus(tester).hasFocus, isTrue);

    // 粘贴带前缀的小写代码也能识别。
    await tester.enterText(hexField, '0x3a7bd5');
    await tester.pump();
    expect(hexText(tester), '3A7BD5');
    expect(colorPanelAttributesAt(harness.controller, 0), isNull);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FF3A7BD5',
    });
    expect(harness.editorFocus.hasFocus, isTrue);
    expect(harness.saved.value.text, <Color>[const Color(0xFF3A7BD5)]);
  });

  testWidgets('a code applied at a collapsed caret colors the next text', (
    tester,
  ) async {
    final controller = colorPanelController();
    controller.updateSelection(
      const TextSelection.collapsed(offset: 5),
      quill.ChangeSource.local,
    );
    final harness = await openCustom(tester, controller: controller);
    await tester.tap(hexField);
    await tester.pumpAndSettle();
    await tester.enterText(hexField, '3A7BD5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(harness.editorFocus.hasFocus, isTrue);

    // 经输入法输入一个字：与真机打字走同一条路径。
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'hellox\n',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.controller.document.toPlainText(), 'hellox\n');
    expect(colorPanelAttributesAt(harness.controller, 5), <String, dynamic>{
      'color': '#FF3A7BD5',
    });
    expect(colorPanelAttributesAt(harness.controller, 0), isNull);
  });

  testWidgets('focusing the editor while typing a code discards it', (
    tester,
  ) async {
    final harness = await openCustom(tester);
    final before = hexText(tester);
    await tester.tap(hexField);
    await tester.pumpAndSettle();
    await tester.enterText(hexField, '3A7BD5');
    await tester.pump();

    harness.editorFocus.requestFocus();
    await tester.pumpAndSettle();

    expect(colorPanelAttributesAt(harness.controller, 0), isNull);
    expect(hexText(tester), before);
    expect(harness.editorFocus.hasFocus, isTrue);
  });

  testWidgets('dragging while typing a code hands focus back first', (
    tester,
  ) async {
    final harness = await openCustom(tester);
    await tester.tap(hexField);
    await tester.pumpAndSettle();
    expect(hexFocus(tester).hasFocus, isTrue);

    final area = tester.getRect(find.byType(DiaryColorSaturationValueArea));
    final gesture = await tester.startGesture(
      area.topRight + const Offset(-1, 1),
    );
    await tester.pump();
    expect(harness.editorFocus.hasFocus, isTrue);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FF0080FF',
    });
    expect(hexText(tester), '0080FF');
  });

  testWidgets('the picker follows the selection color', (tester) async {
    final controller = colorPanelController('ab');
    controller.formatText(0, 1, const quill.ColorAttribute('#FF112233'));
    controller.formatText(1, 1, const quill.ColorAttribute('#FF445566'));
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 1),
      quill.ChangeSource.local,
    );
    await openCustom(tester, controller: controller);
    expect(hexText(tester), '112233');

    controller.updateSelection(
      const TextSelection(baseOffset: 1, extentOffset: 2),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();
    expect(hexText(tester), '445566');
  });

  testWidgets('a gray selection keeps the hue where it was', (tester) async {
    final controller = colorPanelController();
    controller.formatSelection(const quill.ColorAttribute('#FF808080'));
    final handle = tester.ensureSemantics();
    await openCustom(tester, controller: controller);

    // 灰色没有色相：色相条停在起始的 210°，而不是跳回 0°。
    expect(
      tester.getSemantics(find.byType(DiaryColorHueSlider)),
      isSemantics(isSlider: true, label: '色相', value: '210°'),
    );
    handle.dispose();
  });

  testWidgets('screen readers step the hue and write it', (tester) async {
    final controller = colorPanelController();
    controller.formatSelection(const quill.ColorAttribute('#FFFF0000'));
    final handle = tester.ensureSemantics();
    final harness = await openCustom(tester, controller: controller);

    final node = tester.getSemantics(find.byType(DiaryColorHueSlider));
    tester
        .renderObject(find.byType(DiaryColorHueSlider))
        .owner!
        .semanticsOwner!
        .performAction(node.id, SemanticsAction.increase);
    await tester.pumpAndSettle();

    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': encodeDiaryColor(HSVColor.fromAHSV(1, 10, 1, 1).toColor()),
    });
    handle.dispose();
  });

  group('DiaryHexInputFormatter', () {
    const formatter = DiaryHexInputFormatter();

    test('leaves text alone while the IME is composing', () {
      const composing = TextEditingValue(
        text: 'fzz',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      );
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, composing),
        composing,
      );
    });

    test('cleans up committed text: hex only, upper case, six digits', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '#3a7bd5ff',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );
      expect(result.text, '3A7BD5');
      expect(result.selection, const TextSelection.collapsed(offset: 6));
    });
  });

  group('saving into my colors', () {
    Future<void> tapArea(WidgetTester tester, Offset fraction) async {
      final area = tester.getRect(find.byType(DiaryColorSaturationValueArea));
      await tapAt(
        tester,
        area.topLeft +
            Offset(
              (area.width - 2) * fraction.dx + 1,
              (area.height - 2) * fraction.dy + 1,
            ),
      );
    }

    testWidgets('tuning the same text keeps only the last color', (
      tester,
    ) async {
      final harness = await openCustom(
        tester,
        savedColors: const DiarySavedColors(text: <Color>[Color(0xFF112233)]),
      );

      await tapArea(tester, const Offset(1, 0));
      await tapArea(tester, const Offset(0.5, 0.5));
      await tapArea(tester, const Offset(0.8, 0.2));

      final applied = parseDiaryColorValue(
        colorPanelAttributesAt(harness.controller, 0)!['color'] as String,
      )!;
      // 中间色都被替换掉，已有的颜色留在原位。
      expect(harness.saved.value.text, <Color>[
        applied,
        const Color(0xFF112233),
      ]);
      expect(find.text('已保存'), findsOneWidget);
    });

    testWidgets('coloring other text saves another color', (tester) async {
      final harness = await openCustom(tester);

      await tapArea(tester, const Offset(1, 0));
      final first = harness.saved.value.text.single;
      harness.controller.updateSelection(
        const TextSelection(baseOffset: 2, extentOffset: 4),
        quill.ChangeSource.local,
      );
      await tester.pumpAndSettle();
      await tapArea(tester, const Offset(0.4, 0.6));

      expect(harness.saved.value.text, hasLength(2));
      expect(harness.saved.value.text.last, first);
      expect(
        colorPanelAttributesAt(harness.controller, 2)!['color'],
        encodeDiaryColor(harness.saved.value.text.first),
      );
    });

    testWidgets('a color already saved is neither repeated nor moved', (
      tester,
    ) async {
      const saved = DiarySavedColors(
        text: <Color>[Color(0xFF112233), Color(0xFF3A7BD5)],
      );
      final harness = await openCustom(tester, savedColors: saved);
      expect(find.text('已保存'), findsNothing);

      await tester.tap(hexField);
      await tester.pumpAndSettle();
      await tester.enterText(hexField, '3A7BD5');
      await tester.pump();
      // 输入中预览就认得出已保存的颜色。
      expect(find.text('已保存'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(harness.saved.value, saved);

      // 接着在同一段文字上调色：已存的那个不被替换，新颜色另存在最前。
      await tapArea(tester, const Offset(1, 0));
      expect(harness.saved.value.text, hasLength(3));
      expect(harness.saved.value.text.sublist(1), saved.text);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a saved color shows on the swatches page right away', (
      tester,
    ) async {
      final harness = await openCustom(tester);
      await tapArea(tester, const Offset(1, 0));
      final color = harness.saved.value.text.single;

      await tester.tap(find.text('色板'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('我的颜色 ${diaryColorRgbHex(color)}'),
        findsOneWidget,
      );
    });
  });
}
