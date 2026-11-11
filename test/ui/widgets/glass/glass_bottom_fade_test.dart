import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/glass/glass_bottom_fade_painter.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

/// 玻璃表面的底缘渐隐（`GlassSurface.bottomFadeExtent`）：树结构、画笔参数，
/// 以及渲染出来的像素——底色在整个渐隐区里淡出、模糊只在最下面一段淡出、
/// 到下缘时只剩没有模糊的页面，内容不受影响。

const _fill = Color(0x80FF0000);

/// 表面高 100、渐隐区 48：底色自 52 起淡出，模糊自 84 起淡出。
const double _height = 100;
const double _extent = 48;

Finder _below(Type type) =>
    find.descendant(of: find.byType(GlassSurface), matching: find.byType(type));

/// 表面里渐隐用的那个 CustomPaint：它的 child 是接水波纹的透明 Material
/// （外侧投影与 Material 自己画描边的 CustomPaint 都不是）。没有时为 null。
CustomPaint? _fadePaint(WidgetTester tester) {
  for (final paint in tester.widgetList<CustomPaint>(_below(CustomPaint))) {
    final child = paint.child;
    if (child is Material && child.type == MaterialType.transparency) {
      return paint;
    }
  }
  return null;
}

GlassBottomFadePainter? _painter(WidgetTester tester) =>
    _fadePaint(tester)?.painter as GlassBottomFadePainter?;

