import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_color_scheme.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/sections/settings_theme_section.dart';
import 'package:node_diary/ui/widgets/color_palette_families.dart';
import 'package:node_diary/ui/widgets/color_swatch_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

Future<SettingsService> _pumpSection(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = await SettingsService.create();
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SettingsThemeSection(settingsAsync: AsyncData(settings)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

Finder _familySwatch(WidgetTester tester, int index) {
  final l10n = AppLocalizations.of(
    tester.element(find.byType(SettingsThemeSection)),
  );
  final family = kThemeColorPaletteFamilies[index];
  return find.bySemanticsLabel(
    l10n.colorFamilySwatchLabel(index + 1, colorSwatchHex(family.swatch)),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('black and white is the last theme color family', (tester) async {
    final semantics = tester.ensureSemantics();
    final settings = await _pumpSection(tester);
    final last = kThemeColorPaletteFamilies.length - 1;

    // 色系一行横向滚动，末尾几个在 360dp 宽时不在屏内。
    await tester.ensureVisible(_familySwatch(tester, last));
    await tester.pumpAndSettle();
    await tester.tap(_familySwatch(tester, last));
    await tester.pumpAndSettle();

    expect(settings.themeSeedColorValue, kMonochromeThemeSeedValue);
    // 黑白色系只有一个色，选中后这一格带勾；色系色块左黑右白。
    final shade = tester.widget<ColorSwatchButton>(
      find.byWidgetPredicate(
        (w) =>
            w is ColorSwatchButton &&
            w.color.toARGB32() == kMonochromeThemeSeedValue &&
            w.showCheck,
      ),
    );
    expect(shade.selected, isTrue);
    final split = find.byWidgetPredicate(
      (w) => w is ColorSwatchButton && w.splitColor != null,
    );
    expect(split, findsOneWidget);
    final splitSwatch = tester.widget<ColorSwatchButton>(split);
    expect(splitSwatch.color.toARGB32(), kMonochromeThemeSeedValue);
    expect(splitSwatch.splitColor, kMonochromeThemeFamily.swatchSplit);
    expect(splitSwatch.selected, isTrue);
    // 右半边真的画出来了：铺满色块高度、占一半宽。
    final half = find.descendant(
      of: split,
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == kMonochromeThemeFamily.swatchSplit,
      ),
    );
    expect(tester.getSize(half), const Size(16, 32));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('gray family selection is kept instead of falling back', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final settings = await _pumpSection(tester);
    final grayIndex = kColorPaletteFamilies.indexWhere((f) => f.label == '灰');

    // 色系一行横向滚动，末尾几个在 360dp 宽时不在屏内。
    await tester.ensureVisible(_familySwatch(tester, grayIndex));
    await tester.pumpAndSettle();
    await tester.tap(_familySwatch(tester, grayIndex));
    await tester.pumpAndSettle();

    final gray = kColorPaletteFamilies[grayIndex].colors.first;
    expect(settings.themeSeedColorValue, gray.toARGB32());
    expect(
      tester
          .widget<ColorSwatchButton>(
            find.byWidgetPredicate(
              (w) => w is ColorSwatchButton && w.color == gray && w.showCheck,
            ),
          )
          .selected,
      isTrue,
    );
    semantics.dispose();
  });
}
