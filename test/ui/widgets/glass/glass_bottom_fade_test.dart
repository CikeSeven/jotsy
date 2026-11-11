import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/glass/glass_bottom_fade_painter.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

/// 玻璃自上而下逐渐变透明（`GlassSurface.fadeToBottom`）与往上多铺的玻璃
/// （`GlassSurface.extendAbove` / `extendAboveVisible`）：树结构、画笔参数、
/// 点按与背景读取，以及渲染出来的像素——露出来的上半截是完整的玻璃，下半截
/// 里底色与模糊一起淡出，到下缘只剩没有模糊的页面，内容不受影响。

const _fill = Color(0x80FF0000);

/// 表面高 100：上半截（0..50）完整，下半截（50..100）渐变。
const double _height = 100;

/// 渲染画布的大小。
const double _canvasWidth = 200;
const double _canvasHeight = 220;

Finder _below(Type type) =>
    find.descendant(of: find.byType(GlassSurface), matching: find.byType(type));

/// 表面里画底色的画笔；没有渐变结构时为 null。
GlassBottomFadePainter? _painter(WidgetTester tester) {
  for (final paint in tester.widgetList<CustomPaint>(_below(CustomPaint))) {
    final painter = paint.painter;
    if (painter is GlassBottomFadePainter) return painter;
  }
  return null;
}

/// 玻璃（背景模糊）实际铺开的范围。
Rect _glassRect(WidgetTester tester) => tester.getRect(_below(BackdropFilter));

Future<void> _pumpSurface(
  WidgetTester tester, {
  bool? fade,
  double above = 0,
  bool blur = true,
  bool grouped = false,
  BackdropKey? backdropKey,
  double progress = 1,
  Widget child = const SizedBox(height: _height, width: double.infinity),
}) => tester.pumpWidget(
  MaterialApp(
    home: BackdropGroup(
      child: Align(
        alignment: Alignment.center,
        child: GlassSurface(
          fill: _fill,
          blur: blur,
          blurSigma: 8,
          progress: progress,
          fadeToBottom: fade,
          extendAbove: above,
          grouped: grouped,
          backdropKey: backdropKey,
          child: child,
        ),
      ),
    ),
  ),
);

/// 竖条纹的页面：模糊会把条纹抹匀，据此分辨“模糊了没有”。
class _Stripes extends CustomPainter {
  static const Color dark = Color(0xFF000000);
  static const Color light = Color(0xFFFFFFFF);

  /// 每条宽 4：σ 8 的模糊足以把它们抹成均匀的中灰。
  static const double stripe = 4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    for (var x = 0.0; x < size.width; x += stripe * 2) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, stripe, size.height),
        Paint()..color = dark,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}

/// 把“条纹页面 + 叠在上面的玻璃”渲染成 RGBA 像素。玻璃表面上缘在 [top]，
/// 高 [_height]，往上多铺 [above]（此刻露出 [visible]）。
Future<ByteData> _render(
  WidgetTester tester, {
  required Color fill,
  double top = 0,
  double above = 0,
  ValueListenable<double>? visible,
  Widget? child,
}) async {
  tester.view.physicalSize = const Size(_canvasWidth, _canvasHeight);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: boundary,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: CustomPaint(painter: _Stripes())),
            Positioned(
              top: top,
              left: 0,
              right: 0,
              child: GlassSurface(
                fill: fill,
                blurSigma: 8,
                fadeToBottom: true,
                extendAbove: above,
                extendAboveVisible: visible,
                child: SizedBox(height: _height, child: child),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return _capture(tester, boundary);
}

Future<ByteData> _capture(WidgetTester tester, GlobalKey boundary) async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = await tester.runAsync(() async {
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!;
  });
  return data!;
}

/// (x, y) 处的 [r, g, b]。
List<int> _pixel(ByteData data, int x, int y) {
  final offset = (y * _canvasWidth.toInt() + x) * 4;
  return <int>[
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  ];
}

/// 一行里相邻两条条纹（一暗一亮）的亮度差：清晰时约 255，抹匀后接近 0。
int _stripeContrast(ByteData data, int y) {
  // 条纹宽 4：x = 97 在暗条（96..99）中间，x = 101 在亮条（100..103）中间。
  final dark = _pixel(data, 97, y)[1];
  final light = _pixel(data, 101, y)[1];
  return (light - dark).abs();
}

/// 底色的浓淡：红色通道比绿色高出多少（条纹本身是灰阶，差为 0）。
int _redness(ByteData data, int y) {
  final p = _pixel(data, 100, y);
  return p[0] - p[1];
}

