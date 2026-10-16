import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/expressive_choice_tile.dart';

import '../../support/expressive_test_theme.dart';

Future<void> _pump(WidgetTester tester, ExpressiveChoiceTile tile) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, child: tile)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 单选圆点中心相对选项中线的纵向偏移（负数在中线上方）。
double _dotOffset(WidgetTester tester) {
  final tile = tester.getRect(find.byType(ListTile));
  final dot = tester.getRect(find.byType(FaIcon));
  return dot.center.dy - tile.center.dy;
}

void main() {
  testWidgets('the dot follows the title row next to a description', (
    tester,
  ) async {
    await _pump(
      tester,
      ExpressiveChoiceTile(
        label: 'Merge',
        description: 'Keeps every local entry and only adds the missing ones',
        selected: true,
        onTap: () {},
      ),
    );
    expect(_dotOffset(tester), lessThan(-4));
  });

  testWidgets('centerIndicator centers the dot beside a one-line example', (
    tester,
  ) async {
    await _pump(
      tester,
      ExpressiveChoiceTile(
        label: 'Full date',
        description: '2026/10/13',
        centerIndicator: true,
        selected: false,
        onTap: () {},
      ),
    );
    expect(_dotOffset(tester).abs(), lessThan(0.5));
  });

  testWidgets('without a description the dot is centered', (tester) async {
    await _pump(
      tester,
      ExpressiveChoiceTile(label: 'List', selected: true, onTap: () {}),
    );
    expect(_dotOffset(tester).abs(), lessThan(0.5));
  });
}
