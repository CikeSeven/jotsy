import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/desktop_horizontal_scroll.dart';

/// [DesktopHorizontalScroll]：桌面上滚轮让横向条带横向滚动、到头后交给页面，
/// 鼠标可拖动；手机上不改变行为。
void main() {
  late ScrollController page;
  late ScrollController strip;

  setUp(() {
    page = ScrollController();
    strip = ScrollController();
  });
  tearDown(() {
    page.dispose();
    strip.dispose();
  });

  /// 纵向页面里放一条 600 宽视口、内容 1000 宽的横向条带（最多横滚 400）。
  Widget app() => MaterialApp(
    home: Scaffold(
      body: ListView(
        controller: page,
        children: <Widget>[
          const SizedBox(height: 300),
          SizedBox(
            width: 600,
            height: 60,
            child: DesktopHorizontalScroll(
              child: ListView(
                key: const ValueKey<String>('strip'),
                controller: strip,
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  for (var index = 0; index < 10; index++)
                    SizedBox(width: 100, child: Text('chip $index')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2000),
        ],
      ),
    ),
  );

  Future<void> wheel(WidgetTester tester, double dy) async {
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final at = tester.getCenter(find.byKey(const ValueKey<String>('strip')));
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
    await tester.pumpAndSettle();
  }

  testWidgets('the wheel scrolls the strip sideways, then bubbles at the end', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());

    await wheel(tester, 150);
    expect(strip.offset, 150);
    expect(page.offset, 0);

    // 剩 250：先滚到头（夹在末端），再滚就交给页面。
    await wheel(tester, 300);
    expect(strip.offset, strip.position.maxScrollExtent);
    expect(page.offset, 0);
    await wheel(tester, 100);
    expect(strip.offset, strip.position.maxScrollExtent);
    expect(page.offset, 100);

    // 往回滚：条带先往回。
    await wheel(tester, -100);
    expect(strip.offset, strip.position.maxScrollExtent - 100);
    expect(page.offset, 100);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a mouse can drag the strip on desktop', (tester) async {
    await tester.pumpWidget(app());
    await tester.drag(
      find.byKey(const ValueKey<String>('strip')),
      const Offset(-200, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(strip.offset, greaterThan(100));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('phones keep the default behaviour', (tester) async {
    await tester.pumpWidget(app());
    await wheel(tester, 150);
    expect(strip.offset, 0);
    expect(page.offset, 150);
  });
}
