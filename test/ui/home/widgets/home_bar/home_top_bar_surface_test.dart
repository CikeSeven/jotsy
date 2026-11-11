import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_chrome_scope.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_top_bar_surface.dart';
import 'package:node_diary/ui/widgets/glass/glass_bottom_fade_painter.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

import '../../../../support/expressive_test_theme.dart';

const _solid = Color(0xFFF4F1EC);
const _content = SizedBox(height: 56, width: double.infinity);

Future<void> _pump(
  WidgetTester tester, {
  HomeBarResolvedStyle? style,
  bool upper = false,
  double glassAbove = 0,
  HomeTopBarStackLink? link,
  Widget child = _content,
}) {
  Widget surface = upper
      ? HomeTopBarSurface.upper(
          solidColor: _solid,
          link: link ?? HomeTopBarStackLink(),
          child: child,
        )
      : HomeTopBarSurface(
          solidColor: _solid,
          glassAbove: glassAbove,
          link: link,
          child: child,
        );
  if (style != null) {
    surface = HomeChromeScope(style: style, child: surface);
  }
  return tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      home: Align(alignment: Alignment.center, child: surface),
    ),
  );
}

HomeBarResolvedStyle _glass({
  bool highContrast = false,
  bool hairline = false,
}) => HomeBarResolvedStyle.resolve(
  HomeBarStyle(topBarHairline: hairline),
  expressiveTestTheme(Brightness.light).colorScheme,
  highContrast: highContrast,
);

Color? _hairline(WidgetTester tester) =>
    tester.widget<GlassSurface>(_below(GlassSurface)).bottomHairline;

Finder _below(Type type) => find.descendant(
  of: find.byType(HomeTopBarSurface),
  matching: find.byType(type),
);

/// 玻璃的画笔（底色与渐变都由它画）。
GlassBottomFadePainter? _painter(WidgetTester tester) {
  for (final paint in tester.widgetList<CustomPaint>(_below(CustomPaint))) {
    final painter = paint.painter;
    if (painter is GlassBottomFadePainter) return painter;
  }
  return null;
}

/// 玻璃（背景模糊）实际铺开的范围。
Rect _glassRect(WidgetTester tester) => tester.getRect(_below(BackdropFilter));

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

    // 上面的片不在首页之下时同样是自己的色块。
    await _pump(tester, upper: true);
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
    final fill = _painter(tester)!.fill;
    expect(fill, style.tint);
    expect(fill.a, lessThan(1));
    // 与悬浮底栏同一配方：同样的模糊强度与饱和度增强。
    final surface = tester.widget<GlassSurface>(_below(GlassSurface));
    expect(surface.blurSigma, style.blurSigma);
    expect(surface.saturation, style.saturation);
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
    final painter = _painter(tester)!;
    expect(painter.fill, style.solidFill);
    expect(painter.fill.a, 1);
    // 不透明的底色才保证得了栏里文字的对比度：不渐变。
    expect(style.topBarFades, isFalse);
    expect(painter.fade, isFalse);
  });

  testWidgets('the glass fades from top to bottom by default', (tester) async {
    final style = _glass();
    await _pump(tester, style: style);
    expect(style.topBarFades, isTrue);
    final painter = _painter(tester)!;
    expect(painter.fade, isTrue);
    // 模糊也一起淡出，下缘不留一条模糊与清晰的分界线。
    expect(painter.eraseBackdrop, isTrue);
    // 渐变在顶栏之内：玻璃与顶栏一样大，不往外挂。
    expect(_glassRect(tester), tester.getRect(find.byType(HomeTopBarSurface)));
  });

  testWidgets('the hairline replaces the fade with a crisp uniform edge', (
    tester,
  ) async {
    final style = _glass(hairline: true);
    await _pump(tester, style: style);
    expect(style.topBarFades, isFalse);
    final painter = _painter(tester)!;
    expect(painter.fade, isFalse);
    expect(painter.fill, style.tint);
    expect(_hairline(tester), style.hairlineColor);
  });

  testWidgets('glassAbove lays the glass behind the pieces above', (
    tester,
  ) async {
    final link = HomeTopBarStackLink();
    addTearDown(link.dispose);
    await _pump(tester, style: _glass(), glassAbove: 80, link: link);
    final bar = tester.getRect(find.byType(HomeTopBarSurface));
    // 只画、不占布局：这一片仍是内容的大小。
    expect(bar.height, 56);
    final glass = _glassRect(tester);
    expect(glass.top, bar.top - 80);
    expect(glass.bottom, bar.bottom);
    // 往上铺的那截露出多少由上面的片经 link 报上来，渐变从露出的上缘起算。
    final painter = _painter(tester)!;
    expect(painter.overhang, 80);
    expect(painter.visibleOverhang, same(link));
  });

  testWidgets('an upper piece draws only its content over the glass below', (
    tester,
  ) async {
    late MaterialType inkMaterial;
    final link = HomeTopBarStackLink();
    addTearDown(link.dispose);
    await _pump(
      tester,
      style: _glass(hairline: true),
      upper: true,
      link: link,
      child: Builder(
        builder: (BuildContext context) {
          inkMaterial = context.findAncestorWidgetOfExactType<Material>()!.type;
          return _content;
        },
      ),
    );
    // 不自己读背景、不画底色，也不画下缘；水波纹落在透明的 Material 上。
    expect(_below(BackdropFilter), findsNothing);
    expect(_below(GlassSurface), findsNothing);
    expect(_below(ColoredBox), findsNothing);
    expect(inkMaterial, MaterialType.transparency);
    // 布局时把自己的高度报给下面那片。
    expect(link.value, 56);
  });

  testWidgets('toggling high contrast keeps the bar content mounted', (
    tester,
  ) async {
    const field = SizedBox(
      height: 56,
      child: TextField(key: ValueKey<String>('field')),
    );
    await _pump(tester, style: _glass(), child: field);
    await tester.enterText(find.byType(TextField), 'kept');
    final state = tester.state(find.byType(TextField));
    // 渐变 ↔ 高对比度的实边 ↔ 分隔线：渐变用的节点一直在，内容不重新挂载。
    await _pump(tester, style: _glass(highContrast: true), child: field);
    expect(_painter(tester)!.fade, isFalse);
    expect(tester.state(find.byType(TextField)), same(state));
    await _pump(tester, style: _glass(hairline: true), child: field);
    expect(tester.state(find.byType(TextField)), same(state));
    await _pump(tester, style: _glass(), child: field);
    expect(_painter(tester)!.fade, isTrue);
    expect(tester.state(find.byType(TextField)), same(state));
    expect(find.text('kept'), findsOneWidget);
  });

  testWidgets('the default glass top bar draws no hairline', (tester) async {
    await _pump(tester, style: _glass());
    expect(_hairline(tester), isNull);
  });

  testWidgets('the top bar hairline follows its own switch', (tester) async {
    final style = _glass(hairline: true);
    await _pump(tester, style: style);
    expect(_hairline(tester), style.hairlineColor);
  });

  testWidgets('the hairline is the fixed thin outline-variant line', (
    tester,
  ) async {
    final style = _glass(hairline: true);
    await _pump(tester, style: style);
    final surface = tester.widget<GlassSurface>(_below(GlassSurface));
    expect(surface.bottomHairlineWidth, GlassSurface.hairlineWidth);
    expect(surface.bottomHairline, style.hairlineColor);
  });

  testWidgets('glassTopBarsOf is true exactly under a scope', (tester) async {
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
