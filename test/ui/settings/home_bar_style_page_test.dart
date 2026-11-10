import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_floating_bar.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';
import 'package:node_diary/ui/settings/pages/home_bar_style_page.dart';
import 'package:node_diary/ui/settings/sections/settings_home_bar_style_tile.dart';
import 'package:node_diary/ui/settings/widgets/settings_option_tiles.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/home_bar_style_page_harness.dart';

/// 一套不属于任何预设的样式：所有会展开的行（顶栏分隔线）都展开，320dp
/// 检查覆盖选项最多的样子。
const _custom = HomeBarSettings(
  current: HomeBarStyle(
    tint: HomeBarTint.theme,
    tintOpacity: 0.6,
    topBarHairline: true,
    labelMode: HomeBarLabelMode.selected,
    fabPlacement: HomeBarFabPlacement.inline,
  ),
);

/// 预览里的悬浮胶囊。
Finder get _pill => find.descendant(
  of: find.byType(HomeFloatingBar),
  matching: find.byType(GlassSurface),
);

void main() {
  testWidgets('shows a miniature home preview above three option tabs', (
    tester,
  ) async {
    final (_, l10n) = await pumpHomeBarStylePage(tester);
    expect(find.byType(Tab), findsNWidgets(3));
    for (final label in <String>[
      l10n.homeBarStyleTabPresets,
      l10n.homeBarStyleTabAppearance,
      l10n.homeBarStyleTabBehavior,
    ]) {
      expect(find.widgetWithText(Tab, label), findsOneWidget);
    }
    // 预览里是悬浮的玻璃胶囊（底栏只有这一种形态）。
    expect(find.byType(HomeFloatingBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, l10n.commonReset))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the appearance tab holds every look option and no sizes', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabAppearance);
    for (final title in <String>[
      l10n.homeBarStyleTint,
      l10n.homeBarStyleOpacity,
      l10n.homeBarStyleTopBarHairline,
    ]) {
      expect(inHomeBarOptions(title), findsOneWidget, reason: title);
    }
    // 几何是固定的：整页只有“不透明度”一个滑块。
    expect(
      find.descendant(
        of: find.byType(TabBarView),
        matching: find.byType(SettingsSliderTile),
      ),
      findsOneWidget,
    );

    // 色调只有中性 / 主题色两档。
    final tint = find.byType(ExpressiveButtonGroup<HomeBarTint>);
    expect(
      tester.widget<ExpressiveButtonGroup<HomeBarTint>>(tint).segments,
      hasLength(2),
    );
    await tapHomeBarOption(
      tester,
      find.descendant(
        of: tint,
        matching: find.text(l10n.homeBarStyleTintTheme),
      ),
    );
    expect(
      storedHomeBarSettings(settings).current,
      HomeBarStyle.defaults.copyWith(tint: HomeBarTint.theme),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the top bar hairline is a plain switch (top bars are always '
      'glass)', (tester) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabAppearance);
    final hairline = find.widgetWithText(
      SwitchListTile,
      l10n.homeBarStyleTopBarHairline,
    );
    // 顶栏恒为玻璃：分隔线是一个普通的开关，不再从属于任何开关。
    expect(hairline.hitTestable(), findsOneWidget);
    await tapHomeBarOption(tester, hairline);
    expect(storedHomeBarSettings(settings).current.topBarHairline, isTrue);
    await tapHomeBarOption(tester, hairline);
    expect(storedHomeBarSettings(settings).current.topBarHairline, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the opacity slider previews while dragging and persists on '
      'release', (tester) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabAppearance);
    final finder = find.widgetWithText(
      SettingsSliderTile,
      l10n.homeBarStyleOpacity,
    );
    await scrollToHomeBarOption(tester, finder);
    final tile = tester.widget<SettingsSliderTile>(finder);
    tile.onChanged!(0.5000001);
    await tester.pump();
    expect(settings.homeBarStyleRaw, isNull);
    expect(find.text(l10n.diaryCardStyleValuePercent('50')), findsOneWidget);
    // 预览里的玻璃跟着草稿变。
    expect(tester.widget<GlassSurface>(_pill).fill.a, closeTo(0.5, 0.005));

    tile.onChangeEnd!(0.5000001);
    await tester.pumpAndSettle();
    // 规整到百分位：不留浮点尾数。
    expect(storedHomeBarSettings(settings).current.tintOpacity, 0.5);
  });

  testWidgets('labels and the create button reshape the preview pill', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabAppearance);
    expect(tester.getSize(_pill).height, 60);

    await tapHomeBarOption(
      tester,
      find.descendant(
        of: find.byType(ExpressiveButtonGroup<HomeBarLabelMode>),
        matching: find.text(l10n.homeBarStyleLabelsNever),
      ),
    );
    expect(
      storedHomeBarSettings(settings).current,
      HomeBarPreset.compact.style,
    );
    expect(tester.getSize(_pill).height, 54);

    expect(find.byType(HomeInlineCreateButton).hitTestable(), findsNothing);
    await tapHomeBarOption(
      tester,
      find.descendant(
        of: find.byType(ExpressiveButtonGroup<HomeBarFabPlacement>),
        matching: find.text(l10n.homeBarStyleFabInline),
      ),
    );
    expect(
      storedHomeBarSettings(settings).current.fabPlacement,
      HomeBarFabPlacement.inline,
    );
    expect(tester.getSize(find.byType(HomeInlineCreateButton)).width, 54);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the behavior tab always offers both switches', (tester) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabBehavior);

    await tapHomeBarOption(
      tester,
      find.widgetWithText(SwitchListTile, l10n.homeBarStyleIndicatorFollows),
    );
    expect(
      storedHomeBarSettings(settings).behavior.indicatorFollowsSwipe,
      isTrue,
    );
    expect(storedHomeBarSettings(settings).current, HomeBarStyle.defaults);

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
    // 没有“经典”预设了：第一个预设“玻璃”就是默认样式。
    expect(inHomeBarOptions('经典'), findsNothing);
    await tapHomeBarOption(
      tester,
      inHomeBarOptions(l10n.homeBarStylePresetFrosted),
    );
    expect(
      storedHomeBarSettings(settings).current,
      HomeBarPreset.frosted.style,
    );
    expect(
      find.text(l10n.styleEditorApplied(l10n.homeBarStylePresetFrosted)),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(storedHomeBarSettings(settings).current, HomeBarStyle.defaults);
    expect(find.byType(HomeFloatingBar), findsOneWidget);
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
      find.text(l10n.homeBarStyleEntrySubtitle(l10n.homeBarStylePresetGlass)),
      findsOneWidget,
    );

    await settings.setHomeBarStyleRaw(_custom.encode());
    await tester.pump();
    expect(
      find.text(l10n.homeBarStyleEntrySubtitle(l10n.styleEditorCustom)),
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
    final bar = tester.getRect(find.byType(HomeFloatingBar));
    final pane = tester.getRect(find.byType(VerticalDivider));
    // 画框最宽 412，在预览栏（分隔线左侧）里水平居中；悬浮栏的槽位两侧各
    // 收进 16，胶囊在其中居中。
    expect(bar.width, lessThanOrEqualTo(412 - 32));
    expect(bar.width, greaterThan(360 - 32));
    expect(bar.center.dx, moreOrLessEquals(pane.left / 2, epsilon: 1));
    expect(
      tester.getRect(_pill).center.dx,
      moreOrLessEquals(pane.left / 2, epsilon: 1),
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final custom in <bool>[false, true]) {
      testWidgets('every tab fits a 320dp screen in ${locale.languageCode}'
          '${custom ? ' with every row expanded' : ''}', (tester) async {
        final (_, l10n) = await pumpHomeBarStylePage(
          tester,
          locale: locale,
          size: const Size(320, 640),
          initial: custom ? _custom : null,
        );
        for (final label in <String>[
          l10n.homeBarStyleTabPresets,
          l10n.homeBarStyleTabAppearance,
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
