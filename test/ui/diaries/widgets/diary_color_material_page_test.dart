import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_material_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch.dart';

import '../../../support/diary_color_panel_harness.dart';

/// 颜色面板的「色系」页：Material 色板的色阶写入、换色系（点圆点 / 左右滑）、
/// 跟随选区颜色、记住上次的色系、色系一行的居中与半个圆点提示，以及宽屏与
/// 减少动画。
void main() {
  setUpAll(loadColorPanelFonts);

  Future<void> openMaterialPage(
    WidgetTester tester, {
    String tool = colorPanelTextTool,
  }) async {
    await tester.tap(find.byTooltip(tool));
    await tester.pumpAndSettle();
    await tester.tap(find.text('色系'));
    await tester.pumpAndSettle();
  }

  Future<void> tapFamily(WidgetTester tester, String name) async {
    final dot = find.byTooltip('$name色系');
    await tester.ensureVisible(dot);
    await tester.pumpAndSettle();
    await tester.tap(dot);
    await tester.pumpAndSettle();
  }

  DiaryColorSwatch swatch(WidgetTester tester, String label) =>
      tester.widget<DiaryColorSwatch>(
        find.ancestor(
          of: find.byTooltip(label),
          matching: find.byType(DiaryColorSwatch),
        ),
      );

  bool familySelected(WidgetTester tester, String name) =>
      tester
          .getSemantics(find.bySemanticsLabel('$name色系'))
          .flagsCollection
          .isSelected ==
      Tristate.isTrue;

  testWidgets('the 色系 tab shows the red family at the swatches height', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester);
    await tester.tap(find.byTooltip(colorPanelTextTool));
    await tester.pumpAndSettle();
    final swatchesExtent = harness.extents.last;

    await tester.tap(find.text('色系'));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryColorMaterialPage), findsOneWidget);
    // 360dp：色阶两行各 7 格，与色板页同高，换页时面板不跳。
    expect(harness.extents.last, swatchesExtent);
    for (final tone in <String>['50', '500', '900', 'A100', 'A700']) {
      expect(find.byTooltip('红 $tone'), findsOneWidget, reason: tone);
    }
    expect(
      tester.getCenter(find.byTooltip('红 600')).dy,
      tester.getCenter(find.byTooltip('红 50')).dy,
    );
    expect(
      tester.getCenter(find.byTooltip('红 700')).dy,
      greaterThan(tester.getCenter(find.byTooltip('红 600')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a shade writes its exact value, not into My colors', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester);
    await openMaterialPage(tester);

    await tester.tap(find.byTooltip('红 700'));
    await tester.pumpAndSettle();

    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FFD32F2F',
    });
    expect(swatch(tester, '红 700').selected, isTrue);
    expect(find.byType(DiaryColorMaterialPage), findsOneWidget);
    expect(harness.edits, 0);
  });

  testWidgets('a background shade is written opaque, as in the palette', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester);
    await openMaterialPage(tester, tool: colorPanelBackgroundTool);

    await tester.tap(find.byTooltip('红 100'));
    await tester.pumpAndSettle();

    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'background': '#FFFFCDD2',
    });
  });

  testWidgets('a family dot switches the shades, near or far', (tester) async {
    final semantics = tester.ensureSemantics();
    final harness = await pumpColorPanel(tester);
    await openMaterialPage(tester);
    expect(familySelected(tester, '红'), isTrue);

    await tapFamily(tester, '蓝');
    expect(find.byTooltip('红 500'), findsNothing);
    expect(familySelected(tester, '蓝'), isTrue);
    expect(familySelected(tester, '红'), isFalse);
    await tester.tap(find.byTooltip('蓝 200'));
    await tester.pumpAndSettle();
    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FF90CAF9',
    });

    // 远处的色系：先跳到邻页再滑进来，途经的页不改当前色系。
    await tapFamily(tester, '蓝灰');
    expect(find.byTooltip('蓝灰 50'), findsOneWidget);
    expect(familySelected(tester, '蓝灰'), isTrue);
    expect(familySelected(tester, '棕'), isFalse);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('swiping the shades turns to the next family', (tester) async {
    final semantics = tester.ensureSemantics();
    final harness = await pumpColorPanel(tester);
    await openMaterialPage(tester);

    await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.byTooltip('粉 500'), findsOneWidget);
    expect(find.byTooltip('红 500'), findsNothing);
    expect(familySelected(tester, '粉'), isTrue);
    await tester.tap(find.byTooltip('粉 500'));
    await tester.pumpAndSettle();
    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FFE91E63',
    });

    // 往回滑回到红色系。
    await tester.fling(find.byType(PageView), const Offset(200, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byTooltip('红 500'), findsOneWidget);
    expect(familySelected(tester, '红'), isTrue);
    semantics.dispose();
  });

  testWidgets('it opens on the family of the selection color, centered', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = colorPanelController();
    controller.formatSelection(const quill.ColorAttribute('#FF4DB6AC'));
    await pumpColorPanel(tester, controller: controller);
    await openMaterialPage(tester);

    expect(swatch(tester, '蓝绿 300').selected, isTrue);
    expect(familySelected(tester, '蓝绿'), isTrue);
    // 360dp：工具栏内宽 320、8 格各 40dp，当前色系居中；两端都切在圆点中间
    // （靛与黄各露出一半），一看就知道还能滑。
    final panel = tester.getRect(find.byType(DiaryColorPanel));
    expect(
      tester.getCenter(find.byTooltip('蓝绿色系')).dx,
      closeTo(panel.center.dx, 0.5),
    );
    expect(
      tester.getCenter(find.byTooltip('靛色系')).dx,
      closeTo(panel.left, 0.5),
    );
    expect(
      tester.getCenter(find.byTooltip('黄色系')).dx,
      closeTo(panel.right, 0.5),
    );
    semantics.dispose();
  });

  testWidgets('the first family leaves a half dot hint only at the end', (
    tester,
  ) async {
    await pumpColorPanel(tester);
    await openMaterialPage(tester);

    // 滚到头时贴边的一端是半格留白，另一端切在圆点中间。
    final panel = tester.getRect(find.byType(DiaryColorPanel));
    expect(tester.getCenter(find.byTooltip('红色系')).dx, panel.left + 40);
    expect(
      tester.getCenter(find.byTooltip('青色系')).dx,
      closeTo(panel.right, 0.5),
    );
  });

  testWidgets('the page follows the selection into another family', (
    tester,
  ) async {
    final controller = colorPanelController('abcdef');
    controller.formatText(0, 3, const quill.ColorAttribute('#FF4DB6AC'));
    controller.formatText(3, 3, const quill.ColorAttribute('#FFFFE082'));
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 2),
      quill.ChangeSource.local,
    );
    await pumpColorPanel(tester, controller: controller);
    await openMaterialPage(tester);
    expect(swatch(tester, '蓝绿 300').selected, isTrue);

    controller.updateSelection(
      const TextSelection(baseOffset: 4, extentOffset: 5),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();
    expect(swatch(tester, '琥珀 200').selected, isTrue);

    // 选区没有颜色时停在原来的色系。
    controller.replaceText(6, 0, 'g', null);
    controller.updateSelection(
      const TextSelection(baseOffset: 6, extentOffset: 7),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('琥珀 200'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the browsed family survives tabs, targets and reopening', (
    tester,
  ) async {
    await pumpColorPanel(tester);
    await openMaterialPage(tester);
    await tapFamily(tester, '青');
    expect(find.byTooltip('青 500'), findsOneWidget);

    await tester.tap(find.text('色板'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('色系'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('青 500'), findsOneWidget);

    // 换目标：背景选区没有颜色，仍停在青色系。
    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();
    expect(find.byTooltip('青 500'), findsOneWidget);

    // 收起再打开：页签与色系都还在。
    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorPanel), findsNothing);
    await tester.tap(find.byTooltip(colorPanelTextTool));
    await tester.pumpAndSettle();
    expect(find.byTooltip('青 500'), findsOneWidget);
  });

  testWidgets('gray runs from white to black; brown has no accents', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester);
    await openMaterialPage(tester);

    await tapFamily(tester, '灰');
    for (final label in <String>['白', '灰 50', '灰 350', '灰 850', '黑']) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.byTooltip('黑'));
    await tester.pumpAndSettle();
    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FF000000',
    });

    await tapFamily(tester, '棕');
    expect(find.byTooltip('棕 900'), findsOneWidget);
    expect(find.byTooltip('棕 A100'), findsNothing);
  });

  testWidgets('a wide panel puts all shades in one row, as tall as swatches', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester, screenWidth: 1200);
    await tester.tap(find.byTooltip(colorPanelTextTool));
    await tester.pumpAndSettle();
    final swatchesExtent = harness.extents.last;

    await tester.tap(find.text('色系'));
    await tester.pumpAndSettle();

    expect(harness.extents.last, swatchesExtent);
    expect(
      tester.getCenter(find.byTooltip('红 A700')).dy,
      tester.getCenter(find.byTooltip('红 50')).dy,
    );
    // 色系一行放得下全部圆点时从起点排。
    final panel = tester.getRect(find.byType(DiaryColorPanel));
    expect(
      tester.getCenter(find.byTooltip('红色系')).dx,
      lessThan(panel.left + 50),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion switches families without animating', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final harness = await pumpColorPanel(tester);
    await openMaterialPage(tester);

    await tester.ensureVisible(find.byTooltip('蓝灰色系'));
    await tester.pump();
    await tester.tap(find.byTooltip('蓝灰色系'));
    await tester.pump();
    expect(find.byTooltip('蓝灰 50'), findsOneWidget);

    await tester.tap(find.byTooltip('蓝灰 800'));
    await tester.pump();
    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FF37474F',
    });
    expect(tester.takeException(), isNull);
  });
}
