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
  testWidgets('the dot stays centered beside a description that wraps', (
    tester,
  ) async {
    const description =
        'Keeps every local entry and only adds the missing ones';
    await _pump(
      tester,
      ExpressiveChoiceTile(
        label: 'Merge',
        description: description,
        selected: true,
        destructive: true,
        onTap: () {},
      ),
    );
    // 说明确实折成了多行，否则居中与对齐标题行看不出差别。
    final lineHeight = tester.getSize(find.text('Merge')).height;
    expect(
      tester.getSize(find.text(description)).height,
      greaterThan(lineHeight * 1.5),
    );
    expect(_dotOffset(tester).abs(), lessThan(0.5));
  });

  testWidgets('the dot is centered beside a one-line example', (tester) async {
    await _pump(
      tester,
      ExpressiveChoiceTile(
        label: 'Full date',
        description: '2026/10/13',
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
