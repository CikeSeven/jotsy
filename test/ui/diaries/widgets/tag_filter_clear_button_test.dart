import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/tag_filter_clear_button.dart';

Widget _host({required bool hasSelection, required VoidCallback onClear}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: TagFilterClearButton(
            hasSelection: hasSelection,
            onClear: onClear,
          ),
        ),
      ),
    );

double _angle(WidgetTester tester) {
  final transform = tester
      .widgetList<Transform>(
        find.descendant(
          of: find.byType(TagFilterClearButton),
          matching: find.byType(Transform),
        ),
      )
      .first
      .transform;
  return transform.storage[1];
}

void main() {
  testWidgets('nothing selected: tapping neither clears nor spins', (
    tester,
  ) async {
    var cleared = 0;
    await tester.pumpWidget(
      _host(hasSelection: false, onClear: () => cleared++),
    );
    await tester.tap(find.byType(TagFilterClearButton));
    await tester.pump(const Duration(milliseconds: 120));

    expect(cleared, 0);
    expect(_angle(tester), 0);
  });

  testWidgets('with a selection: press shrinks, release clears and spins', (
    tester,
  ) async {
    var cleared = 0;
    await tester.pumpWidget(
      _host(hasSelection: true, onClear: () => cleared++),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TagFilterClearButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final pressedScale = tester
        .widget<AnimatedScale>(find.byType(AnimatedScale))
        .scale;
    expect(pressedScale, lessThan(1));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(cleared, 1);
    expect(_angle(tester), isNot(0));
    await tester.pumpAndSettle();
  });
}