void main() {
  group('structure', () {
    testWidgets('without a fade setting the surface is built as before', (
      tester,
    ) async {
      await _pumpSurface(tester);
      expect(_painter(tester), isNull);
      expect(_below(Stack), findsNothing);
      expect(_below(Material), findsOneWidget);
      expect(tester.widget<Material>(_below(Material)).color, _fill);
    });

    testWidgets('fade false keeps the fade nodes but paints uniformly', (
      tester,
    ) async {
      await _pumpSurface(tester, fade: false);
      final painter = _painter(tester)!;
      expect(painter.fade, isFalse);
      expect(painter.fill, _fill);
      expect(painter.eraseBackdrop, isFalse);
      expect(_glassRect(tester), tester.getRect(find.byType(GlassSurface)));
    });

    testWidgets('fade true hands the fill and the blur to the fade painter', (
      tester,
    ) async {
      await _pumpSurface(tester, fade: true);
      final painter = _painter(tester)!;
      expect(painter.fade, isTrue);
      expect(painter.fill, _fill);
      expect(painter.eraseBackdrop, isTrue);
      // 渐变在表面之内，玻璃与表面一样大。
      expect(_glassRect(tester), tester.getRect(find.byType(GlassSurface)));
    });

    testWidgets('extendAbove lays the glass behind what sits above', (
      tester,
    ) async {
      final visible = ValueNotifier<double>(30);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            child: GlassSurface(
              fill: _fill,
              fadeToBottom: true,
              extendAbove: 30,
              extendAboveVisible: visible,
              child: const SizedBox(height: _height, width: double.infinity),
            ),
          ),
        ),
      );
      final surface = tester.getRect(find.byType(GlassSurface));
      // 只画、不占布局：表面仍是内容的大小。
      expect(surface.height, _height);
      final glass = _glassRect(tester);
      expect(glass.top, surface.top - 30);
      expect(glass.bottom, surface.bottom);
      final painter = _painter(tester)!;
      expect(painter.overhang, 30);
      expect(painter.visibleOverhang, same(visible));
    });

    testWidgets('the fade follows the reveal progress of the fill', (
      tester,
    ) async {
      await _pumpSurface(tester, fade: true, progress: 0.5);
      expect(_painter(tester)!.fill.a, closeTo(_fill.a * 0.5, 0.001));
    });

    testWidgets('without a blur layer the backdrop is never erased', (
      tester,
    ) async {
      // 没有离屏图层时 dstIn 会直接擦掉页面：只淡底色。
      await _pumpSurface(tester, fade: true, blur: false);
      expect(_painter(tester)!.eraseBackdrop, isFalse);
      await _pumpSurface(tester, fade: true, progress: 0);
      expect(_painter(tester)!.eraseBackdrop, isFalse);
    });

    testWidgets('a fading glass never shares its backdrop read', (
      tester,
    ) async {
      // 共用背景且滤镜相同时 Impeller 不开新图层、子节点直接画进父图层，
      // 擦除会把页面擦成黑色：渐变时一律自己读背景。
      RenderBackdropFilter filter() =>
          tester.renderObject<RenderBackdropFilter>(_below(BackdropFilter));
      await _pumpSurface(tester, fade: true, grouped: true);
      expect(filter().backdropKey, isNull);
      // 不渐变时照常共用。
      await _pumpSurface(tester, fade: false, grouped: true);
      expect(filter().backdropKey, isNotNull);
      final key = BackdropKey();
      await _pumpSurface(tester, fade: true, backdropKey: key);
      expect(filter().backdropKey, isNull);
      await _pumpSurface(tester, fade: false, backdropKey: key);
      expect(filter().backdropKey, same(key));
    });

    testWidgets('switching the fade on and off keeps the content state', (
      tester,
    ) async {
      const field = TextField(key: ValueKey<String>('field'));
      await _pumpSurface(tester, fade: true, grouped: true, child: field);
      await tester.enterText(find.byType(TextField), 'kept');
      final state = tester.state(find.byType(TextField));
      await _pumpSurface(tester, fade: false, grouped: true, child: field);
      expect(tester.state(find.byType(TextField)), same(state));
      expect(find.text('kept'), findsOneWidget);
    });

    testWidgets('ink is drawn above the glass, on its own material', (
      tester,
    ) async {
      late MaterialType inkMaterial;
      await _pumpSurface(
        tester,
        fade: true,
        child: Builder(
          builder: (BuildContext context) {
            inkMaterial = context
                .findAncestorWidgetOfExactType<Material>()!
                .type;
            return const SizedBox(height: _height, width: double.infinity);
          },
        ),
      );
      // 水波纹画在最近的 Material 上：必须是玻璃之上那层透明 Material，
      // 画在更外层的话会被玻璃盖住。
      expect(inkMaterial, MaterialType.transparency);
    });

    testWidgets('taps on the glass extended above reach what is there', (
      tester,
    ) async {
      var behind = 0;
      var surface = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => behind++,
                ),
              ),
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: GlassSurface(
                  fill: _fill,
                  fadeToBottom: true,
                  extendAbove: 60,
                  child: SizedBox(
                    height: _height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => surface++,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      // 往上铺的玻璃不接点按。
      await tester.tapAt(const Offset(100, 70));
      expect(behind, 1);
      expect(surface, 0);
      // 表面本身照常接点按。
      await tester.tapAt(const Offset(100, 150));
      expect(surface, 1);
      expect(behind, 1);
    });
  });

  group('curve', () {
    test('strength eases from full to nothing with flat ends', () {
      expect(GlassBottomFadePainter.strengthAt(0), 1);
      expect(GlassBottomFadePainter.strengthAt(0.5), closeTo(0.5, 1e-9));
      expect(GlassBottomFadePainter.strengthAt(1), 0);
      // 两端贴着 1 与 0：看不出渐变从哪一行开始、到哪一行结束。
      expect(GlassBottomFadePainter.strengthAt(0.05), greaterThan(0.99));
      expect(GlassBottomFadePainter.strengthAt(0.95), lessThan(0.01));
      // 越界的输入被夹住。
      expect(GlassBottomFadePainter.strengthAt(-1), 1);
      expect(GlassBottomFadePainter.strengthAt(2), 0);
    });
  });

  group('pixels', () {
    testWidgets('the tint holds on the upper half and thins out below', (
      tester,
    ) async {
      final data = await _render(tester, fill: _fill);
      // 上半截是完整的底色。
      final full = _redness(data, 10);
      expect(full, greaterThan(80));
      expect(_redness(data, 48), closeTo(full, 3));
      // 下半截越往下越淡……
      expect(_redness(data, 75), lessThan(full - 20));
      expect(_redness(data, 88), lessThan(_redness(data, 75)));
      // ……到下缘完全没有底色，与玻璃外的页面一样。
      expect(_redness(data, 99), closeTo(0, 3));
      expect(_redness(data, 130), 0);
    });

    testWidgets('the blur holds on the upper half and dissolves below', (
      tester,
    ) async {
      // 底色全透明，只看模糊。
      final data = await _render(tester, fill: const Color(0x00FFFFFF));
      // 玻璃外的页面：条纹清晰。
      final sharp = _stripeContrast(data, 180);
      expect(sharp, greaterThan(240));
      // 上半截：抹匀。
      expect(_stripeContrast(data, 10), lessThan(12));
      expect(_stripeContrast(data, 48), lessThan(12));
      // 下半截里逐渐清晰……
      final mid = _stripeContrast(data, 75);
      expect(mid, greaterThan(60));
      expect(mid, lessThan(sharp - 60));
      // ……到下缘与页面无缝衔接。
      expect(_stripeContrast(data, 99), closeTo(sharp, 8));
    });

    testWidgets('the fade spans the visible part of the extended glass', (
      tester,
    ) async {
      // 表面在 60..160，往上铺 60：露出来的是 0..160，上半截 0..80 完整，
      // 80..160 渐变。
      final data = await _render(tester, fill: _fill, top: 60, above: 60);
      final full = _redness(data, 10);
      expect(full, greaterThan(80));
      expect(_redness(data, 58), closeTo(full, 3));
      expect(_redness(data, 78), closeTo(full, 3));
      expect(_stripeContrast(data, 30), lessThan(12));
      expect(_redness(data, 120), lessThan(full - 20));
      expect(_redness(data, 159), closeTo(0, 3));
    });

    testWidgets('a hidden part of the extended glass is not painted', (
      tester,
    ) async {
      // 往上铺 60，只露出 20：画布上 0..40 那截不画，渐变按露出的 40..160。
      final visible = ValueNotifier<double>(20);
      addTearDown(visible.dispose);
      final data = await _render(
        tester,
        fill: _fill,
        top: 60,
        above: 60,
        visible: visible,
      );
      expect(_redness(data, 20), 0);
      expect(_stripeContrast(data, 20), greaterThan(240));
      final full = _redness(data, 50);
      expect(full, greaterThan(80));
      // 上半截 40..100 完整，100..160 渐变。
      expect(_redness(data, 98), closeTo(full, 3));
      expect(_redness(data, 130), lessThan(full - 20));
      expect(_redness(data, 159), closeTo(0, 3));
    });

    testWidgets('content keeps its full strength on the fading glass', (
      tester,
    ) async {
      const ink = Color(0xFF00C853);
      final data = await _render(
        tester,
        fill: _fill,
        child: const Align(
          alignment: Alignment.bottomCenter,
          child: ColoredBox(color: ink, child: SizedBox(width: 40, height: 30)),
        ),
      );
      // 内容画在玻璃之上，颜色不被底色或模糊冲淡。
      expect(_pixel(data, 100, 97), <int>[0x00, 0xC8, 0x53]);
      expect(_pixel(data, 100, 75), <int>[0x00, 0xC8, 0x53]);
    });
  });
}
