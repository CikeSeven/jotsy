import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_metrics.dart';
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
  bool bottomEdge = true,
  Widget child = _content,
}) {
  Widget surface = HomeTopBarSurface(
    solidColor: _solid,
    bottomEdge: bottomEdge,
    child: child,
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

/// [surface]（默认唯一的那一片）底缘渐隐的画笔；不渐隐时为 null。
GlassBottomFadePainter? _fade(WidgetTester tester, [Finder? surface]) {
  final paints = find.descendant(
    of: surface ?? find.byType(HomeTopBarSurface),
    matching: find.byType(CustomPaint),
  );
  for (final paint in tester.widgetList<CustomPaint>(paints)) {
    final painter = paint.painter;
    if (painter is GlassBottomFadePainter) return painter;
  }
  return null;
}

/// 玻璃均匀画出的底色（不渐隐时由外层 Material 画）。
Color _uniformFill(WidgetTester tester) =>
    tester.widget<Material>(_below(Material).first).color!;

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

  testWidgets('glass top bars blur the content behind a translucent tint', (
    tester,
  ) async {
    final style = _glass();
    await _pump(tester, style: style);
    expect(
      tester.widget<BackdropFilter>(_below(BackdropFilter)).enabled,
      isTrue,
    );
    // 默认下缘渐隐，底色交给渐隐画笔（见下面的渐隐用例）。
    final fill = _fade(tester)!.fill;
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
    final fill = _uniformFill(tester);
    expect(fill, style.solidFill);
    expect(fill.a, 1);
    // 不透明的底色才保证得了栏里文字的对比度：不渐隐。
    expect(_fade(tester), isNull);
  });

  testWidgets('the glass thins out towards the bottom edge by default', (
    tester,
  ) async {
    final style = _glass();
    await _pump(tester, style: style);
    final fade = _fade(tester)!;
    expect(fade.extent, HomeBarMetrics.topBarFadeExtent);
    expect(style.topBarFadeExtent, HomeBarMetrics.topBarFadeExtent);
    // 模糊也一起淡出，下缘不留一条模糊与清晰的分界线。
    expect(fade.eraseBackdrop, isTrue);
    // 单片顶栏：自己的下缘就是顶栏的下缘。
    expect(fade.trailing, isNull);
  });

  testWidgets('the hairline replaces the fade with a crisp uniform edge', (
    tester,
  ) async {
    final style = _glass(hairline: true);
    await _pump(tester, style: style);
    expect(style.topBarFadeExtent, 0);
    expect(_fade(tester), isNull);
    expect(_uniformFill(tester), style.tint);
    expect(_hairline(tester), style.hairlineColor);
  });

  testWidgets('an upper piece without a link stays uniform', (tester) async {
    final style = _glass();
    await _pump(tester, style: style, bottomEdge: false);
    expect(_fade(tester), isNull);
    expect(_uniformFill(tester), style.tint);
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
    // 渐隐 ↔ 高对比度的实边：渐隐用的节点一直在，内容不重新挂载。
    await _pump(tester, style: _glass(highContrast: true), child: field);
    expect(_fade(tester), isNull);
    expect(tester.state(find.byType(TextField)), same(state));
    await _pump(tester, style: _glass(), child: field);
    expect(_fade(tester), isNotNull);
    expect(tester.state(find.byType(TextField)), same(state));
    expect(find.text('kept'), findsOneWidget);
  });

  group('two pieces sharing one fade', () {
    const upperKey = ValueKey<String>('upper');
    const lowerKey = ValueKey<String>('lower');

    Future<HomeTopBarFadeLink> pumpPieces(
      WidgetTester tester, {
      required double lowerHeight,
      HomeBarResolvedStyle? style,
    }) async {
      final link = HomeTopBarFadeLink();
      addTearDown(link.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          home: HomeChromeScope(
            style: style ?? _glass(),
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  HomeTopBarSurface(
                    key: upperKey,
                    solidColor: _solid,
                    bottomEdge: false,
                    fadeLink: link,
                    child: _content,
                  ),
                  HomeTopBarSurface(
                    key: lowerKey,
                    solidColor: _solid,
                    fadeLink: link,
                    child: SizedBox(
                      height: lowerHeight,
                      width: double.infinity,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return link;
    }

    testWidgets('the lower piece reports its height to the upper piece', (
      tester,
    ) async {
      final link = await pumpPieces(tester, lowerHeight: 6);
      expect(link.value, 6);
      // 上面一片把渐隐接着画：按“自己的下缘 + 下面那片的高度”对齐。
      final upper = _fade(tester, find.byKey(upperKey))!;
      expect(upper.extent, HomeBarMetrics.topBarFadeExtent);
      expect(upper.trailing, same(link));
      // 最下面一片按自己的下缘对齐。
      final lower = _fade(tester, find.byKey(lowerKey))!;
      expect(lower.extent, HomeBarMetrics.topBarFadeExtent);
      expect(lower.trailing, isNull);
    });

    testWidgets('a resize repaints the upper piece without rebuilding it', (
      tester,
    ) async {
      final link = HomeTopBarFadeLink();
      addTearDown(link.dispose);
      final height = ValueNotifier<double>(6);
      addTearDown(height.dispose);
      var upperBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          home: HomeChromeScope(
            style: _glass(),
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  HomeTopBarSurface(
                    key: upperKey,
                    solidColor: _solid,
                    bottomEdge: false,
                    fadeLink: link,
                    child: Builder(
                      builder: (BuildContext context) {
                        upperBuilds++;
                        return _content;
                      },
                    ),
                  ),
                  HomeTopBarSurface(
                    key: lowerKey,
                    solidColor: _solid,
                    fadeLink: link,
                    child: ValueListenableBuilder<double>(
                      valueListenable: height,
                      builder: (_, double value, _) =>
                          SizedBox(height: value, width: double.infinity),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(link.value, 6);
      // 标签栏展开：高度在布局阶段报上来，上面一片只需要重画。
      height.value = 120;
      await tester.pump();
      expect(link.value, 120);
      expect(upperBuilds, 1);
    });

    testWidgets('with the hairline on neither piece fades', (tester) async {
      await pumpPieces(tester, lowerHeight: 6, style: _glass(hairline: true));
      expect(_fade(tester, find.byKey(upperKey)), isNull);
      expect(_fade(tester, find.byKey(lowerKey)), isNull);
    });
  });

  testWidgets('the default glass top bar draws no hairline', (tester) async {
    await _pump(tester, style: _glass());
    expect(_hairline(tester), isNull);
  });

  testWidgets('the top bar hairline follows its own switch', (tester) async {
    final style = _glass(hairline: true);
    await _pump(tester, style: style);
    expect(_hairline(tester), style.hairlineColor);

    // 页面不允许这一片画线时（日记页刊头不是最下面一片），开关打开也不画。
    await _pump(tester, style: style, bottomEdge: false);
    expect(_hairline(tester), isNull);
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
