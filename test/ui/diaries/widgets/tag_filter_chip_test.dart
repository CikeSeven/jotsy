import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/widgets/tag_filter_chip.dart';

import '../../../support/expressive_test_theme.dart';

const _unselectedText = Color(0xff222222);
const _selectedText = Color(0xff3366cc);

Widget _host(bool selected, {bool paintsSelectedSurface = true}) => MaterialApp(
  theme: expressiveTestTheme(Brightness.light),
  home: Scaffold(
    body: Center(
      child: TagFilterChip(
        label: 'Weekend',
        colorDot: const Color(0xff3366cc),
        selected: selected,
        selectedColor: const Color(0x553366cc),
        selectedForegroundColor: _selectedText,
        selectedBorderColor: const Color(0xff3366cc),
        unselectedColor: const Color(0x143366cc),
        unselectedForegroundColor: _unselectedText,
        unselectedBorderColor: const Color(0x383366cc),
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        animateBorder: true,
        paintsSelectedSurface: paintsSelectedSurface,
        onTap: () {},
      ),
    ),
  ),
);

Finder get _chip => find.byType(TagFilterChip);

/// 常规字重那一层（真正的文字）此刻的颜色。
Color _labelColor(WidgetTester tester) =>
    tester.widget<Text>(find.text('Weekend')).style!.color!;

void main() {
  testWidgets('selection never changes the chip size', (tester) async {
    await tester.pumpWidget(_host(false));
    final idle = tester.getSize(_chip);

    await tester.pumpWidget(_host(true));
    for (var frame = 0; frame < 15; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getSize(_chip), idle, reason: 'frame $frame');
    }
    await tester.pumpAndSettle();
    expect(tester.getSize(_chip), idle);

    await tester.pumpWidget(_host(false));
    await tester.pumpAndSettle();
    expect(tester.getSize(_chip), idle);
  });

  testWidgets('label colour and weight blend instead of snapping', (
    tester,
  ) async {
    await tester.pumpWidget(_host(false));
    expect(_labelColor(tester), _unselectedText);

    await tester.pumpWidget(_host(true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final midway = _labelColor(tester);
    expect(midway, isNot(_unselectedText));
    expect(midway, isNot(_selectedText));

    await tester.pumpAndSettle();
    expect(_labelColor(tester), _selectedText);
    // 只有一份可查找的文字：粗体那一层只画不参与查找与语义。
    expect(find.text('Weekend'), findsOneWidget);
  });

  testWidgets('becoming selected pops the chip once and settles', (
    tester,
  ) async {
    await tester.pumpWidget(_host(false));
    await tester.pumpWidget(_host(true));
    var peak = 1.0;
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final scale = tester
          .widget<ScaleTransition>(
            find.descendant(of: _chip, matching: find.byType(ScaleTransition)),
          )
          .scale
          .value;
      if (scale > peak) {
        peak = scale;
      }
    }
    expect(peak, greaterThan(1.01));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ScaleTransition>(
            find.descendant(of: _chip, matching: find.byType(ScaleTransition)),
          )
          .scale
          .value,
      1,
    );
  });

  testWidgets('a chip under the sliding pill does not pop itself', (
    tester,
  ) async {
    await tester.pumpWidget(_host(false, paintsSelectedSurface: false));
    await tester.pumpWidget(_host(true, paintsSelectedSurface: false));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester
            .widget<ScaleTransition>(
              find.descendant(
                of: _chip,
                matching: find.byType(ScaleTransition),
              ),
            )
            .scale
            .value,
        1,
      );
    }
  });
}
