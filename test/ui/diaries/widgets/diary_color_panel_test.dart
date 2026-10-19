import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';

import '../../../support/expressive_test_theme.dart';

const _textColorTool = '文字颜色';
const _backgroundColorTool = '背景颜色';
const _moreTooltip = '更多工具';
const _hideMoreTooltip = '收起更多工具';
const _enterCode = '输入颜色代码';

/// 颜色工具排在最前，360dp 下常驻在工具栏一排上。
const _colorFirstOrder = <DiaryToolbarItem>[
  DiaryToolbarItem.textColor,
  DiaryToolbarItem.backgroundColor,
  ...kDefaultDiaryToolbarOrder,
];

class _RouteCounter extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

class _Harness {
  _Harness(this.controller, this.editorFocus, this.routes, this.extents);

  final quill.QuillController controller;
  final FocusNode editorFocus;
  final _RouteCounter routes;
  final List<double> extents;
}

quill.QuillController _controller([String text = 'hello']) {
  final controller = quill.QuillController.basic();
  addTearDown(controller.dispose);
  controller.replaceText(0, 0, text, null);
  controller.updateSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
    quill.ChangeSource.local,
  );
  return controller;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  quill.QuillController? controller,
  double screenWidth = 360,
  List<DiaryToolbarItem> order = _colorFirstOrder,
  bool recordingOpen = false,
  Locale locale = const Locale('zh'),
  _Harness? reuse,
}) async {
  tester.view.physicalSize = Size(screenWidth, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness =
      reuse ??
      _Harness(
        controller ?? _controller(),
        FocusNode(),
        _RouteCounter(),
        <double>[],
      );
  if (reuse == null) addTearDown(harness.editorFocus.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: locale,
      navigatorObservers: <NavigatorObserver>[harness.routes],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ...AppLocalizations.localizationsDelegates,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: <Widget>[
            Expanded(
              child: quill.QuillEditor.basic(
                controller: harness.controller,
                focusNode: harness.editorFocus,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kDiaryFloatingToolbarInset,
              ),
              child: DiaryFloatingToolbar(
                controller: harness.controller,
                order: order,
                recordingOpen: recordingOpen,
                onPanelExtentChanged: harness.extents.add,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

Map<String, dynamic>? _attributesAt(quill.QuillController controller, int i) {
  var offset = 0;
  for (final op in controller.document.toDelta().toList()) {
    final length = op.length ?? 0;
    if (i < offset + length) return op.attributes;
    offset += length;
  }
  return null;
}

FocusNode _hexFocus(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).focusNode!;

Future<void> _openTextPanel(WidgetTester tester) async {
  await tester.tap(find.byTooltip(_textColorTool));
  await tester.pumpAndSettle();
}

void main() {
  // 用应用的真实字体排版：320dp 表头放不放得下标题取决于字宽，测试默认的
  // Ahem 每个字都是满格方块，比真实文字宽得多。
  setUpAll(() async {
    final loader = FontLoader('HarmonyOSSansSC');
    for (final weight in <String>['Regular', 'Medium', 'Bold']) {
      loader.addFont(
        rootBundle.load(
          'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_$weight.ttf',
        ),
      );
    }
    await loader.load();
  });

  testWidgets('the text color tool opens the panel inside the card, no route', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final pushesBefore = harness.routes.pushes;

    await _openTextPanel(tester);

    expect(find.byType(DiaryColorPanel), findsOneWidget);
    expect(harness.routes.pushes, pushesBefore);
    expect(find.byType(Dialog), findsNothing);
    expect(harness.extents.last, greaterThan(0));
    // 面板在工具栏一排的上方。
    expect(
      tester.getBottomLeft(find.byType(DiaryColorPanel)).dy,
      lessThan(tester.getTopLeft(find.byTooltip(_textColorTool)).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a preset writes the exact #AARRGGBB value', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _openTextPanel(tester);

    await tester.tap(find.byTooltip('红'));
    await tester.pumpAndSettle();

    expect(_attributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FFE5484D',
    });
    // 面板保持打开，便于继续调整。
    expect(find.byType(DiaryColorPanel), findsOneWidget);
  });

  testWidgets('the default swatch clears the text color', (tester) async {
    final controller = _controller();
    controller.formatSelection(const quill.ColorAttribute('#FF3B7BE8'));
    final harness = await _pump(tester, controller: controller);
    await _openTextPanel(tester);

    await tester.tap(find.byTooltip('默认颜色'));
    await tester.pumpAndSettle();

    expect(_attributesAt(harness.controller, 0), isNull);
  });

  testWidgets('the other color tool switches the open panel to its target', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _openTextPanel(tester);
    expect(find.text('文字颜色'), findsOneWidget);
    final reportsBefore = harness.extents.length;

    await tester.tap(find.byTooltip(_backgroundColorTool));
    await tester.pumpAndSettle();

    // 面板没有收起再展开：一直开着，只换了目标。
    expect(find.byType(DiaryColorPanel), findsOneWidget);
    expect(harness.extents.length, reportsBefore);
    expect(harness.extents.last, greaterThan(0));
    expect(find.text('背景颜色'), findsOneWidget);
    expect(find.text('文字颜色'), findsNothing);
    expect(find.byTooltip('无背景色'), findsOneWidget);

    await tester.tap(find.byTooltip('红'));
    await tester.pumpAndSettle();
    expect(_attributesAt(harness.controller, 0), <String, dynamic>{
      'background': '#4DFF6369',
    });
  });

  testWidgets('switching targets re-reports the extent when the grid changes', (
    tester,
  ) async {
    // 宽屏 16 列：预设占一行；文字色另有 5 种自定义颜色，第二行才放得下。
    final controller = _controller('abcdef');
    for (var i = 0; i < 5; i++) {
      controller.formatText(i, 1, quill.ColorAttribute('#FF12345${i + 1}'));
    }
    final harness = await _pump(
      tester,
      controller: controller,
      screenWidth: 1200,
    );
    await _openTextPanel(tester);
    final textExtent = harness.extents.last;

    await tester.tap(find.byTooltip(_backgroundColorTool));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryColorPanel), findsOneWidget);
    expect(harness.extents.last, textExtent - DiaryColorGridLayout.cellHeight);
    expect(
      tester.getSize(find.byType(DiaryFloatingToolbar)).height,
      kDiaryToolbarBarHeight + harness.extents.last,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the same tool again closes the panel', (tester) async {
    final harness = await _pump(tester);
    await _openTextPanel(tester);
    expect(harness.extents.last, greaterThan(0));

    // 换到背景颜色工具：面板保持打开，只换目标。
    await tester.tap(find.byTooltip(_backgroundColorTool));
    await tester.pumpAndSettle();
    expect(find.byTooltip('无背景色'), findsOneWidget);

    await tester.tap(find.byTooltip(_backgroundColorTool));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorPanel), findsNothing);
    expect(harness.extents.last, 0);
  });

  testWidgets('a color tool inside More opens the color panel under More', (
    tester,
  ) async {
    final harness = await _pump(tester, order: kDefaultDiaryToolbarOrder);
    await tester.tap(find.byTooltip(_moreTooltip));
    await tester.pumpAndSettle();
    final moreExtent = harness.extents.last;

    await tester.tap(find.byTooltip(_textColorTool));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryColorPanel), findsOneWidget);
    expect(find.byTooltip('插入图片'), findsNothing);
    expect(harness.extents.last, isNot(moreExtent));
    // 「更多」仍是展开态，再点一下整块收起。
    expect(find.byTooltip(_hideMoreTooltip), findsOneWidget);
    await tester.tap(find.byTooltip(_hideMoreTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorPanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening the recording panel closes the color panel at once', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _openTextPanel(tester);

    await _pump(tester, recordingOpen: true, reuse: harness);

    expect(find.byType(DiaryColorPanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hex input validates, applies and hands focus back', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.editorFocus.requestFocus();
    await tester.pump();
    await _openTextPanel(tester);
    expect(harness.editorFocus.hasFocus, isTrue);

    await tester.tap(find.byTooltip(_enterCode));
    await tester.pumpAndSettle();
    expect(_hexFocus(tester).hasFocus, isTrue);
    expect(harness.editorFocus.hasFocus, isFalse);
    // 输入框是 40dp 高的胶囊，与表头里的其他控件居中对齐。
    expect(tester.getSize(find.byType(InputDecorator)).height, 40);

    IconButton apply() => tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('应用'),
        matching: find.byType(IconButton),
      ),
    );
    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();
    expect(apply().onPressed, isNull);

    // 粘贴带前缀的代码也能识别。
    await tester.enterText(find.byType(TextField), '0x3a7bd5');
    await tester.pump();
    expect(find.text('3A7BD5'), findsOneWidget);
    expect(apply().onPressed, isNotNull);

    await tester.tap(find.byTooltip('应用'));
    await tester.pumpAndSettle();

    expect(_attributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FF3A7BD5',
    });
    expect(find.byType(TextField), findsNothing);
    expect(harness.editorFocus.hasFocus, isTrue);
  });

  testWidgets('cancelling hex input changes nothing and restores focus', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.editorFocus.requestFocus();
    await tester.pump();
    await _openTextPanel(tester);
    await tester.tap(find.byTooltip(_enterCode));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '3A7BD5');
    await tester.tap(find.byTooltip('取消'));
    await tester.pumpAndSettle();

    expect(_attributesAt(harness.controller, 0), isNull);
    expect(find.byType(TextField), findsNothing);
    expect(harness.editorFocus.hasFocus, isTrue);
  });

  testWidgets('focusing the editor while typing a code leaves input mode', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.editorFocus.requestFocus();
    await tester.pump();
    await _openTextPanel(tester);
    await tester.tap(find.byTooltip(_enterCode));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3A7BD5');

    harness.editorFocus.requestFocus();
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(_attributesAt(harness.controller, 0), isNull);
    expect(harness.editorFocus.hasFocus, isTrue);
  });

  testWidgets('a hex color applied at a collapsed caret colors the next text', (
    tester,
  ) async {
    final controller = _controller();
    controller.updateSelection(
      const TextSelection.collapsed(offset: 5),
      quill.ChangeSource.local,
    );
    final harness = await _pump(tester, controller: controller);
    harness.editorFocus.requestFocus();
    await tester.pump();
    await _openTextPanel(tester);
    await tester.tap(find.byTooltip(_enterCode));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3A7BD5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(harness.editorFocus.hasFocus, isTrue);
    expect(find.byType(TextField), findsNothing);

    // 经输入法输入一个字：与真机打字走同一条路径。
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'hellox\n',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.controller.document.toPlainText(), 'hellox\n');
    expect(_attributesAt(harness.controller, 5), <String, dynamic>{
      'color': '#FF3A7BD5',
    });
    expect(_attributesAt(harness.controller, 0), isNull);
  });

  testWidgets('tapping a swatch while typing a code applies it and exits', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.editorFocus.requestFocus();
    await tester.pump();
    await _openTextPanel(tester);
    await tester.tap(find.byTooltip(_enterCode));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('蓝'));
    await tester.pumpAndSettle();

    expect(_attributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FF3B7BE8',
    });
    expect(find.byType(TextField), findsNothing);
    expect(harness.editorFocus.hasFocus, isTrue);
  });

  for (final width in <double>[360, 1200]) {
    testWidgets('the panel opens in a ${width.toInt()}dp toolbar', (
      tester,
    ) async {
      final harness = await _pump(
        tester,
        screenWidth: width,
        order: kDefaultDiaryToolbarOrder,
      );
      if (width == 360) {
        // 窄屏：颜色工具收在「更多」里。
        await tester.tap(find.byTooltip(_moreTooltip));
        await tester.pumpAndSettle();
      } else {
        expect(find.byTooltip(_moreTooltip), findsNothing);
      }
      await _openTextPanel(tester);

      expect(find.byType(DiaryColorPanel), findsOneWidget);
      expect(harness.extents.last, greaterThan(0));
      final toolbarHeight = tester
          .getSize(find.byType(DiaryFloatingToolbar))
          .height;
      expect(toolbarHeight, kDiaryToolbarBarHeight + harness.extents.last);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a 320dp English header fits one 40dp row with the code', (
    tester,
  ) async {
    final controller = _controller();
    controller.formatSelection(const quill.BackgroundAttribute('#4D5B9BFF'));
    await _pump(
      tester,
      controller: controller,
      screenWidth: 320,
      locale: const Locale('en'),
    );
    await tester.tap(find.byTooltip('Background color'));
    await tester.pumpAndSettle();

    final title = find.descendant(
      of: find.byType(DiaryColorPanel),
      matching: find.text('Background color'),
    );
    expect(tester.getSize(title).height, lessThanOrEqualTo(40));
    expect(
      tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
      isFalse,
    );
    expect(find.text('#5B9BFF'), findsOneWidget);
    // 标题起点对齐第一个色块圆的左缘。
    final firstSwatch = find.byTooltip('No background');
    expect(
      tester.getTopLeft(title).dx,
      closeTo(tester.getCenter(firstSwatch).dx - 14, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('hex input mode fits the 40dp header at 320dp', (tester) async {
    final harness = await _pump(
      tester,
      screenWidth: 320,
      locale: const Locale('en'),
    );
    harness.editorFocus.requestFocus();
    await tester.pump();
    await tester.tap(find.byTooltip('Text color'));
    await tester.pumpAndSettle();
    final panelHeight = tester.getSize(find.byType(DiaryColorPanel)).height;

    await tester.tap(find.byTooltip('Enter color code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3A7BD5');
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(DiaryColorPanel)).height, panelHeight);
    for (final tooltip in <String>['Cancel', 'Apply']) {
      final button = find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(button), const Size.square(40), reason: tooltip);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion switches targets and panels without errors', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    // 颜色工具常驻，其余工具仍有一部分收在「更多」里。
    await _pump(tester);

    await tester.tap(find.byTooltip(_textColorTool));
    await tester.pump();
    await tester.pump();
    expect(find.byType(DiaryColorPanel), findsOneWidget);
    await tester.tap(find.byTooltip(_backgroundColorTool));
    await tester.pump();
    await tester.pump();
    expect(find.text('背景颜色'), findsOneWidget);
    // 颜色面板开着时点「更多」换成「更多」面板，再点收起。
    await tester.tap(find.byTooltip(_moreTooltip));
    await tester.pump();
    await tester.pump();
    expect(find.byType(DiaryColorPanel), findsNothing);
    await tester.tap(find.byTooltip(_hideMoreTooltip));
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip(_moreTooltip), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
