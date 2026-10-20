import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_saved_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_custom_picker.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_material_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';

import '../../../support/diary_color_panel_harness.dart';

/// 颜色面板：卡片内展开、色板写入、目标切换、色板 / 色系 / 自定义页签与高度
/// 报告、窄屏表头与减少动画。色系页见 diary_color_material_page_test.dart，
/// 自定义页的取色行为见 diary_color_custom_picker_test.dart，我的颜色一行见
/// diary_color_saved_strip_test.dart。
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
    // 面板保持打开，便于继续调整；预设不存进我的颜色。
    expect(find.byType(DiaryColorPanel), findsOneWidget);
    expect(harness.edits, 0);
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

  testWidgets('the panel height does not depend on how many colors exist', (
    tester,
  ) async {
    // 宽屏 16 列：文字色有 5 种本篇颜色和 2 种我的颜色，背景色一个都没有；
    // 两种目标的面板一样高。
    final controller = colorPanelController('abcdef');
    for (var i = 0; i < 5; i++) {
      controller.formatText(i, 1, quill.ColorAttribute('#FF12345${i + 1}'));
    }
    final harness = await pumpColorPanel(
      tester,
      controller: controller,
      screenWidth: 1200,
      savedColors: const DiarySavedColors(
        text: <Color>[Color(0xFF112233), Color(0xFF445566)],
      ),
    );
    await openTextColorPanel(tester);
    final textExtent = harness.extents.last;
    final reports = harness.extents.length;

    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryColorPanel), findsOneWidget);
    expect(harness.extents.last, textExtent);
    expect(harness.extents, hasLength(reports));
    expect(
      tester.getSize(find.byType(DiaryFloatingToolbar)).height,
      kDiaryToolbarBarHeight + textExtent,
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

    // 360dp 下预设两行 + 我的颜色一行，与自定义页同高：换页时面板不跳。
    expect(find.byType(DiaryColorCustomPicker), findsOneWidget);
    expect(find.byTooltip('红'), findsNothing);
    expect(swatchesExtent, greaterThan(0));
    expect(harness.extents.last, swatchesExtent);
    expect(
      DiaryColorGridLayout.resolve(innerWidth: 320).height,
      kDiaryColorCustomPickerHeight,
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
          final tab = switch (mode) {
            DiaryColorPanelMode.swatches => null,
            DiaryColorPanelMode.material => '色系',
            DiaryColorPanelMode.custom => '自定义',
          };
          if (tab != null) {
            await tester.tap(find.text(tab));
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

  testWidgets('a 320dp English header fits the title and all three tabs', (
    tester,
  ) async {
    await pumpColorPanel(tester, screenWidth: 320, locale: const Locale('en'));
    await tester.tap(find.byTooltip('Background color'));
    await tester.pumpAndSettle();

    final panel = find.byType(DiaryColorPanel);
    // 三个页签优先完整显示；标题放不下时换成工具栏同款图标（荧光笔），名称
    // 留给长按提示与读屏，不显示半截的省略文字。
    expect(
      find.descendant(of: panel, matching: find.text('Background color')),
      findsNothing,
    );
    final title = find.descendant(
      of: panel,
      matching: find.byTooltip('Background color'),
    );
    expect(title, findsOneWidget);
    expect(find.bySemanticsLabel('Background color'), findsWidgets);
    for (final tab in <String>['Swatches', 'Material', 'Custom']) {
      final label = find.descendant(of: panel, matching: find.text(tab));
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        isFalse,
        reason: tab,
      );
      // 页签在 40dp 表头里，不越出面板右缘，字与按钮几乎不缩小。
      expect(
        tester.getRect(label).right,
        lessThanOrEqualTo(tester.getRect(panel).right),
      );
      expect(
        tester.getRect(label).width / tester.getSize(label).width,
        greaterThan(0.95),
        reason: tab,
      );
    }
    // 标题（图标）起点对齐第一个色块圆的左缘。
    final firstSwatch = find.byTooltip('No background');
    expect(
      tester.getTopLeft(title).dx,
      closeTo(tester.getCenter(firstSwatch).dx - 14, 0.5),
    );

    // 320dp 的色系页（色阶 7 格各 40dp）与背景色自定义页（多一条不透明度
    // 条）同样放得下。
    await tester.tap(find.text('Material'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorMaterialPage), findsOneWidget);
    expect(find.byTooltip('Red A700'), findsOneWidget);
    expect(
      tester.getRect(find.byTooltip('Red A700')).right,
      lessThanOrEqualTo(tester.getRect(panel).right),
    );
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorCustomPicker), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the title is written out whenever it fits', (tester) async {
    // 320dp 中文：标题与三个页签都完整显示，页签不缩小。
    await pumpColorPanel(tester, screenWidth: 320);
    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();

    final panel = find.byType(DiaryColorPanel);
    final title = find.descendant(of: panel, matching: find.text('背景颜色'));
    expect(title, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
      isFalse,
    );
    for (final tab in <String>['色板', '色系', '自定义']) {
      final label = find.descendant(of: panel, matching: find.text(tab));
      expect(
        tester.getRect(label).width,
        closeTo(tester.getSize(label).width, 0.01),
        reason: tab,
      );
    }
    expect(
      tester.getRect(title).right,
      lessThan(tester.getRect(find.text('色板')).left),
    );
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
