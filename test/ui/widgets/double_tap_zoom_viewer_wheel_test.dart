import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/double_tap_zoom_viewer.dart';

const _viewport = Size(400, 400);
const _center = Offset(200, 200);

/// 普通内容或高为宽 × 5 的长内容，放在左上角 400×400 的视口里。
Widget _host({required bool tall}) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox.fromSize(
      size: _viewport,
      child: tall
          ? DoubleTapZoomViewer.tall(
              contentHeightFactor: 5,
              builder: (BuildContext context, Size size, Rect visible) =>
                  const ColoredBox(color: Color(0xFF3366CC)),
            )
          : const DoubleTapZoomViewer(
              child: ColoredBox(color: Color(0xFF3366CC)),
            ),
    ),
  ),
);

Matrix4 _matrix(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value;

double _scale(WidgetTester tester) => _matrix(tester).getMaxScaleOnAxis();
double _dy(WidgetTester tester) => _matrix(tester).getTranslation().y;

Future<void> _wheel(WidgetTester tester, double dy) async {
  tester.binding.handlePointerEvent(
    PointerScrollEvent(
      position: _center,
      kind: PointerDeviceKind.mouse,
      scrollDelta: Offset(0, dy),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the wheel scrolls a tall image on desktop and stops at its ends',
    (tester) async {
      await tester.pumpWidget(_host(tall: true));
      await _wheel(tester, 300);
      expect(_scale(tester), 1);
      expect(_dy(tester), closeTo(-300, 1e-6));
      // 滚到底：内容高 2000，视口 400，最多上移 1600。
      await _wheel(tester, 5000);
      expect(_dy(tester), closeTo(-1600, 1e-6));
      await _wheel(tester, -9000);
      expect(_dy(tester), closeTo(0, 1e-6));
      expect(_scale(tester), 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('ctrl + wheel zooms a tall image instead of scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(_host(tall: true));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    // 按下 Ctrl 后的下一帧起滚轮改为缩放（真实使用时按键与滚动之间总有帧）。
    await tester.pump();
    final before = _dy(tester);
    await _wheel(tester, -200);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(_scale(tester), greaterThan(1));
    expect(before, 0);
    // 松开后滚轮又回到滚动，缩放保持。
    await tester.pump();
    final zoomed = _scale(tester);
    await _wheel(tester, 100);
    expect(_scale(tester), closeTo(zoomed, 1e-9));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('a trackpad pinch zooms a tall image', (tester) async {
    await tester.pumpWidget(_host(tall: true));
    final pinch = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await pinch.panZoomStart(_center);
    await pinch.panZoomUpdate(_center, scale: 2);
    await pinch.panZoomEnd();
    await tester.pumpAndSettle();
    expect(_scale(tester), greaterThan(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('the wheel still zooms a normal image on desktop', (
    tester,
  ) async {
    await tester.pumpWidget(_host(tall: false));
    await _wheel(tester, -200);
    expect(_scale(tester), greaterThan(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('touch platforms keep the wheel zooming tall images', (
    tester,
  ) async {
    await tester.pumpWidget(_host(tall: true));
    await _wheel(tester, -200);
    expect(_scale(tester), greaterThan(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
