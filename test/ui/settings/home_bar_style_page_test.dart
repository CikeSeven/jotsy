import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_floating_bar.dart';
import 'package:node_diary/ui/settings/pages/home_bar_style_page.dart';
import 'package:node_diary/ui/settings/sections/settings_home_bar_style_tile.dart';
import 'package:node_diary/ui/settings/widgets/settings_option_tiles.dart';
import 'package:node_diary/ui/widgets/bottom_nav.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/home_bar_style_page_harness.dart';

Finder _materialOption(String label) => find.descendant(
  of: find.byType(ExpressiveButtonGroup<HomeBarMaterial>),
  matching: find.text(label),
);

const _glassCustom = HomeBarSettings(
  current: HomeBarStyle(
    material: HomeBarMaterial.glass,
    tint: HomeBarTint.custom,
    tintColor: 0xFF88AACC,
    // 两条线都打开、底栏描边用自定义色：320dp 检查要覆盖描边分组展开最多的
    // 样子（含二级的取色行）。
    topBarHairline: true,
    borderLine: HomeBarLineStyle(
      color: HomeBarLineColor.custom,
      customColor: 0xFF336699,
      opacity: 0.6,
      width: 1.0,
    ),
  ),
);

void main() {
  testWidgets('shows a miniature home preview above five option tabs', (
    tester,
  ) async {
    final (_, l10n) = await pumpHomeBarStylePage(tester);
    expect(find.byType(Tab), findsNWidgets(5));
    for (final label in <String>[
      l10n.homeBarStyleTabPresets,
      l10n.homeBarStyleTabMaterial,
      l10n.homeBarStyleTabFloating,
      l10n.homeBarStyleTabItems,
      l10n.homeBarStyleTabBehavior,
    ]) {
      expect(find.widgetWithText(Tab, label), findsOneWidget);
    }
    // 默认是实色：预览里是贴底的实色底栏。
    expect(find.byType(BottomNav), findsOneWidget);
    expect(find.byType(HomeFloatingBar), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, l10n.commonReset))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing glass reveals the glass rows, solid hides them', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabMaterial);
    expect(inHomeBarOptions(l10n.homeBarStyleGlassTopBars), findsNothing);

    await tapHomeBarOption(
      tester,
      _materialOption(l10n.homeBarStyleMaterialGlass),
    );
    expect(
      storedHomeBarSettings(settings).current.material,
      HomeBarMaterial.glass,
    );
    // 切到玻璃时默认的图标文字间距随之收紧。
    expect(
      storedHomeBarSettings(settings).current.labelGap,
      HomeBarStyle.glassLabelGap,
    );
    expect(inHomeBarOptions(l10n.homeBarStyleGlassTopBars), findsOneWidget);
    expect(inHomeBarOptions(l10n.homeBarStyleGlassFooter), findsOneWidget);
    expect(find.byType(HomeFloatingBar), findsOneWidget);

    // 自定义色调：起始色是当前中性底色（不透明），颜色行随之展开。
    await tapHomeBarOption(
      tester,
      find.descendant(
        of: find.byType(ExpressiveButtonGroup<HomeBarTint>),
        matching: find.text(l10n.styleEditorCustom),
      ),
    );
    final custom = storedHomeBarSettings(settings).current;
    expect(custom.tint, HomeBarTint.custom);
    expect(custom.tintColor, isNotNull);
    expect(custom.tintColor! >> 24, 0xFF);
    expect(inHomeBarOptions(l10n.homeBarStyleTintColor), findsOneWidget);

    await tapHomeBarOption(
      tester,
      _materialOption(l10n.homeBarStyleMaterialSolid),
    );
    expect(
      storedHomeBarSettings(settings).current.material,
      HomeBarMaterial.solid,
    );
    expect(storedHomeBarSettings(settings).current.labelGap, 4);
    expect(inHomeBarOptions(l10n.homeBarStyleGlassTopBars), findsNothing);
    expect(inHomeBarOptions(l10n.homeBarStyleTintColor), findsNothing);
    expect(find.byType(BottomNav), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the top bar hairline is its own switch in the outline group', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(
      tester,
      initial: const HomeBarSettings(
        current: HomeBarStyle(material: HomeBarMaterial.glass),
      ),
    );
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabMaterial);
    await scrollToHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleTopBarHairline),
    );
    expect(inHomeBarOptions(l10n.homeBarStyleTopBarHairline), findsOneWidget);
    // 与底栏描边并列在“描边”分组里（同一缩进），而不是挂在材质分组的
    // “顶栏也用玻璃”之下。
    expect(
      tester.getTopLeft(inHomeBarOptions(l10n.homeBarStyleTopBarHairline)).dx,
      tester.getTopLeft(inHomeBarOptions(l10n.homeBarStyleBorder)).dx,
    );
    expect(
      tester.getTopLeft(inHomeBarOptions(l10n.homeBarStyleTopBarHairline)).dy,
      greaterThan(
        tester.getTopLeft(inHomeBarOptions(l10n.homeBarStyleOutlineGroup)).dy,
      ),
    );

    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleTopBarHairline),
    );
    expect(storedHomeBarSettings(settings).current.topBarHairline, isTrue);
    expect(storedHomeBarSettings(settings).current.border, isTrue);

    // 底栏描边只写 border，不动顶栏分隔线。
    await tapHomeBarOption(tester, inHomeBarOptions(l10n.homeBarStyleBorder));
    expect(storedHomeBarSettings(settings).current.border, isFalse);
    expect(storedHomeBarSettings(settings).current.topBarHairline, isTrue);

    // 顶栏不用玻璃时分隔线这一行收起。
    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleGlassTopBars),
    );
    expect(storedHomeBarSettings(settings).current.glassTopBars, isFalse);
    expect(inHomeBarOptions(l10n.homeBarStyleTopBarHairline), findsNothing);
    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleGlassTopBars),
    );
    expect(inHomeBarOptions(l10n.homeBarStyleTopBarHairline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sliders preview while dragging and persist on release', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabItems);
    final finder = find.widgetWithText(
      SettingsSliderTile,
      l10n.homeBarStyleIconSize,
    );
    await scrollToHomeBarOption(tester, finder);
    final tile = tester.widget<SettingsSliderTile>(finder);
    tile.onChanged!(24);
    await tester.pump();
    expect(settings.homeBarStyleRaw, isNull);
    expect(find.text(l10n.diaryCardStyleValueDp('24')), findsOneWidget);

    tile.onChangeEnd!(24);
    await tester.pumpAndSettle();
    expect(storedHomeBarSettings(settings).current.iconSize, 24);
  });

  testWidgets('spacing sliders follow the label mode and the indicator', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabItems);
    expect(inHomeBarOptions(l10n.homeBarStyleItemsFooter), findsOneWidget);
    // 默认显示文字、胶囊指示器：有间距滑块，没有内边距滑块。
    expect(inHomeBarOptions(l10n.homeBarStyleLabelGap), findsOneWidget);
    expect(inHomeBarOptions(l10n.homeBarStyleBlockPadding), findsNothing);

    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleLabelsNever),
    );
    expect(
      storedHomeBarSettings(settings).current.labelMode,
      HomeBarLabelMode.never,
    );
    expect(inHomeBarOptions(l10n.homeBarStyleLabelGap), findsNothing);
    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleLabelsSelected),
    );
    expect(inHomeBarOptions(l10n.homeBarStyleLabelGap), findsOneWidget);

    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleIndicatorBlock),
    );
    expect(
      storedHomeBarSettings(settings).current.indicator,
      HomeBarIndicator.block,
    );
    final padding = find.widgetWithText(
      SettingsSliderTile,
      l10n.homeBarStyleBlockPadding,
    );
    await scrollToHomeBarOption(tester, padding);
    final tile = tester.widget<SettingsSliderTile>(padding);
    expect(tile.nested, isTrue);
    tile.onChanged!(10);
    await tester.pump();
    expect(storedHomeBarSettings(settings).current.blockPadding, 6);
    tile.onChangeEnd!(10);
    await tester.pumpAndSettle();
    expect(storedHomeBarSettings(settings).current.blockPadding, 10);

    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleIndicatorNone),
    );
    expect(inHomeBarOptions(l10n.homeBarStyleBlockPadding), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the floating tab offers to switch to glass when solid', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabFloating);
    expect(
      inHomeBarOptions(l10n.homeBarStyleFloatingSolidHint),
      findsOneWidget,
    );
    expect(inHomeBarOptions(l10n.homeBarStyleSizeGroup), findsNothing);

    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleSwitchToGlass),
    );
    expect(
      storedHomeBarSettings(settings).current.material,
      HomeBarMaterial.glass,
    );
    expect(
      storedHomeBarSettings(settings).current.labelGap,
      HomeBarStyle.glassLabelGap,
    );
    expect(inHomeBarOptions(l10n.homeBarStyleFloatingSolidHint), findsNothing);
    expect(inHomeBarOptions(l10n.homeBarStyleSizeGroup), findsOneWidget);

    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStyleFabInline),
    );
    expect(
      storedHomeBarSettings(settings).current.fabPlacement,
      HomeBarFabPlacement.inline,
    );
    expect(find.byType(HomeInlineCreateButton), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the behavior tab hides hide-on-scroll while solid', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabBehavior);
    expect(inHomeBarOptions(l10n.homeBarStyleHideOnScroll), findsNothing);
    expect(
      find.descendant(
        of: find.byType(TabBarView),
        matching: find.textContaining(l10n.homeBarStyleHideOnScrollSolidHint),
      ),
      findsOneWidget,
    );

    await tapHomeBarOption(
      tester,
      find.widgetWithText(SwitchListTile, l10n.homeBarStyleIndicatorFollows),
    );
    expect(
      storedHomeBarSettings(settings).behavior.indicatorFollowsSwipe,
      isTrue,
    );
    expect(storedHomeBarSettings(settings).current, HomeBarStyle.defaults);

    await settings.setHomeBarStyleRaw(
      storedHomeBarSettings(settings)
          .withCurrent(const HomeBarStyle(material: HomeBarMaterial.glass))
          .encode(),
    );
    await tester.pumpAndSettle();
    await tapHomeBarOption(
      tester,
      find.widgetWithText(SwitchListTile, l10n.homeBarStyleHideOnScroll),
    );
    expect(storedHomeBarSettings(settings).behavior.hideOnScroll, isTrue);
    expect(
      storedHomeBarSettings(settings).behavior.indicatorFollowsSwipe,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a preset applies with an undo snackbar', (tester) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStylePresetGlass),
    );
    expect(storedHomeBarSettings(settings).current, HomeBarPreset.glass.style);
    expect(find.byType(HomeFloatingBar), findsOneWidget);
    expect(
      find.text(l10n.styleEditorApplied(l10n.homeBarStylePresetGlass)),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(storedHomeBarSettings(settings).current, HomeBarStyle.defaults);
    expect(find.byType(BottomNav), findsOneWidget);
  });

  testWidgets('the appearance entry names the current style and opens it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = (await tester.runAsync(SettingsService.create))!;
    await tester.pumpWidget(
      homeBarStyleApp(
        settings,
        Scaffold(
          body: SettingsHomeBarStyleTile(
            settingsAsync: AsyncValue<SettingsService>.data(settings),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(
      find.text(l10n.homeBarStyleEntrySubtitle(l10n.homeBarStylePresetClassic)),
      findsOneWidget,
    );

    await settings.setHomeBarStyleRaw(_glassCustom.encode());
    await tester.pump();
    expect(
      find.text(
        l10n.homeBarStyleEntrySubtitle(
          l10n.homeBarStyleCustomName(l10n.homeBarStyleMaterialGlass),
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.homeBarStyleTitle));
    await tester.pumpAndSettle();
    expect(find.byType(HomeBarStylePage), findsOneWidget);
  });

  testWidgets('side by side the preview stays a phone-sized centred frame', (
    tester,
  ) async {
    await pumpHomeBarStylePage(tester, size: const Size(1184, 800));
    final bar = tester.getRect(find.byType(BottomNav));
    final pane = tester.getRect(find.byType(VerticalDivider));
    // 画框最宽 412，在预览栏（分隔线左侧）里水平居中。
    expect(bar.width, lessThanOrEqualTo(412));
    expect(bar.width, greaterThan(360));
    expect(bar.center.dx, moreOrLessEquals(pane.left / 2, epsilon: 1));
    expect(tester.takeException(), isNull);
  });

  for (final locale in const <Locale>[Locale('zh'), Locale('en')]) {
    for (final glass in <bool>[false, true]) {
      testWidgets('every tab fits a 320dp screen in ${locale.languageCode}'
          '${glass ? ' with glass' : ''}', (tester) async {
        final (_, l10n) = await pumpHomeBarStylePage(
          tester,
          locale: locale,
          size: const Size(320, 640),
          initial: glass ? _glassCustom : null,
        );
        for (final label in <String>[
          l10n.homeBarStyleTabPresets,
          l10n.homeBarStyleTabMaterial,
          l10n.homeBarStyleTabFloating,
          l10n.homeBarStyleTabItems,
          l10n.homeBarStyleTabBehavior,
        ]) {
          await openHomeBarStyleTab(tester, label);
          await tester.drag(find.byType(TabBarView), const Offset(0, -2000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
        }
      });
    }
  }
}
