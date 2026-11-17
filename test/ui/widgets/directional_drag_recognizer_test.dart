import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/directional_drag_recognizer.dart';

/// 单向横向拖动：嵌在 PageView 里时只接自己那一侧，另一侧照常翻页。
void main() {
  Future<({List<String> drags, PageController pages})> pump(
    WidgetTester tester, {
    bool Function(Offset position)? acceptsPointer,
  }) async {
    final drags = <String>[];
    final pages = PageController();
    addTearDown(pages.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PageView(
          controller: pages,
          children: <Widget>[
            RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                DirectionalHorizontalDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      DirectionalHorizontalDragGestureRecognizer
                    >(
                      () => DirectionalHorizontalDragGestureRecognizer(
                        acceptsDirection: (double sign) => sign > 0,
                        acceptsPointer: acceptsPointer,
                      ),
                      (DirectionalHorizontalDragGestureRecognizer r) {
                        r.onStart = (_) => drags.add('start');
                        r.onEnd = (_) => drags.add('end');
                      },
                    ),
              },
              child: const SizedBox.expand(),
            ),
            const SizedBox.expand(),
          ],
        ),
      ),
    );
    return (drags: drags, pages: pages);
  }

  testWidgets('a right drag goes to the inner recognizer', (tester) async {
    final setup = await pump(tester);
    await tester.dragFrom(const Offset(200, 300), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(setup.drags, <String>['start', 'end']);
    expect(setup.pages.page, 0);
  });

  testWidgets('a left drag still turns the outer page', (tester) async {
    final setup = await pump(tester);
    // 拖过半页还多：有两个横向识别器时外层越过触摸溢出距离才接手。
    await tester.dragFrom(const Offset(700, 300), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(setup.drags, isEmpty);
    expect(setup.pages.page, 1);
  });

  testWidgets('pointers the filter rejects never take part', (tester) async {
    final setup = await pump(
      tester,
      acceptsPointer: (Offset position) => position.dx > 100,
    );
    await tester.dragFrom(const Offset(50, 300), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(setup.drags, isEmpty);
    await tester.dragFrom(const Offset(150, 300), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(setup.drags, <String>['start', 'end']);
  });
}
