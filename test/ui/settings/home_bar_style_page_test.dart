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

  testWidgets('the appearance tab holds every look option and no bar '
      'height', (tester) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabAppearance);
    // 自上而下走一遍（列表是懒构建的）：(标题, 是否滑块)。
    final rows = <(String, bool)>[
      (l10n.homeBarStyleTint, false),
      (l10n.homeBarStyleOpacity, true),
      (l10n.homeBarStyleTopBarHairline, false),
      (l10n.homeBarStyleRoundness, true),
      (l10n.homeBarStyleItemWidth, true),
      (l10n.homeBarStyleItemInset, true),
      (l10n.homeBarStyleIconSize, true),
      (l10n.homeBarStyleLabels, false),
      (l10n.homeBarStyleLabelSize, true),
      (l10n.homeBarStyleLabelGap, true),
      (l10n.homeBarStyleFabGroup, false),
    ];
    final seenSliders = <String>{};
    for (final (title, isSlider) in rows) {
      final finder = isSlider
          ? find.widgetWithText(SettingsSliderTile, title)
          : inHomeBarOptions(title);
      await scrollToHomeBarOption(tester, finder);
      expect(finder, findsOneWidget, reason: title);
      for (final element
          in find
              .descendant(
                of: find.byType(TabBarView),
                matching: find.byType(SettingsSliderTile),
              )
              .evaluate()) {
        seenSliders.add((element.widget as SettingsSliderTile).title);
      }
    }
    // 栏高与指示器圆角由这些推导，不单独开放：滑块只有上面这七个。
    expect(seenSliders, <String>{
      for (final (title, isSlider) in rows)
        if (isSlider) title,
    });
    await tester.scrollUntilVisible(
      find.byType(ExpressiveButtonGroup<HomeBarTint>),
      -120,
      scrollable: find
          .descendant(
            of: find.byType(TabBarView),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first,
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

  testWidgets('shape sliders reshape the preview and persist snapped '
      'values', (tester) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabAppearance);
    final roundness = find.widgetWithText(
      SettingsSliderTile,
      l10n.homeBarStyleRoundness,
    );
    await scrollToHomeBarOption(tester, roundness);
    final tile = tester.widget<SettingsSliderTile>(roundness);
    // 默认是完整胶囊：滑块在最右端，显示 100%。
    expect(tile.value, 1);
    tile.onChanged!(0.4499999);
    await tester.pump();
    expect(settings.homeBarStyleRaw, isNull);
    expect(
      tester.widget<GlassSurface>(_pill).borderRadius,
      BorderRadius.circular(0.45 * 30),
    );
    tile.onChangeEnd!(0.4499999);
    await tester.pumpAndSettle();
    expect(
      storedHomeBarSettings(settings).current,
      HomeBarPreset.rounded.style,
    );

    final inset = find.widgetWithText(
      SettingsSliderTile,
      l10n.homeBarStyleItemInset,
    );
    await scrollToHomeBarOption(tester, inset);
    tester.widget<SettingsSliderTile>(inset).onChangeEnd!(3.6);
    await tester.pumpAndSettle();
    expect(storedHomeBarSettings(settings).current.itemInset, 4);
    // 栏高 = 格高 48 + 两道 4 的缝。
    expect(tester.getSize(_pill).height, 56);
    expect(tester.takeException(), isNull);
  });

  testWidgets('label size and spacing only show while labels are on', (
    tester,
  ) async {
    final (settings, l10n) = await pumpHomeBarStylePage(tester);
    await openHomeBarStyleTab(tester, l10n.homeBarStyleTabAppearance);
    final labelSize = find.widgetWithText(
      SettingsSliderTile,
      l10n.homeBarStyleLabelSize,
    );
    await scrollToHomeBarOption(tester, labelSize);
    expect(tester.widget<SettingsSliderTile>(labelSize).nested, isTrue);

    await tapHomeBarOption(
      tester,
      find.descendant(
        of: find.byType(ExpressiveButtonGroup<HomeBarLabelMode>),
        matching: find.text(l10n.homeBarStyleLabelsNever),
      ),
    );
    expect(inHomeBarOptions(l10n.homeBarStyleLabelSize), findsNothing);
    expect(inHomeBarOptions(l10n.homeBarStyleLabelGap), findsNothing);
    // 图标大小与文字模式无关，仍在。
    expect(inHomeBarOptions(l10n.homeBarStyleIconSize), findsOneWidget);

    await tapHomeBarOption(
      tester,
      find.descendant(
        of: find.byType(ExpressiveButtonGroup<HomeBarLabelMode>),
        matching: find.text(l10n.homeBarStyleLabelsSelected),
      ),
    );
    expect(inHomeBarOptions(l10n.homeBarStyleLabelSize), findsOneWidget);
    expect(
      storedHomeBarSettings(settings).current.labelMode,
      HomeBarLabelMode.selected,
    );
    expect(tester.takeException(), isNull);
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
      HomeBarStyle.defaults.copyWith(labelMode: HomeBarLabelMode.never),
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
