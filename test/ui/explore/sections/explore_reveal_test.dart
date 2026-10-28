import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/explore/models/explore_layout.dart';
import 'package:node_diary/ui/explore/models/explore_module_data.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/sections/explore_mood_cards.dart';
import 'package:node_diary/ui/explore/widgets/explore_shared_widgets.dart';

import '../../../support/expressive_test_theme.dart';

Widget _host(Widget child) => MaterialApp(
  theme: expressiveTestTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

Widget _tile(int value) => SizedBox(
  width: 160,
  child: ExploreStatTile(
    icon: FontAwesomeIcons.bookOpen,
    label: 'Records',
    value: value,
  ),
);

int _shownNumber(WidgetTester tester) => int.parse(
  tester
      .widget<Text>(
        find.descendant(
          of: find.byType(TweenAnimationBuilder<double>),
          matching: find.byType(Text),
        ),
      )
      .data!,
);

void main() {
  testWidgets('stat counts up once and then follows data changes', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_tile(120)));
    expect(_shownNumber(tester), 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_shownNumber(tester), inExclusiveRange(0, 120));
    await tester.pumpAndSettle();
    expect(_shownNumber(tester), 120);

    // 数据变化：从当前值补间到新值，而不是从 0 重播。
    await tester.pumpWidget(_host(_tile(121)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_shownNumber(tester), greaterThanOrEqualTo(120));
    await tester.pumpAndSettle();
    expect(_shownNumber(tester), 121);
  });

  testWidgets('stat shows the final value at once under reduce motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_host(_tile(120)));
    await tester.pump();
    expect(_shownNumber(tester), 120);
  });

  testWidgets('energy bars grow from the baseline on first reveal', (
    tester,
  ) async {
    final primary = expressiveTestTheme(Brightness.light).colorScheme.primary;
    double tallestBar() {
      var tallest = 0.0;
      for (final element in find.byType(Container).evaluate()) {
        final decoration = (element.widget as Container).decoration;
        if (decoration is BoxDecoration && decoration.color == primary) {
          final height = element.size!.height;
          if (height > tallest) {
            tallest = height;
          }
        }
      }
      return tallest;
    }

    final today = DateTime(2026, 10, 28);
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 360,
          child: ExploreEnergyCard(
            config: ExploreLayout.defaults.module(ExploreModuleId.energy),
            series: <ExploreDayValue>[
              for (var i = 6; i >= 0; i--)
                ExploreDayValue(
                  DateTime(today.year, today.month, today.day - i),
                  5,
                ),
            ],
          ),
        ),
      ),
    );
    expect(tallestBar(), 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tallestBar(), inExclusiveRange(0, 44));
    await tester.pumpAndSettle();
    expect(tallestBar(), 44);
  });
}
