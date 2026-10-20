import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_saved_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_custom_picker.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_saved_strip.dart';

import '../../../support/diary_color_panel_harness.dart';

/// 色板页的“我的颜色”一行：排列、套用、新建入口、管理（移除 / 收藏 /
/// 长按进入 / 自动退出）与空状态。保存规则见 diary_saved_colors_test.dart，
/// 自定义页的保存见 diary_color_custom_picker_test.dart。
void main() {
  setUpAll(loadColorPanelFonts);

  const a = Color(0xFF112233);
  const b = Color(0xFF445566);
  const threeSaved = DiarySavedColors(
    text: <Color>[a, b],
    background: <Color>[Color(0x4DABCDEF)],
  );

  Finder label(String text) => find.bySemanticsLabel(text);
  double x(WidgetTester tester, String text) =>
      tester.getCenter(label(text)).dx;

  testWidgets('saved colors come first, then other colors of this entry', (
    tester,
  ) async {
    final controller = colorPanelController();
    controller.formatText(0, 1, const quill.ColorAttribute('#FF778899'));
    // 这篇也用过一个已保存的颜色：只出现一次，在我的颜色里。
    controller.formatText(1, 1, const quill.ColorAttribute('#FF445566'));
    await pumpColorPanel(
      tester,
      controller: controller,
      savedColors: threeSaved,
    );
    await openTextColorPanel(tester);

    expect(label('我的颜色 #112233'), findsOneWidget);
    expect(label('我的颜色 #445566'), findsOneWidget);
    expect(label('本篇用过的颜色 #778899'), findsOneWidget);
    expect(label('本篇用过的颜色 #445566'), findsNothing);
    expect(x(tester, '我的颜色 #112233'), lessThan(x(tester, '我的颜色 #445566')));
    expect(x(tester, '我的颜色 #445566'), lessThan(x(tester, '本篇用过的颜色 #778899')));
    // 这一行在预设下方。
    expect(
      tester.getCenter(label('我的颜色 #112233')).dy,
      greaterThan(tester.getCenter(find.byTooltip('灰')).dy),
    );
    expect(find.byTooltip('管理我的颜色'), findsOneWidget);

    // 背景色有自己的一组。
    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();
    expect(label('我的颜色 #ABCDEF'), findsOneWidget);
    expect(label('我的颜色 #112233'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a saved color applies it and leaves the list alone', (
    tester,
  ) async {
    final harness = await pumpColorPanel(tester, savedColors: threeSaved);
    await openTextColorPanel(tester);

    await tester.tap(label('我的颜色 #445566'));
    await tester.pumpAndSettle();

    expect(colorPanelAttributesAt(harness.controller, 0), <String, dynamic>{
      'color': '#FF445566',
    });
    expect(harness.edits, 0);
    expect(harness.saved.value, threeSaved);
    expect(
      tester.getSemantics(label('我的颜色 #445566')),
      isSemantics(isSelected: true),
    );
  });

  testWidgets('with nothing saved the row explains itself and + goes custom', (
    tester,
  ) async {
    await pumpColorPanel(tester);
    await openTextColorPanel(tester);

    expect(find.text('在「自定义」调出的颜色会保存在这里'), findsOneWidget);
    expect(find.byTooltip('管理我的颜色'), findsNothing);

    await tester.tap(find.byTooltip('新建颜色'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorCustomPicker), findsOneWidget);
    expect(find.byType(DiaryColorSavedStrip), findsNothing);
  });

  testWidgets('managing removes saved colors and keeps colors of the entry', (
    tester,
  ) async {
    final controller = colorPanelController();
    controller.formatText(0, 1, const quill.ColorAttribute('#FF778899'));
    final harness = await pumpColorPanel(
      tester,
      controller: controller,
      savedColors: threeSaved,
    );
    await openTextColorPanel(tester);

    await tester.tap(find.byTooltip('管理我的颜色'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('完成'), findsOneWidget);
    expect(label('移除 #112233'), findsOneWidget);
    expect(label('保存 #778899 到我的颜色'), findsOneWidget);

    // 管理中点我的颜色是移除，不是套用。
    await tester.tap(label('移除 #112233'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 收拢途中还在原位。
    expect(label('移除 #112233'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(label('移除 #112233'), findsNothing);
    expect(harness.saved.value.text, <Color>[b]);
    expect(colorPanelAttributesAt(harness.controller, 1), isNull);

    // 点本篇颜色是收藏：排到我的颜色最前。
    await tester.tap(label('保存 #778899 到我的颜色'));
    await tester.pumpAndSettle();
    expect(harness.saved.value.text, <Color>[const Color(0xFF778899), b]);
    expect(label('移除 #778899'), findsOneWidget);
    expect(label('保存 #778899 到我的颜色'), findsNothing);
    expect(x(tester, '移除 #778899'), lessThan(x(tester, '移除 #445566')));

    await tester.tap(find.byTooltip('完成'));
    await tester.pumpAndSettle();
    expect(label('我的颜色 #778899'), findsOneWidget);
    expect(find.byTooltip('管理我的颜色'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press enters managing; removing the last color ends it', (
    tester,
  ) async {
    final harness = await pumpColorPanel(
      tester,
      savedColors: const DiarySavedColors(text: <Color>[a]),
    );
    await openTextColorPanel(tester);

    await tester.longPress(label('我的颜色 #112233'));
    await tester.pumpAndSettle();
    // 长按不会顺带套用颜色。
    expect(colorPanelAttributesAt(harness.controller, 0), isNull);
    expect(find.byTooltip('完成'), findsOneWidget);

    await tester.tap(label('移除 #112233'));
    await tester.pumpAndSettle();
    expect(harness.saved.value.isEmpty, isTrue);
    expect(find.text('在「自定义」调出的颜色会保存在这里'), findsOneWidget);
    expect(find.byTooltip('完成'), findsNothing);
    expect(find.byTooltip('管理我的颜色'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching targets leaves managing', (tester) async {
    await pumpColorPanel(tester, savedColors: threeSaved);
    await openTextColorPanel(tester);
    await tester.tap(find.byTooltip('管理我的颜色'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(colorPanelBackgroundTool));
    await tester.pumpAndSettle();
    expect(find.byTooltip('完成'), findsNothing);
    expect(label('我的颜色 #ABCDEF'), findsOneWidget);
  });

  testWidgets('a long list scrolls sideways with half a swatch peeking', (
    tester,
  ) async {
    final many = DiarySavedColors(
      text: <Color>[for (var i = 0; i < 10; i++) Color(0xFF203040 + i)],
    );
    await pumpColorPanel(tester, savedColors: many);
    await openTextColorPanel(tester);

    final strip = find.byType(DiaryColorSavedStrip);
    final manage = tester.getRect(find.byTooltip('管理我的颜色'));
    final last = label('我的颜色 #203049');
    // 最后一个在可见范围外；滑过去就能点到。
    expect(tester.getCenter(last).dx, greaterThan(manage.left));
    await tester.drag(
      find.descendant(of: strip, matching: find.byType(Scrollable)),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getCenter(last).dx, lessThan(manage.left));
    expect(tester.takeException(), isNull);
  });
}