Future<void> _pumpSurface(
  WidgetTester tester, {
  double? extent,
  bool blur = true,
  double progress = 1,
  Widget child = const SizedBox(height: _height, width: double.infinity),
}) => tester.pumpWidget(
  MaterialApp(
    home: Align(
      alignment: Alignment.topCenter,
      child: GlassSurface(
        fill: _fill,
        blur: blur,
        blurSigma: 8,
        progress: progress,
        bottomFadeExtent: extent,
        child: child,
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

/// 把“条纹页面 + 叠在顶上的玻璃”渲染成 200×160 的 RGBA 像素。
Future<ByteData> _render(
  WidgetTester tester, {
  required Color fill,
  Widget? child,
}) async {
  tester.view.physicalSize = const Size(200, 160);
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
              top: 0,
              left: 0,
              right: 0,
              child: GlassSurface(
                fill: fill,
                blurSigma: 8,
                bottomFadeExtent: _extent,
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
  final offset = (y * 200 + x) * 4;
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

void main() {
  group('structure', () {
    testWidgets('without a fade extent the surface is built as before', (
      tester,
    ) async {
      await _pumpSurface(tester);
      expect(_fadePaint(tester), isNull);
      expect(_below(Material), findsOneWidget);
      expect(tester.widget<Material>(_below(Material)).color, _fill);
    });

    testWidgets('a zero extent keeps the fade nodes but paints uniformly', (
      tester,
    ) async {
      await _pumpSurface(tester, extent: 0);
      expect(_fadePaint(tester), isNotNull);
      expect(_painter(tester), isNull);
      expect(tester.widget<Material>(_below(Material).first).color, _fill);
    });

    testWidgets('a positive extent hands the fill to the fade painter', (
      tester,
    ) async {
      await _pumpSurface(tester, extent: _extent);
      final painter = _painter(tester)!;
      expect(painter.extent, _extent);
      expect(painter.fill, _fill);
      expect(painter.eraseBackdrop, isTrue);
      // 外层 Material 不再均匀地画底色，否则渐隐区里会多垫一层。
      expect(
        tester.widget<Material>(_below(Material).first).color,
        Colors.transparent,
      );
    });

    testWidgets('the fade follows the reveal progress of the fill', (
      tester,
    ) async {
      await _pumpSurface(tester, extent: _extent, progress: 0.5);
      expect(_painter(tester)!.fill.a, closeTo(_fill.a * 0.5, 0.001));
    });

    testWidgets('without a blur layer the backdrop is never erased', (
      tester,
    ) async {
      // 没有离屏图层时 dstIn 会直接擦掉页面：只淡底色。
      await _pumpSurface(tester, extent: _extent, blur: false);
      expect(_painter(tester)!.eraseBackdrop, isFalse);
      await _pumpSurface(tester, extent: _extent, progress: 0);
      expect(_painter(tester)!.eraseBackdrop, isFalse);
    });

    testWidgets('switching the fade on and off keeps the content state', (
      tester,
    ) async {
      const field = TextField(key: ValueKey<String>('field'));
      await _pumpSurface(tester, extent: _extent, child: field);
      await tester.enterText(find.byType(TextField), 'kept');
      final state = tester.state(find.byType(TextField));
      await _pumpSurface(tester, extent: 0, child: field);
      expect(tester.state(find.byType(TextField)), same(state));
      expect(find.text('kept'), findsOneWidget);
    });

    testWidgets('ink is drawn above the fade, on its own material', (
      tester,
    ) async {
      late MaterialType inkMaterial;
      await _pumpSurface(
        tester,
        extent: _extent,
        child: Builder(
          builder: (BuildContext context) {
            inkMaterial = context
                .findAncestorWidgetOfExactType<Material>()!
                .type;
            return const SizedBox(height: _height, width: double.infinity);
          },
        ),
      );
      // 水波纹画在最近的 Material 上：必须是渐隐画笔之内的那层透明 Material，
      // 画在外层的话会被擦淡、再被底色盖住。
      expect(inkMaterial, MaterialType.transparency);
    });
  });

  group('curve', () {
    test('strength eases from full to nothing with flat ends', () {
      expect(GlassBottomFadePainter.strengthAt(0), 1);
      expect(GlassBottomFadePainter.strengthAt(0.5), closeTo(0.5, 1e-9));
      expect(GlassBottomFadePainter.strengthAt(1), 0);
      // 两端贴着 1 与 0：看不出渐隐从哪一行开始、到哪一行结束。
      expect(GlassBottomFadePainter.strengthAt(0.05), greaterThan(0.99));
      expect(GlassBottomFadePainter.strengthAt(0.95), lessThan(0.01));
      // 越界的输入被夹住。
      expect(GlassBottomFadePainter.strengthAt(-1), 1);
      expect(GlassBottomFadePainter.strengthAt(2), 0);
    });
  });

  group('pixels', () {
    testWidgets('the tint thins out towards the bottom edge', (tester) async {
      final data = await _render(tester, fill: _fill);
      // 渐隐区之上是完整的底色：红色通道明显高于绿色。
      int redness(int y) {
        final p = _pixel(data, 100, y);
        return p[0] - p[1];
      }

      final top = redness(20);
      expect(top, greaterThan(80));
      // 渐隐区起点处仍是完整的底色，没有台阶。
      expect(redness(53), closeTo(top, 3));
      // 往下越来越淡……
      expect(redness(76), lessThan(top - 20));
      expect(redness(90), lessThan(redness(76)));
      // ……到下缘完全没有底色，与栏外的页面一样。
      expect(redness(99), closeTo(0, 2));
      expect(redness(110), 0);
    });

    testWidgets('the blur holds until the last third, then dissolves', (
      tester,
    ) async {
      // 底色全透明，只看模糊。
      final data = await _render(tester, fill: const Color(0x00FFFFFF));
      // 栏外的页面：条纹清晰。
      final sharp = _stripeContrast(data, 130);
      expect(sharp, greaterThan(240));
      // 渐隐区之上、以及渐隐区里模糊还没开始淡出的部分（84 以上）：抹匀。
      expect(_stripeContrast(data, 20), lessThan(12));
      expect(_stripeContrast(data, 60), lessThan(12));
      expect(_stripeContrast(data, 82), lessThan(12));
      // 最后三分之一里逐渐清晰……
      final mid = _stripeContrast(data, 92);
      expect(mid, greaterThan(60));
      expect(mid, lessThan(sharp - 60));
      // ……到下缘与页面无缝衔接。
      expect(_stripeContrast(data, 99), closeTo(sharp, 6));
    });

    testWidgets('content keeps its full strength inside the fade', (
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
      // 内容盖在下缘最透明的那一段上，颜色不被冲淡。
      expect(_pixel(data, 100, 97), <int>[0x00, 0xC8, 0x53]);
      expect(_pixel(data, 100, 75), <int>[0x00, 0xC8, 0x53]);
    });

    testWidgets('a trailing extent moves the fade below the surface', (
      tester,
    ) async {
      // 下面还接着 48 高的玻璃：渐隐区整个落在那一片上，本表面保持完整。
      final trailing = ValueNotifier<double>(48);
      addTearDown(trailing.dispose);
      final boundary = GlobalKey();
      tester.view.physicalSize = const Size(200, 160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: boundary,
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: CustomPaint(painter: _Stripes())),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: GlassSurface(
                    fill: _fill,
                    blurSigma: 8,
                    bottomFadeExtent: _extent,
                    bottomFadeTrailing: trailing,
                    child: const SizedBox(height: _height),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      int redness(ByteData data, int y) {
        final p = _pixel(data, 100, y);
        return p[0] - p[1];
      }

      final whole = await _capture(tester, boundary);
      expect(redness(whole, 99), closeTo(redness(whole, 20), 3));
      expect(_stripeContrast(whole, 99), lessThan(12));

      // 下面那片缩到 24：渐隐区的上半截回到本表面里，只触发重画。
      trailing.value = 24;
      await tester.pump();
      final half = await _capture(tester, boundary);
      expect(redness(half, 99), lessThan(redness(half, 20) - 20));
      expect(redness(half, 99), greaterThan(10));

      // 下面没有玻璃了：本表面的下缘就是栏的下缘。
      trailing.value = 0;
      await tester.pump();
      final own = await _capture(tester, boundary);
      expect(redness(own, 99), closeTo(0, 2));
    });
  });
}
