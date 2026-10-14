import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/double_tap_zoom_viewer.dart';

const _viewport = Size(400, 400);

Widget _host({required ValueChanged<bool> onZoomChanged}) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox.fromSize(
      size: _viewport,
      child: DoubleTapZoomViewer(
        onZoomChanged: onZoomChanged,
        child: const ColoredBox(color: Color(0xFF3366CC)),
      ),
    ),
  ),
);

TransformationController _transformation(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!;

double _scale(WidgetTester tester) =>
    _transformation(tester).value.getMaxScaleOnAxis();

Future<void> _doubleTapAt(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(kDoubleTapMinTime + const Duration(milliseconds: 10));
  await tester.tapAt(position);
  await tester.pump();
}

void main() {
  testWidgets('double tap zooms in around the tapped point and back out', (
    tester,
  ) async {
    final zoomEvents = <bool>[];
    await tester.pumpWidget(_host(onZoomChanged: zoomEvents.add));
    const focal = Offset(100, 120);

    await _doubleTapAt(tester, focal);
    await tester.pump(const Duration(milliseconds: 100));
    // 补间进行中：缩放介于原始与目标之间，而不是一帧跳到位。
    expect(_scale(tester), inExclusiveRange(1, 2.5));

    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(2.5, 1e-6));
    // 点按位置是放大的不动点。
    final scenePoint = _transformation(tester).toScene(focal);
    expect(scenePoint.dx, closeTo(focal.dx, 1e-6));
    expect(scenePoint.dy, closeTo(focal.dy, 1e-6));
    expect(zoomEvents, <bool>[true]);

    await _doubleTapAt(tester, const Offset(300, 300));
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(1, 1e-6));
    expect(_transformation(tester).value, Matrix4.identity());
    expect(zoomEvents, <bool>[true, false]);
  });

  testWidgets('zoomed content never exposes space outside the viewport', (
    tester,
  ) async {
    await tester.pumpWidget(_host(onZoomChanged: (_) {}));

    await _doubleTapAt(tester, const Offset(398, 398));
    await tester.pumpAndSettle();

    final matrix = _transformation(tester).value;
    // 视口右下角映射回内容坐标后仍在内容范围内。
    final corner = MatrixUtils.transformPoint(
      Matrix4.inverted(matrix),
      Offset(_viewport.width, _viewport.height),
    );
    expect(corner.dx, lessThanOrEqualTo(_viewport.width + 1e-6));
    expect(corner.dy, lessThanOrEqualTo(_viewport.height + 1e-6));
    final origin = MatrixUtils.transformPoint(
      Matrix4.inverted(matrix),
      Offset.zero,
    );
    expect(origin.dx, greaterThanOrEqualTo(-1e-6));
    expect(origin.dy, greaterThanOrEqualTo(-1e-6));
  });

  testWidgets('double tap jumps straight to the target under reduce motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_host(onZoomChanged: (_) {}));

    await _doubleTapAt(tester, const Offset(200, 200));

    expect(_scale(tester), closeTo(2.5, 1e-6));
    expect(tester.binding.hasScheduledFrame, isFalse);
    // 让双击识别器的最短间隔计时器走完。
    await tester.pump(kDoubleTapMinTime);
  });
}
