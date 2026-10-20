import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/settings/widgets/settings_option_tiles.dart';
import 'package:node_diary/ui/settings/widgets/style_editor/style_custom_color_tile.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';

import '../../support/home_bar_style_page_harness.dart';

const _glass = HomeBarSettings(
  current: HomeBarStyle(material: HomeBarMaterial.glass),
);

/// 颜色来源按钮组里的某个选项；[index] 0 为底栏描边、1 为顶栏分隔线。
Finder _lineColorOption(String label, {int index = 0}) => find
    .descendant(
      of: find.byType(ExpressiveButtonGroup<HomeBarLineColor>).at(index),
      matching: find.text(label),
    )
    .first;

Finder _slider(String title) =>
    find.widgetWithText(SettingsSliderTile, title).first;

void main() {
  testWidgets('the outline group is hidden in solid and shown in glass', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabMaterial);
    expect(inHomeBarOptions(l10n.homeBarStyleOutlineGroup), findsNothing);
    expect(inHomeBarOptions(l10n.homeBarStyleBorder), findsNothing);

    await tapHomeBarOption(
      tester,
      find.descendant(
        of: find.byType(ExpressiveButtonGroup<HomeBarMaterial>),
        matching: find.text(l10n.homeBarStyleMaterialGlass),
      ),
    );
    await scrollToHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleOutlineGroup),
    );
    expect(inHomeBarOptions(l10n.homeBarStyleOutlineGroup), findsOneWidget);
    expect(inHomeBarOptions(l10n.homeBarStyleBorder), findsOneWidget);
    expect(
      storedHomeBarSettings(settings).current.material,
      HomeBarMaterial.glass,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('line rows appear only while their switch is on', (tester) async {
    final (settings, l10n) = await pumpHomeBarStylePage(
      tester,
      initial: _glass,
    );
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabMaterial);
    await scrollToHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleLineWidth),
    );
    // 底栏描边默认打开：一组从属行；顶栏分隔线默认关闭：没有第二组。
    expect(inHomeBarOptions(l10n.homeBarStyleLineColor), findsOneWidget);
    expect(inHomeBarOptions(l10n.homeBarStyleLineWidth), findsOneWidget);
    final colorRow = find.widgetWithText(
      SettingsChoiceTile,
      l10n.homeBarStyleLineColor,
    );
    expect(tester.widget<SettingsChoiceTile>(colorRow).nested, isTrue);
    expect(
      tester
          .widget<SettingsSliderTile>(_slider(l10n.homeBarStyleLineWidth))
          .nested,
      isTrue,
    );
    // 没选自定义时不出现取色行。
    expect(inHomeBarOptions(l10n.homeBarStyleLineCustomColor), findsNothing);

    await tapHomeBarOption(tester, inHomeBarOptions(l10n.homeBarStyleBorder));
    expect(storedHomeBarSettings(settings).current.border, isFalse);
    expect(inHomeBarOptions(l10n.homeBarStyleLineColor), findsNothing);
    expect(inHomeBarOptions(l10n.homeBarStyleLineWidth), findsNothing);

    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleTopBarHairline),
    );
    expect(storedHomeBarSettings(settings).current.topBarHairline, isTrue);
    await scrollToHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleLineWidth),
    );
    expect(inHomeBarOptions(l10n.homeBarStyleLineColor), findsOneWidget);
    // 关掉开关不清除调整：底栏描边的线条样式仍是默认值，没被改写。
    expect(
      storedHomeBarSettings(settings).current.borderLine,
      HomeBarLineStyle.borderDefaults,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the top bar divider is hidden while glass top bars is off', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(
      tester,
      initial: const HomeBarSettings(
        current: HomeBarStyle(
          material: HomeBarMaterial.glass,
          glassTopBars: false,
          topBarHairline: true,
        ),
      ),
    );
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabMaterial);
    await scrollToHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleBorder),
    );
    expect(inHomeBarOptions(l10n.homeBarStyleTopBarHairline), findsNothing);
    // 只有底栏描边的一组从属行，分隔线的从属行随它一起收起。
    expect(inHomeBarOptions(l10n.homeBarStyleLineColor), findsOneWidget);

    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleGlassTopBars),
    );
    expect(storedHomeBarSettings(settings).current.glassTopBars, isTrue);
    await scrollToHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleTopBarHairline),
    );
    expect(inHomeBarOptions(l10n.homeBarStyleTopBarHairline), findsOneWidget);
    await scrollToHomeBarOption(
      tester,
      find.byType(ExpressiveButtonGroup<HomeBarLineColor>).at(1),
    );
    expect(
      find.byType(ExpressiveButtonGroup<HomeBarLineColor>),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a color source saves it; custom reveals the picker', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(
      tester,
      initial: _glass,
    );
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabMaterial);

    await tapHomeBarOption(
      tester,
      _lineColorOption(l10n.homeBarStyleLineColorHighlight),
    );
    expect(
      storedHomeBarSettings(settings).current.borderLine.color,
      HomeBarLineColor.highlight,
    );
    expect(
      storedHomeBarSettings(settings).current.borderLine.customColor,
      isNull,
    );

    await tapHomeBarOption(tester, _lineColorOption(l10n.styleEditorCustom));
    final line = storedHomeBarSettings(settings).current.borderLine;
    expect(line.color, HomeBarLineColor.custom);
    // 起始色是切换前这条线的颜色来源（高光）在浅色主题下的颜色，不透明。
    final scheme = Theme.of(
      tester.element(find.byType(TabBarView)),
    ).colorScheme;
    expect(line.customColor, scheme.surfaceContainerLowest.toARGB32());
    expect(line.customColor! >> 24, 0xFF);
    // 其余字段不动。
    expect(line.opacity, HomeBarLineStyle.borderDefaults.opacity);
    expect(line.width, HomeBarLineStyle.borderDefaults.width);

    final tile = find.widgetWithText(
      StyleCustomColorTile,
      l10n.homeBarStyleLineCustomColor,
    );
    await scrollToHomeBarOption(tester, tile);
    expect(tile, findsOneWidget);
    final widget = tester.widget<StyleCustomColorTile>(tile);
    expect(widget.nested && widget.deep, isTrue);
    expect(widget.light, line.customColor);

    // 换回默认：取色行收起，自定义色保留（再切回来时还是它）。
    await tapHomeBarOption(
      tester,
      _lineColorOption(l10n.homeBarStyleLineColorTheme),
    );
    expect(tile, findsNothing);
    expect(
      storedHomeBarSettings(settings).current.borderLine.customColor,
      line.customColor,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('line sliders preview while dragging and persist on release', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(
      tester,
      initial: _glass,
    );
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabMaterial);

    final width = _slider(l10n.homeBarStyleLineWidth);
    await scrollToHomeBarOption(tester, width);
    final widthTile = tester.widget<SettingsSliderTile>(width);
    expect(widthTile.min, HomeBarStyleLimits.lineWidth.min);
    expect(widthTile.max, HomeBarStyleLimits.lineWidth.max);
    expect(find.text(l10n.diaryCardStyleValueDp('1.0')), findsOneWidget);
    widthTile.onChanged!(2.0000001);
    await tester.pump();
    // 拖动中只改草稿：没写盘，标签已经跟着变。
    expect(storedHomeBarSettings(settings).current.borderLine.width, 1.0);
    expect(find.text(l10n.diaryCardStyleValueDp('2.0')), findsOneWidget);
    widthTile.onChangeEnd!(2.0000001);
    await tester.pumpAndSettle();
    expect(storedHomeBarSettings(settings).current.borderLine.width, 2.0);

    final opacity = find.widgetWithText(
      SettingsSliderTile,
      l10n.homeBarStyleOpacity,
    );
    // 第一个“不透明度”是玻璃底色的，描边的在后面。
    final lineOpacity = opacity.at(1);
    await scrollToHomeBarOption(tester, lineOpacity);
    final opacityTile = tester.widget<SettingsSliderTile>(lineOpacity);
    expect(opacityTile.min, HomeBarStyleLimits.lineOpacity.min);
    opacityTile.onChanged!(0.85);
    await tester.pump();
    expect(storedHomeBarSettings(settings).current.borderLine.opacity, 0.6);
    opacityTile.onChangeEnd!(0.85);
    await tester.pumpAndSettle();
    final stored = storedHomeBarSettings(settings).current;
    expect(stored.borderLine.opacity, 0.85);
    // 玻璃底色的不透明度没被牵动。
    expect(stored.tintOpacity, HomeBarStyle.defaults.tintOpacity);
    expect(stored.topBarLine, HomeBarLineStyle.topBarDefaults);
    expect(tester.takeException(), isNull);
  });
}
