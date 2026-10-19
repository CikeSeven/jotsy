import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_recent_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_custom_picker.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';

import '../../../support/diary_color_panel_harness.dart';

/// 颜色面板：卡片内展开、色板写入、目标切换、色板 / 自定义页签与高度报告、
/// 最近颜色的排列、窄屏表头与减少动画。自定义页的取色行为见
/// diary_color_custom_picker_test.dart。
void main() {
  setUpAll(loadColorPanelFonts);

  testWidgets('the text color tool opens the panel inside the card, no route', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester);
    final pushesBefore = harness.routes.pushes;

    await openTextColorPanel(tester);

    expect(find.byType(DiaryColorPanel), findsOneWidget);
    expect(harness.routes.pushes, pushesBefore);
    expect(find.byType(Dialog), findsNothing);
    expect(harness.extents.last, greaterThan(0));
    // 面板在工具栏一排的上方，默认停在色板页。
    expect(
      tester.getBottomLeft(find.byType(DiaryColorPanel)).dy,
      lessThan(tester.getTopLeft(find.byTooltip(colorPanelTextTool)).dy),
    );
    expect(find.byTooltip('红'), findsOneWidget);
    expect(find.byType(DiaryColorCustomPicker), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a preset writes the exact #AARRGGBB value', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester);
    await openTextColorPanel(tester);

    await tester.tap(find.byTooltip('红'));
    await tester.pumpAndSettle();

    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FFE5484D',
    });
    // 面板保持打开，便于继续调整；色板颜色不记入最近颜色。
    expect(find.byType(DiaryColorPanel), findsOneWidget);
    expect(harness.usedColors, isEmpty);
  });

  testWidgets('the default swatch clears the text color', (tester) async {
    final controller = colorPanelController();
    controller.formatSelection(const quill.ColorAttribute('#FF3B7BE8'));
    final harness = await pumpColorPanel(tester, controller: controller);
    await openTextColorPanel(tester);

    await tester.tap(find.byTooltip('默认颜色'));
    await tester.pumpAndSettle();

    expect(colorPanelAttributesAt(harness.controller, 0), isNull);
  });

  testWidgets('the other color tool switches the open panel to its target', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester);
    await openTextColorPanel(tester);
    expect(find.text('文字颜色'), findsOneWidget);
    final reportsBefore = harness.extents.length;

    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
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
    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'background': '#4DFF6369',
    });
  });

  testWidgets('switching targets re-reports the extent when the grid changes', (
    tester,
  ) async {
    // 宽屏 16 列：预设占一行；文字色另有 5 种自定义颜色，第二行才放得下。
    final controller = colorPanelController('abcdef');
    for (var i = 0; i < 5; i++) {
      controller.formatText(i, 1, quill.ColorAttribute('#FF12345${i + 1}'));
    }
    final harness = await pumpColorPanel(
      tester,
      controller: controller,
      screenWidth: 1200,
    );
    await openTextColorPanel(tester);
    final textExtent = harness.extents.last;

    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryColorPanel), findsOneWidget);
    expect(harness.extents.last, textExtent - DiaryColorGridLayout.cellHeight);
    expect(
      tester.getSize(find.byType(DiaryFloatingToolbar)).height,
      kDiaryToolbarBarHeight + harness.extents.last,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the custom tab swaps the page and reports its height', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester);
    await openTextColorPanel(tester);
    final swatchesExtent = harness.extents.last;

    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();

    // 360dp 下色板两行（80dp），自定义页 128dp。
    expect(find.byType(DiaryColorCustomPicker), findsOneWidget);
    expect(find.byTooltip('红'), findsNothing);
    expect(
      harness.extents.last,
      swatchesExtent +
          kDiaryColorCustomPickerHeight -
          2 * DiaryColorGridLayout.cellHeight,
    );
    expect(
      tester.getSize(find.byType(DiaryFloatingToolbar)).height,
      kDiaryToolbarBarHeight + harness.extents.last,
    );

    // 换目标、收起再打开都停在自定义页。
    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorCustomPicker), findsOneWidget);
    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();
    await openTextColorPanel(tester);
    expect(find.byType(DiaryColorCustomPicker), findsOneWidget);

    await tester.tap(find.text('色板'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('红'), findsOneWidget);
    expect(harness.extents.last, swatchesExtent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent colors come after the presets, newest first', (
    tester,
  ) async {
    final controller = colorPanelController();
    controller.formatText(0, 1, const quill.ColorAttribute('#FF778899'));
    // 最近颜色里也有这篇用过的颜色：只出现一次，排在最近颜色的位置。
    controller.formatText(1, 1, const quill.ColorAttribute('#FF445566'));
    await pumpColorPanel(
      tester,
      controller: controller,
      recentColors: const DiaryRecentColors(
        text: <Color>[Color(0xFF112233), Color(0xFF445566)],
        background: <Color>[Color(0x4DABCDEF)],
      ),
    );
    await openTextColorPanel(tester);

    final order = <String>['颜色 #112233', '颜色 #445566', '颜色 #778899'];
    for (final label in order) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }
    double x(String label) => tester.getCenter(find.byTooltip(label)).dx;
    // 同一行内从左到右（360dp 每行 8 格：预设之后的第二行）。
    expect(x(order[0]), lessThan(x(order[1])));
    expect(x(order[1]), lessThan(x(order[2])));
    expect(find.byTooltip('颜色 #ABCDEF'), findsNothing);

    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();
    expect(find.byTooltip('颜色 #ABCDEF'), findsOneWidget);
    expect(find.byTooltip(order[0]), findsNothing);
  });

  testWidgets('tapping the same tool again closes the panel', (tester) async {
    final harness = await pumpColorPanel(tester);
    await openTextColorPanel(tester);
    expect(harness.extents.last, greaterThan(0));

    // 换到背景颜色工具：面板保持打开，只换目标。
    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();
    expect(find.byTooltip('无背景色'), findsOneWidget);

    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorPanel), findsNothing);
    expect(harness.extents.last, 0);
  });

  testWidgets('a color tool inside More opens the color panel under More', (
    tester,
  ) async {
    final harness = await pumpColorPanel(
      tester,
      order: kDefaultDiaryToolbarOrder,
    );
    await tester.tap(find.byTooltip(colorPanelMoreTooltip));
    await tester.pumpAndSettle();
    final moreExtent = harness.extents.last;

    await tester.tap(find.byTooltip(colorPanelTextTool));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryColorPanel), findsOneWidget);
    expect(find.byTooltip('插入图片'), findsNothing);
    expect(harness.extents.last, isNot(moreExtent));
    // 「更多」仍是展开态，再点一下整块收起。
    expect(find.byTooltip(colorPanelHideMoreTooltip), findsOneWidget);
    await tester.tap(find.byTooltip(colorPanelHideMoreTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorPanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening the recording panel closes the color panel at once', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester);
    await openTextColorPanel(tester);

    await pumpColorPanel(tester, recordingOpen: true, reuse: harness);

    expect(find.byType(DiaryColorPanel), findsNothing);
    expect(harness.extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[360, 1200]) {
    for (final mode in DiaryColorPanelMode.values) {
      testWidgets(
        'the ${mode.name} page opens in a ${width.toInt()}dp toolbar',
        (tester) async {
          final harness = await pumpColorPanel(
            tester,
            screenWidth: width,
            order: kDefaultDiaryToolbarOrder,
          );
          if (width == 360) {
            // 窄屏：颜色工具收在「更多」里。
            await tester.tap(find.byTooltip(colorPanelMoreTooltip));
            await tester.pumpAndSettle();
          } else {
            expect(find.byTooltip(colorPanelMoreTooltip), findsNothing);
          }
          await openTextColorPanel(tester);
          if (mode == DiaryColorPanelMode.custom) {
            await tester.tap(find.text('自定义'));
            await tester.pumpAndSettle();
          }

          expect(find.byType(DiaryColorPanel), findsOneWidget);
          expect(harness.extents.last, greaterThan(0));
          final toolbarHeight = tester
              .getSize(find.byType(DiaryFloatingToolbar))
              .height;
          expect(toolbarHeight, kDiaryToolbarBarHeight + harness.extents.last);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('a 320dp English header fits the title and both tabs', (
    tester,
  ) async {
    await pumpColorPanel(tester, screenWidth: 320, locale: const Locale('en'));
    await tester.tap(find.byTooltip('Background color'));
    await tester.pumpAndSettle();

    final panel = find.byType(DiaryColorPanel);
    final title = find.descendant(
      of: panel,
      matching: find.text('Background color'),
    );
    // 标题单行（窄屏英文可能省略），页签始终完整。
    expect(tester.getSize(title).height, lessThanOrEqualTo(40));
    for (final tab in <String>['Swatches', 'Custom']) {
      final label = find.descendant(of: panel, matching: find.text(tab));
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        isFalse,
        reason: tab,
      );
      // 页签在 40dp 表头里，不越出面板右缘。
      expect(
        tester.getRect(label).right,
        lessThanOrEqualTo(tester.getRect(panel).right),
      );
    }
    // 标题起点对齐第一个色块圆的左缘。
    final firstSwatch = find.byTooltip('No background');
    expect(
      tester.getTopLeft(title).dx,
      closeTo(tester.getCenter(firstSwatch).dx - 14, 0.5),
    );

    // 320dp 的背景色自定义页（多一条不透明度条）同样放得下。
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorCustomPicker), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduce motion switches targets, tabs and panels without errors',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      // 颜色工具常驻，其余工具仍有一部分收在「更多」里。
      await pumpColorPanel(tester);

      await tester.tap(find.byTooltip(colorPanelTextTool));
      await tester.pump();
      await tester.pump();
      expect(find.byType(DiaryColorPanel), findsOneWidget);
      await tester.tap(find.text('自定义'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(DiaryColorCustomPicker), findsOneWidget);
      await tester.tap(find.byTooltip(colorPanelBackgroundTool));
      await tester.pump();
      await tester.pump();
      expect(find.text('背景颜色'), findsOneWidget);
      // 颜色面板开着时点「更多」换成「更多」面板，再点收起。
      await tester.tap(find.byTooltip(colorPanelMoreTooltip));
      await tester.pump();
      await tester.pump();
      expect(find.byType(DiaryColorPanel), findsNothing);
      await tester.tap(find.byTooltip(colorPanelHideMoreTooltip));
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip(colorPanelMoreTooltip), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
