import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/color_swatch_button.dart';

import '../../support/expressive_test_theme.dart';

void main() {
  testWidgets('swatches expose button semantics and meet tap target size', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    Color? tapped;
    const colors = <Color>[Color(0xFFE57373), Color(0xFF1E6586)];
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        home: Scaffold(
          body: Wrap(
            children: <Widget>[
              for (final color in colors)
                ColorSwatchButton(
                  color: color,
                  selected: color == colors.last,
                  semanticLabel: 'Color ${colorSwatchHex(color)}',
                  onTap: () => tapped = color,
                ),
            ],
          ),
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Color #1E6586')),
      isSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Color #E57373')),
      isSemantics(isButton: true, isSelected: false),
    );
    // 只有选中色块显示勾选。
    expect(find.byType(FaIcon), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Color #E57373'));
    expect(tapped, colors.first);
    semantics.dispose();
  });

  testWidgets('family swatch shows ring without a check mark', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorSwatchButton(
            color: const Color(0xFFE57373),
            selected: true,
            showCheck: false,
            borderRadius: 10,
            semanticLabel: 'Palette 1',
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.byType(FaIcon), findsNothing);
  });
}
