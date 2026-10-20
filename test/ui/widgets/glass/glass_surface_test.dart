import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';
import 'package:node_diary/ui/widgets/glass/outer_shadow_painter.dart';

const _fill = Color(0xB8FFFFFF);
const _childKey = ValueKey<String>('glass-child');

Future<void> _pump(WidgetTester tester, Widget surface) => tester.pumpWidget(
  MaterialApp(
    home: Center(child: SizedBox(width: 200, height: 64, child: surface)),
  ),
);

GlassSurface _surface({
  bool blur = true,
  double blurSigma = 20,
  double progress = 1,
  Color? hairline,
  double? hairlineWidth,
  Color? shadow,
  BorderSide? border,
  bool grouped = false,
}) => GlassSurface(
  fill: _fill,
  blur: blur,
  blurSigma: blurSigma,
  progress: progress,
  bottomHairline: hairline,
  bottomHairlineWidth: hairlineWidth ?? GlassSurface.hairlineWidth,
  shadowColor: shadow,
  border: border,
  grouped: grouped,
  child: const SizedBox.expand(key: _childKey),
);

BackdropFilter _filter(WidgetTester tester) => tester.widget<BackdropFilter>(
  find.descendant(
    of: find.byType(GlassSurface),
    matching: find.byType(BackdropFilter),
  ),
);

Material _material(WidgetTester tester) => tester.widget<Material>(
  find.descendant(
    of: find.byType(GlassSurface),
    matching: find.byType(Material),
  ),
);

CustomPaint _shadowPaint(WidgetTester tester) => tester.widget<CustomPaint>(
  find
      .descendant(
        of: find.byType(GlassSurface),
        matching: find.byType(CustomPaint),
      )
      .first,
);

Finder get _hairline => find.descendant(
  of: find.byType(GlassSurface),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is DecoratedBox &&
        widget.position == DecorationPosition.foreground,
  ),
);

void main() {
  testWidgets('blur follows the flag, the progress and the sigma', (
    tester,
  ) async {
    await _pump(tester, _surface());
    expect(_filter(tester).enabled, isTrue);

    await _pump(tester, _surface(blur: false));
    expect(_filter(tester).enabled, isFalse);

    await _pump(tester, _surface(progress: 0));
    expect(_filter(tester).enabled, isFalse);

    await _pump(tester, _surface(blurSigma: 0));
    expect(_filter(tester).enabled, isFalse);
    // 开关模糊只切换 enabled，节点一直在：内容不会因此重建。
    expect(find.byKey(_childKey), findsOneWidget);
  });

  testWidgets('progress scales the fill, border and shadow alpha', (
    tester,
  ) async {
    const side = BorderSide(color: Color(0x99000000));
    const shadow = Color(0x40000000);
    await _pump(tester, _surface(progress: 0.5, border: side, shadow: shadow));
    final material = _material(tester);
    expect(material.color!.a, closeTo(_fill.a * 0.5, 1e-9));
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.side.color.a, closeTo(side.color.a * 0.5, 1e-9));
    final painter = _shadowPaint(tester).painter! as OuterShadowPainter;
    expect(painter.color.a, closeTo(shadow.a * 0.5, 1e-9));

    await _pump(tester, _surface(border: side, shadow: shadow));
    expect(_material(tester).color, _fill);
  });

  testWidgets('draws the bottom hairline only when a colour is given', (
    tester,
  ) async {
    await _pump(tester, _surface());
    expect(_hairline, findsNothing);

    const hairline = Color(0x59000000);
    await _pump(tester, _surface(hairline: hairline, progress: 0.5));
    final decoration =
        tester.widget<DecoratedBox>(_hairline).decoration as BoxDecoration;
    final bottom = (decoration.border! as Border).bottom;
    expect(bottom.width, GlassSurface.hairlineWidth);
    expect(bottom.color.a, closeTo(hairline.a * 0.5, 1e-9));
    expect((decoration.border! as Border).top, BorderSide.none);
  });

  testWidgets('the bottom hairline width defaults to the hairline spec', (
    tester,
  ) async {
    const hairline = Color(0x59000000);
    BorderSide bottom() =>
        ((tester.widget<DecoratedBox>(_hairline).decoration as BoxDecoration)
                    .border!
                as Border)
            .bottom;

    // 不传粗细的调用方（菜单等）保持原来的 0.6。
    await _pump(
      tester,
      const GlassSurface(
        fill: _fill,
        bottomHairline: hairline,
        child: SizedBox.expand(key: _childKey),
      ),
    );
    expect(bottom().width, GlassSurface.hairlineWidth);
    expect(GlassSurface.hairlineWidth, 0.6);

    await _pump(tester, _surface(hairline: hairline, hairlineWidth: 2.4));
    expect(bottom().width, 2.4);
    expect(bottom().color, hairline);
  });

  testWidgets('paints the outer shadow only with a shadow colour', (
    tester,
  ) async {
    await _pump(tester, _surface());
    expect(_shadowPaint(tester).painter, isNull);

    await _pump(tester, _surface(shadow: const Color(0x40000000)));
    expect(_shadowPaint(tester).painter, isA<OuterShadowPainter>());
  });

  testWidgets('grouped surfaces share the enclosing backdrop group', (
    tester,
  ) async {
    final group = BackdropGroup(child: _surface(grouped: true));
    await _pump(tester, group);
    final render = tester.renderObject<RenderBackdropFilter>(
      find.byType(BackdropFilter),
    );
    final key = BackdropGroup.of(
      tester.element(find.byType(BackdropFilter)),
    )!.backdropKey;
    expect(render.backdropKey, key);

    await _pump(tester, BackdropGroup(child: _surface()));
    expect(
      tester
          .renderObject<RenderBackdropFilter>(find.byType(BackdropFilter))
          .backdropKey,
      isNull,
    );
  });
}
