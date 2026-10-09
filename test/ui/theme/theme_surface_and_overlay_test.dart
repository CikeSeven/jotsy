import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../support/expressive_test_theme.dart';

void main() {
  group('Theme surfaces and overlay style tests', () {
    test('Expressive theme sets transparent status bar and adaptive icons', () {
      final lightTheme = expressiveTestTheme(Brightness.light);
      final darkTheme = expressiveTestTheme(Brightness.dark);

      expect(
        lightTheme.appBarTheme.backgroundColor,
        lightTheme.colorScheme.surface,
      );
      expect(
        darkTheme.appBarTheme.backgroundColor,
        darkTheme.colorScheme.surface,
      );

      final lightOverlay = lightTheme.appBarTheme.systemOverlayStyle;
      expect(lightOverlay, isNotNull);
      expect(lightOverlay!.statusBarColor, Colors.transparent);
      expect(lightOverlay.statusBarIconBrightness, Brightness.dark);

      final darkOverlay = darkTheme.appBarTheme.systemOverlayStyle;
      expect(darkOverlay, isNotNull);
      expect(darkOverlay!.statusBarColor, Colors.transparent);
      expect(darkOverlay.statusBarIconBrightness, Brightness.light);
    });

    testWidgets(
      'AppTopBar uses transparent status bar overlay matching theme brightness',
      (WidgetTester tester) async {
        final lightTheme = expressiveTestTheme(
          Brightness.light,
          seedColor: Colors.pink,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              appBar: AppTopBar(title: Text('Test Title')),
              body: SizedBox.shrink(),
            ),
          ),
        );

        final appBarWidget = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBarWidget.backgroundColor, lightTheme.colorScheme.surface);
        expect(
          appBarWidget.systemOverlayStyle?.statusBarColor,
          Colors.transparent,
        );
        expect(
          appBarWidget.systemOverlayStyle?.statusBarIconBrightness,
          Brightness.dark,
        );
      },
    );

    testWidgets(
      'SettingsPage resolves dynamic surface color from ambient theme',
      (WidgetTester tester) async {
        final pinkTheme = expressiveTestTheme(
          Brightness.light,
          seedColor: Colors.pink,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: pinkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SettingsPage()),
          ),
        );

        // Verify ColoredBox in SettingsPage uses pink theme surface
        final coloredBoxes = tester.widgetList<ColoredBox>(
          find.byType(ColoredBox),
        );
        expect(
          coloredBoxes.any((box) => box.color == pinkTheme.colorScheme.surface),
          isTrue,
        );
      },
    );
  });
}
