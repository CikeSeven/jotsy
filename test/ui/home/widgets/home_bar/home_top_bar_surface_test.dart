import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_chrome_scope.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_top_bar_surface.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

import '../../../../support/expressive_test_theme.dart';

const _solid = Color(0xFFF4F1EC);
const _content = SizedBox(height: 56, width: double.infinity);

Future<void> _pump(
  WidgetTester tester, {
  HomeBarResolvedStyle? style,
  bool showHairline = true,
}) {
  Widget surface = HomeTopBarSurface(
    solidColor: _solid,
    showHairline: showHairline,
    child: _content,
  );
  if (style != null) {
    surface = HomeChromeScope(style: style, child: surface);
  }
  return tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      home: Align(alignment: Alignment.topCenter, child: surface),
    ),
  );
}

HomeBarResolvedStyle _glass({
  bool highContrast = false,
  bool top = true,
  bool border = true,
  bool hairline = false,
}) => HomeBarResolvedStyle.resolve(
  HomeBarStyle(
    material: HomeBarMaterial.glass,
    glassTopBars: top,
    border: border,
    topBarHairline: hairline,
  ),
  expressiveTestTheme(Brightness.light).colorScheme,
  highContrast: highContrast,
);

Color? _hairline(WidgetTester tester) =>
    tester.widget<GlassSurface>(_below(GlassSurface)).bottomHairline;

Finder _below(Type type) => find.descendant(
  of: find.byType(HomeTopBarSurface),
  matching: find.byType(type),
);

void main() {
  testWidgets('without a scope the top bar is exactly a coloured box', (
    tester,
  ) async {
    await _pump(tester);
    final box = tester.widget<ColoredBox>(_below(ColoredBox).first);
    expect(box.color, _solid);
    expect(identical(box.child, _content), isTrue);
    expect(_below(BackdropFilter), findsNothing);
    expect(_below(Material), findsNothing);
  });

  testWidgets('a glass scope with solid top bars keeps the coloured box', (
    tester,
  ) async {
    await _pump(tester, style: _glass(top: false));
    expect(tester.widget<ColoredBox>(_below(ColoredBox).first).color, _solid);
    expect(_below(BackdropFilter), findsNothing);
  });

  testWidgets('glass top bars blur the content behind a translucent tint', (
    tester,
  ) async {
    final style = _glass();
    await _pump(tester, style: style);
    expect(
      tester.widget<BackdropFilter>(_below(BackdropFilter)).enabled,
      isTrue,
    );
    final fill = tester.widget<Material>(_below(Material).first).color!;
    expect(fill, style.tint);
    expect(fill.a, lessThan(1));
  });

  testWidgets('high contrast keeps glass top bars opaque and unblurred', (
    tester,
  ) async {
    final style = _glass(highContrast: true);
    await _pump(tester, style: style);
    expect(
      tester.widget<BackdropFilter>(_below(BackdropFilter)).enabled,
      isFalse,
    );
    final fill = tester.widget<Material>(_below(Material).first).color!;
    expect(fill, style.solidFill);
    expect(fill.a, 1);
  });

  testWidgets('the default glass top bar draws no hairline', (tester) async {
    await _pump(tester, style: _glass());
    expect(_hairline(tester), isNull);
  });

  testWidgets('the top bar hairline follows its own switch, not the border', (
    tester,
  ) async {
    final style = _glass(hairline: true, border: false);
    await _pump(tester, style: style);
    expect(_hairline(tester), style.hairlineColor);

    // 页面不允许这一片画线时（日记页刊头不是最下面一片），开关打开也不画。
    await _pump(tester, style: style, showHairline: false);
    expect(_hairline(tester), isNull);
  });

  testWidgets('glassTopBarsOf is false without a scope', (tester) async {
    late bool withoutScope;
    late bool withScope;
    await tester.pumpWidget(
      Column(
        children: <Widget>[
          Builder(
            builder: (BuildContext context) {
              withoutScope = HomeChromeScope.glassTopBarsOf(context);
              return const SizedBox();
            },
          ),
          HomeChromeScope(
            style: _glass(),
            child: Builder(
              builder: (BuildContext context) {
                withScope = HomeChromeScope.glassTopBarsOf(context);
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
    expect(withoutScope, isFalse);
    expect(withScope, isTrue);
  });
}
