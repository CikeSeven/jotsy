import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart' as m3e;
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/bottom_nav.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

import '../../support/expressive_test_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    test('keeps the configured blue as the primary color in $brightness', () {
      const seed = Color(0xff2196f3);
      final expected = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      );
      final actual = MaterialTheme(
        brightness == Brightness.light
            ? Typography.material2021().black
            : Typography.material2021().white,
      ).theme(expected);
      expect(actual.colorScheme.primary, expected.primary);
      expect(actual.listTileTheme.tileColor, isNull);
      expect(actual.listTileTheme.contentPadding, isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'buttons morph on press and keep disabled actions inert in $brightness',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          _app(
            brightness: brightness,
            child: Column(
              children: [
                FilledButton(
                  onPressed: () => calls++,
                  child: const Text('Save'),
                ),
                const FilledButton(onPressed: null, child: Text('Disabled')),
              ],
            ),
          ),
        );
        final button = find.widgetWithText(FilledButton, 'Save');
        final ink = find.descendant(
          of: button,
          matching: find.byType(Material),
        );
        final before = tester.widget<Material>(ink).shape;
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<Material>(ink).shape, isNot(before));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(calls, 1);
        await tester.tap(find.text('Disabled'));
        expect(calls, 1);
        expect(tester.widget<Material>(ink).shape, before);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'connected selection keeps state and keyboard activation in $brightness',
      (tester) async {
        var selected = 0;
        await tester.pumpWidget(
          _app(
            brightness: brightness,
            child: StatefulBuilder(
              builder: (context, setState) => ExpressiveButtonGroup<int>(
                selected: {selected},
                segments: const [
                  ButtonSegment(value: 0, label: Text('System')),
                  ButtonSegment(value: 1, label: Text('Light')),
                  ButtonSegment(
                    value: 2,
                    label: Text('Disabled'),
                    enabled: false,
                  ),
                ],
                onSelectionChanged: (values) =>
                    setState(() => selected = values.single),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Light'));
        await tester.pumpAndSettle();
        expect(selected, 1);
        await tester.tap(find.text('Disabled'));
        expect(selected, 1);
        Focus.of(tester.element(find.text('System'))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(selected, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'expressive slider updates at both range boundaries in $brightness',
      (tester) async {
        var value = 0.5;
        await tester.pumpWidget(
          _app(
            brightness: brightness,
            child: StatefulBuilder(
              builder: (context, setState) => Slider(
                value: value,
                divisions: 5,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        );
        final slider = find.byType(Slider);
        await tester.drag(slider, const Offset(700, 0));
        await tester.pumpAndSettle();
        expect(value, 1);
        await tester.drag(slider, const Offset(-700, 0));
        await tester.pumpAndSettle();
        expect(value, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'connected selection reflows on a narrow screen with large text',
    (tester) async {
      await tester.pumpWidget(
        _app(
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SizedBox(
              width: 280,
              child: ExpressiveButtonGroup<int>(
                selected: const {0},
                segments: const [
                  ButtonSegment(value: 0, label: Text('Follow system')),
                  ButtonSegment(value: 1, label: Text('Light appearance')),
                  ButtonSegment(value: 2, label: Text('Dark appearance')),
                ],
                onSelectionChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.text('Dark appearance')).dy,
        greaterThan(tester.getBottomLeft(find.text('Light appearance')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading remains visible and labelled without animation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _app(
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SizedBox(
              width: 20,
              height: 20,
              child: ExpressiveLoadingIndicator(
                semanticLabel: 'Loading diaries',
              ),
            ),
          ),
        ),
      );
      expect(find.byType(m3e.LoadingIndicatorM3E), findsOneWidget);
      expect(find.bySemanticsLabel('Loading diaries'), findsWidgets);
      expect(
        TickerMode.valuesOf(
          tester.element(find.byType(m3e.LoadingIndicatorM3E)),
        ).enabled,
        isFalse,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('navigation clamps stale selection and still routes taps', (
    tester,
  ) async {
    var tapped = -1;
    const items = [
      BottomNavItem(label: 'Diaries', icon: FontAwesomeIcons.book),
      BottomNavItem(label: 'Settings', icon: FontAwesomeIcons.gear),
    ];
    await tester.pumpWidget(
      _app(
        child: BottomNav(
          items: items,
          selectedIndex: 9,
          onTap: (value) => tapped = value,
        ),
      ),
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await tester.tap(find.text('Diaries'));
    expect(tapped, 0);
    await tester.pumpWidget(
      _app(
        child: BottomNav(items: const [], selectedIndex: -1, onTap: (_) {}),
      ),
    );
    expect(find.byType(NavigationBar), findsNothing);
    await tester.pumpWidget(
      _app(
        child: BottomNav(
          items: [items.first],
          selectedIndex: 9,
          onTap: (value) => tapped = value,
        ),
      ),
    );
    await tester.tap(find.text('Diaries'));
    expect(tapped, 0);
    expect(tester.takeException(), isNull);
  });

  test(
    'reduced motion preserves expressive styles and removes button transitions',
    () {
      final theme = expressiveTestTheme(Brightness.dark);
      final reduced = ExpressiveControls.withoutMotion(theme);
      expect(reduced.colorScheme, theme.colorScheme);
      expect(
        reduced.filledButtonTheme.style!.shape,
        theme.filledButtonTheme.style!.shape,
      );
      expect(reduced.filledButtonTheme.style!.animationDuration, Duration.zero);
    },
  );
}

Widget _app({
  required Widget child,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: expressiveTestTheme(brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);
