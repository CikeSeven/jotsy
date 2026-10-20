import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
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

import '../../support/expressive_test_theme.dart';

Widget _app(
  SettingsService settings,
  Widget home, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('zh'),
}) {
  return ProviderScope(
    overrides: [settingsServiceProvider.overrideWith((ref) async => settings)],
    child: MaterialApp(
      theme: expressiveTestTheme(brightness),
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ...AppLocalizations.localizationsDelegates,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Future<(SettingsService, AppLocalizations)> _pumpPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('zh'),
  Size size = const Size(400, 860),
  HomeBarSettings? initial,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (initial != null) 'app.settings.home_bar_style': initial.encode()!,
  });
  final settings = (await tester.runAsync(SettingsService.create))!;
  await tester.pumpWidget(
    _app(
      settings,
      HomeBarStylePage(settingsService: settings),
      brightness: brightness,
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  return (settings, l10n);
}

HomeBarSettings _stored(SettingsService settings) =>
    HomeBarSettings.decode(settings.homeBarStyleRaw);

Future<void> _openTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// 选项列表是懒构建的：目标还没进树时先在当前标签页里向下滚动。
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      120,
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
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 选项面板里的某个文字（不含上方预览）。
Finder _inOptions(String text) =>
    find.descendant(of: find.byType(TabBarView), matching: find.text(text));

Finder _materialOption(String label) => find.descendant(
  of: find.byType(ExpressiveButtonGroup<HomeBarMaterial>),
  matching: find.text(label),
);

const _glassCustom = HomeBarSettings(
  current: HomeBarStyle(
    material: HomeBarMaterial.glass,
    tint: HomeBarTint.custom,
    tintColor: 0xFF88AACC,
  ),
);

void main() {
  testWidgets('shows a miniature home preview above five option tabs', (
    tester,
  ) async {
    final (_, l10n) = await _pumpPage(tester);
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
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.homeBarStyleTabMaterial);
    expect(_inOptions(l10n.homeBarStyleGlassTopBars), findsNothing);

    await _tapVisible(tester, _materialOption(l10n.homeBarStyleMaterialGlass));
    expect(_stored(settings).current.material, HomeBarMaterial.glass);
    // 切到玻璃时默认的图标文字间距随之收紧。
    expect(_stored(settings).current.labelGap, HomeBarStyle.glassLabelGap);
    expect(_inOptions(l10n.homeBarStyleGlassTopBars), findsOneWidget);
    expect(_inOptions(l10n.homeBarStyleGlassFooter), findsOneWidget);
    expect(find.byType(HomeFloatingBar), findsOneWidget);

    // 自定义色调：起始色是当前中性底色（不透明），颜色行随之展开。
    await _tapVisible(tester, _inOptions(l10n.styleEditorCustom));
    final custom = _stored(settings).current;
    expect(custom.tint, HomeBarTint.custom);
    expect(custom.tintColor, isNotNull);
    expect(custom.tintColor! >> 24, 0xFF);
    expect(_inOptions(l10n.homeBarStyleTintColor), findsOneWidget);

    await _tapVisible(tester, _materialOption(l10n.homeBarStyleMaterialSolid));
    expect(_stored(settings).current.material, HomeBarMaterial.solid);
    expect(_stored(settings).current.labelGap, 4);
    expect(_inOptions(l10n.homeBarStyleGlassTopBars), findsNothing);
    expect(_inOptions(l10n.homeBarStyleTintColor), findsNothing);
    expect(find.byType(BottomNav), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the top bar hairline is its own switch under glass top bars', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(
      tester,
      initial: const HomeBarSettings(
        current: HomeBarStyle(material: HomeBarMaterial.glass),
      ),
    );
    await _openTab(tester, l10n.homeBarStyleTabMaterial);
    expect(_inOptions(l10n.homeBarStyleTopBarHairline), findsOneWidget);
    // 挂在“顶栏也用玻璃”之下，要再缩进一级，不能与它并列。
    expect(
      tester.getTopLeft(_inOptions(l10n.homeBarStyleTopBarHairline)).dx,
      greaterThan(
        tester.getTopLeft(_inOptions(l10n.homeBarStyleGlassTopBars)).dx,
      ),
    );

    await _tapVisible(tester, _inOptions(l10n.homeBarStyleTopBarHairline));
    expect(_stored(settings).current.topBarHairline, isTrue);
    expect(_stored(settings).current.border, isTrue);

    // 底栏描边只写 border，不动顶栏分隔线。
    await _tapVisible(tester, _inOptions(l10n.homeBarStyleBorder));
    expect(_stored(settings).current.border, isFalse);
    expect(_stored(settings).current.topBarHairline, isTrue);

    // 顶栏不用玻璃时分隔线这一行收起。
    await _tapVisible(tester, _inOptions(l10n.homeBarStyleGlassTopBars));
    expect(_stored(settings).current.glassTopBars, isFalse);
    expect(_inOptions(l10n.homeBarStyleTopBarHairline), findsNothing);
    await _tapVisible(tester, _inOptions(l10n.homeBarStyleGlassTopBars));
    expect(_inOptions(l10n.homeBarStyleTopBarHairline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sliders preview while dragging and persist on release', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.homeBarStyleTabItems);
    final finder = find.widgetWithText(
      SettingsSliderTile,
      l10n.homeBarStyleIconSize,
    );
    await _scrollTo(tester, finder);
    final tile = tester.widget<SettingsSliderTile>(finder);
    tile.onChanged!(24);
    await tester.pump();
    expect(settings.homeBarStyleRaw, isNull);
    expect(find.text(l10n.diaryCardStyleValueDp('24')), findsOneWidget);

    tile.onChangeEnd!(24);
    await tester.pumpAndSettle();
    expect(_stored(settings).current.iconSize, 24);
  });

  testWidgets('spacing sliders follow the label mode and the indicator', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.homeBarStyleTabItems);
    expect(_inOptions(l10n.homeBarStyleItemsFooter), findsOneWidget);
    // 默认显示文字、胶囊指示器：有间距滑块，没有内边距滑块。
    expect(_inOptions(l10n.homeBarStyleLabelGap), findsOneWidget);
    expect(_inOptions(l10n.homeBarStyleBlockPadding), findsNothing);

    await _tapVisible(tester, _inOptions(l10n.homeBarStyleLabelsNever));
    expect(_stored(settings).current.labelMode, HomeBarLabelMode.never);
    expect(_inOptions(l10n.homeBarStyleLabelGap), findsNothing);
    await _tapVisible(tester, _inOptions(l10n.homeBarStyleLabelsSelected));
    expect(_inOptions(l10n.homeBarStyleLabelGap), findsOneWidget);

    await _tapVisible(tester, _inOptions(l10n.homeBarStyleIndicatorBlock));
    expect(_stored(settings).current.indicator, HomeBarIndicator.block);
    final padding = find.widgetWithText(
      SettingsSliderTile,
      l10n.homeBarStyleBlockPadding,
    );
    await _scrollTo(tester, padding);
    final tile = tester.widget<SettingsSliderTile>(padding);
    expect(tile.nested, isTrue);
    tile.onChanged!(10);
    await tester.pump();
    expect(_stored(settings).current.blockPadding, 6);
    tile.onChangeEnd!(10);
    await tester.pumpAndSettle();
    expect(_stored(settings).current.blockPadding, 10);

    await _tapVisible(tester, _inOptions(l10n.homeBarStyleIndicatorNone));
    expect(_inOptions(l10n.homeBarStyleBlockPadding), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the floating tab offers to switch to glass when solid', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.homeBarStyleTabFloating);
    expect(_inOptions(l10n.homeBarStyleFloatingSolidHint), findsOneWidget);
    expect(_inOptions(l10n.homeBarStyleSizeGroup), findsNothing);

    await _tapVisible(tester, _inOptions(l10n.homeBarStyleSwitchToGlass));
    expect(_stored(settings).current.material, HomeBarMaterial.glass);
    expect(_stored(settings).current.labelGap, HomeBarStyle.glassLabelGap);
    expect(_inOptions(l10n.homeBarStyleFloatingSolidHint), findsNothing);
    expect(_inOptions(l10n.homeBarStyleSizeGroup), findsOneWidget);

    await _tapVisible(tester, _inOptions(l10n.homeBarStyleFabInline));
    expect(_stored(settings).current.fabPlacement, HomeBarFabPlacement.inline);
    expect(find.byType(HomeInlineCreateButton), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the behavior tab hides hide-on-scroll while solid', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.homeBarStyleTabBehavior);
    expect(_inOptions(l10n.homeBarStyleHideOnScroll), findsNothing);
    expect(
      find.descendant(
        of: find.byType(TabBarView),
        matching: find.textContaining(l10n.homeBarStyleHideOnScrollSolidHint),
      ),
      findsOneWidget,
    );

    await _tapVisible(
      tester,
      find.widgetWithText(SwitchListTile, l10n.homeBarStyleIndicatorFollows),
    );
    expect(_stored(settings).behavior.indicatorFollowsSwipe, isTrue);
    expect(_stored(settings).current, HomeBarStyle.defaults);

    await settings.setHomeBarStyleRaw(
      _stored(settings)
          .withCurrent(const HomeBarStyle(material: HomeBarMaterial.glass))
          .encode(),
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.widgetWithText(SwitchListTile, l10n.homeBarStyleHideOnScroll),
    );
    expect(_stored(settings).behavior.hideOnScroll, isTrue);
    expect(_stored(settings).behavior.indicatorFollowsSwipe, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a preset applies with an undo snackbar', (tester) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _tapVisible(tester, _inOptions(l10n.homeBarStylePresetGlass));
    expect(_stored(settings).current, HomeBarPreset.glass.style);
    expect(find.byType(HomeFloatingBar), findsOneWidget);
    expect(
      find.text(l10n.styleEditorApplied(l10n.homeBarStylePresetGlass)),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(_stored(settings).current, HomeBarStyle.defaults);
    expect(find.byType(BottomNav), findsOneWidget);
  });

  testWidgets('the appearance entry names the current style and opens it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = (await tester.runAsync(SettingsService.create))!;
    await tester.pumpWidget(
      _app(
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

  for (final locale in const <Locale>[Locale('zh'), Locale('en')]) {
    for (final glass in <bool>[false, true]) {
      testWidgets('every tab fits a 320dp screen in ${locale.languageCode}'
          '${glass ? ' with glass' : ''}', (tester) async {
        final (_, l10n) = await _pumpPage(
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
          await _openTab(tester, label);
          await tester.drag(find.byType(TabBarView), const Offset(0, -2000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
        }
      });
    }
  }
}
