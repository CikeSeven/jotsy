import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/double_tap_zoom_viewer.dart';
import 'package:node_diary/ui/widgets/swipe_dismiss_viewer.dart';
import 'package:node_diary/ui/widgets/zoom_geometry.dart';

const _viewport = Size(400, 800);

/// 与看图页相同的结构：下拉关闭 > 翻页 > 每页一个缩放视口；放大时锁住翻页
/// 与下拉关闭。#252 的误触就发生在这三方争抢同一根手指时。
class _ViewerHost extends StatefulWidget {
  const _ViewerHost({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_ViewerHost> createState() => _ViewerHostState();
}

class _ViewerHostState extends State<_ViewerHost> {
  bool _zoomed = false;
  int page = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: _viewport,
          child: SwipeDismissViewer(
            enabled: !_zoomed,
            onDismiss: widget.onDismiss,
            builder: (context, chromeOpacity, content) => content,
            child: PageView.builder(
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              itemCount: 2,
              onPageChanged: (index) => setState(() => page = index),
              itemBuilder: (context, index) => DoubleTapZoomViewer(
                onZoomChanged: (zoomed) => setState(() => _zoomed = zoomed),
                child: ColoredBox(
                  color: index == 0
                      ? const Color(0xFF3366CC)
                      : const Color(0xFFCC6633),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 测试窗口默认 800×600，放不下 400×800 的视口：改成与视口同大，手指落点
/// 才都在视口里。
Future<void> _pumpHost(WidgetTester tester, Widget host) async {
  tester.view
    ..physicalSize = _viewport
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host);
}

TransformationController _transformation(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
    .transformationController!;

double _scale(WidgetTester tester) =>
    _transformation(tester).value.getMaxScaleOnAxis();

Offset _translation(WidgetTester tester) {
  final t = _transformation(tester).value.getTranslation();
  return Offset(t.x, t.y);
}

/// 内容（第一页）相对视口原点的位移：下拉关闭会把整页往下拖。
double _pageTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(DoubleTapZoomViewer).first).dy;

/// 分几步移动，模拟手指连续滑动（每步都小于触摸阈值 18）。
Future<void> _moveInSteps(
  TestGesture gesture,
  Offset total, {
  int steps = 6,
}) async {
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(total / steps.toDouble());
  }
}

void main() {
  testWidgets('a pinch whose second finger moves straight down zooms, '
      'never dismisses', (tester) async {
    var dismissed = 0;
    await _pumpHost(tester, _ViewerHost(onDismiss: () => dismissed++));

    final first = await tester.startGesture(
      const Offset(200, 300),
      pointer: 101,
    );
    final second = await tester.startGesture(
      const Offset(200, 500),
      pointer: 102,
    );
    // 只有后落下的手指在动，且竖直走了 60（远超下拉的触发阈值 18）。
    await _moveInSteps(second, const Offset(0, 60));
    await tester.pump();

    expect(_scale(tester), greaterThan(1.2));
    expect(_pageTop(tester), 0);
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(dismissed, 0);
    expect(_scale(tester), greaterThan(1.2));
  });

  testWidgets('a horizontal pinch zooms instead of turning the page', (
    tester,
  ) async {
    await _pumpHost(tester, _ViewerHost(onDismiss: () {}));

    final first = await tester.startGesture(
      const Offset(100, 400),
      pointer: 101,
    );
    final second = await tester.startGesture(
      const Offset(300, 400),
      pointer: 102,
    );
    // 后落下的手指水平走了 60（远超翻页的触发阈值 18）。
    await _moveInSteps(second, const Offset(-60, 0));
    await tester.pump();
    // 页面没有跟着手指横移，画面在缩小（阻尼中）。
    expect(tester.getTopLeft(find.byType(DoubleTapZoomViewer).first).dx, 0);
    expect(_scale(tester), lessThan(1));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    final host = tester.state<_ViewerHostState>(find.byType(_ViewerHost));
    expect(host.page, 0);
    // 两指间距 200 → 140：缩小到原始大小以下，松手回弹到 1。
    expect(_scale(tester), closeTo(1, 1e-6));
    expect(_transformation(tester).value, Matrix4.identity());
  });

  testWidgets('the focal point stays under the fingers while zooming', (
    tester,
  ) async {
    await _pumpHost(tester, _ViewerHost(onDismiss: () {}));

    final first = await tester.startGesture(
      const Offset(200, 300),
      pointer: 101,
    );
    final second = await tester.startGesture(
      const Offset(200, 500),
      pointer: 102,
    );
    await _moveInSteps(second, const Offset(0, 30));
    await tester.pump();

    // 跨度 100 → 115；起点焦点 (200, 400) 的内容点跟到新焦点 (200, 415)。
    expect(_scale(tester), closeTo(1.15, 1e-6));
    final scene = _transformation(tester).toScene(const Offset(200, 415));
    expect(scene.dx, closeTo(200, 1e-6));
    expect(scene.dy, closeTo(400, 1e-6));

    await first.up();
    await second.up();
    await tester.pumpAndSettle();
  });

  testWidgets('pinching below the original size follows with resistance '
      'and springs back', (tester) async {
    await _pumpHost(tester, _ViewerHost(onDismiss: () {}));

    final first = await tester.startGesture(
      const Offset(200, 200),
      pointer: 101,
    );
    final second = await tester.startGesture(
      const Offset(200, 600),
      pointer: 102,
    );
    await _moveInSteps(first, const Offset(0, 100));
    await _moveInSteps(second, const Offset(0, -100));
    await tester.pump();

    // 未阻尼应为 0.5，阻尼后缩得少一些但仍小于 1，并且居中不露出偏移。
    final shrunk = _scale(tester);
    expect(shrunk, inExclusiveRange(0.5, 1));
    expect(
      _translation(tester).dx,
      closeTo(_viewport.width * (1 - shrunk) / 2, 1e-6),
    );

    await first.up();
    await second.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // 回弹是补间，不是一帧跳回。
    expect(_scale(tester), inExclusiveRange(shrunk, 1));
    await tester.pumpAndSettle();
    expect(_transformation(tester).value, Matrix4.identity());
  });

  testWidgets('lifting the remaining finger without moving still springs '
      'back', (tester) async {
    await _pumpHost(tester, _ViewerHost(onDismiss: () {}));

    final first = await tester.startGesture(
      const Offset(200, 200),
      pointer: 101,
    );
    final second = await tester.startGesture(
      const Offset(200, 600),
      pointer: 102,
    );
    await _moveInSteps(second, const Offset(0, -200));
    await tester.pump();
    expect(_scale(tester), lessThan(1));

    // 先抬一根，另一根原地不动再抬：父类不会再发 onEnd，回弹靠 onRelease。
    await second.up();
    await tester.pump();
    await first.up();
    await tester.pumpAndSettle();
    expect(_transformation(tester).value, Matrix4.identity());
  });

  testWidgets('after one finger lifts the other keeps panning without a jump', (
    tester,
  ) async {
    await _pumpHost(tester, _ViewerHost(onDismiss: () {}));

    final first = await tester.startGesture(
      const Offset(200, 300),
      pointer: 101,
    );
    final second = await tester.startGesture(
      const Offset(200, 500),
      pointer: 102,
    );
    await _moveInSteps(first, const Offset(0, -50));
    await _moveInSteps(second, const Offset(0, 50));
    await tester.pump();
    final zoomedScale = _scale(tester);
    expect(zoomedScale, closeTo(1.5, 1e-6));

    await second.up();
    await tester.pump();
    final before = _translation(tester);
    await first.moveBy(const Offset(0, 4));
    await tester.pump();
    final firstStep = _translation(tester);
    // 剩下那根手指接着动：缩放不变、画面跟手平移，没有跳变。
    expect(_scale(tester), closeTo(zoomedScale, 1e-6));
    expect((firstStep - before).distance, lessThanOrEqualTo(4 + 1e-6));
    await _moveInSteps(first, const Offset(0, 30));
    await tester.pump();
    expect(_translation(tester).dy - firstStep.dy, closeTo(30, 1e-6));

    await first.up();
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(zoomedScale, 1e-6));
  });

  testWidgets('zooming past the maximum settles back to it', (tester) async {
    await _pumpHost(tester, _ViewerHost(onDismiss: () {}));

    final first = await tester.startGesture(
      const Offset(200, 380),
      pointer: 101,
    );
    final second = await tester.startGesture(
      const Offset(200, 420),
      pointer: 102,
    );
    // 跨度 20 → 200：未阻尼为 10 倍，上限 4。
    await _moveInSteps(first, const Offset(0, -180), steps: 12);
    await _moveInSteps(second, const Offset(0, 180), steps: 12);
    await tester.pump();
    expect(_scale(tester), greaterThan(4));

    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(4, 1e-6));
  });

  testWidgets('single-finger swipes still page and dismiss', (tester) async {
    var dismissed = 0;
    await _pumpHost(tester, _ViewerHost(onDismiss: () => dismissed++));

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    final host = tester.state<_ViewerHostState>(find.byType(_ViewerHost));
    expect(host.page, 1);
    expect(_scale(tester), closeTo(1, 1e-6));

    final gesture = await tester.startGesture(const Offset(200, 400));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(dismissed, 1);
  });

  group('ZoomGeometry', () {
    const geometry = ZoomGeometry(
      viewport: Size(400, 800),
      content: Size(400, 800),
      maxScale: 4,
    );

    test('rubber band is identity in range and invertible outside it', () {
      expect(geometry.rubberBand(2), 2);
      for (final raw in <double>[0.3, 0.6, 0.95, 4.2, 6, 12]) {
        final damped = geometry.rubberBand(raw);
        expect(geometry.unband(damped), closeTo(raw, 1e-9));
      }
      expect(geometry.rubberBand(0.6), inExclusiveRange(0.6, 1));
      expect(geometry.rubberBand(6), inExclusiveRange(4, 6));
      // 两指几乎并拢也只缩到一半。
      expect(geometry.rubberBand(0.001), 0.5);
    });

    test('clamped keeps zoomed content covering the viewport', () {
      final matrix = geometry.clamped(2, const Offset(50, -2000));
      final t = matrix.getTranslation();
      expect(t.x, 0);
      expect(t.y, -800);
      final shrunk = geometry.clamped(0.5, const Offset(-30, 40));
      final s = shrunk.getTranslation();
      expect(s.x, 100);
      expect(s.y, 200);
    });
  });
}
