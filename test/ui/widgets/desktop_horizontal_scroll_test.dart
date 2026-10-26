import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/desktop_horizontal_scroll.dart';

/// [DesktopHorizontalScroll]：桌面上普通滚轮始终交给页面；Shift + 滚轮与原生
/// 横向位移让条带横向滚动，到头后交给页面；鼠标可拖动；手机上不改变行为。
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
  ///
  /// [noAxisModifiers] 去掉默认滚动行为里的 Shift 换轴（框架自己的处理），
  /// 用来确认 Shift + 滚轮是本组件显式换算的。
  Widget app({bool noAxisModifiers = false}) => MaterialApp(
    scrollBehavior: noAxisModifiers
        ? const MaterialScrollBehavior().copyWith(
            pointerAxisModifiers: <LogicalKeyboardKey>{},
          )
        : null,
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

  void useSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> wheel(
    WidgetTester tester,
    double dy, {
    double dx = 0,
    bool shift = false,
  }) async {
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final at = tester.getCenter(find.byKey(const ValueKey<String>('strip')));
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.sendEventToBinding(pointer.scroll(Offset(dx, dy)));
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('a plain wheel over the strip always scrolls the page', (
    tester,
  ) async {
    useSize(tester);
    await tester.pumpWidget(app());

    await wheel(tester, 150);
    expect(strip.offset, 0);
    expect(page.offset, 150);
    await wheel(tester, -100);
    expect(strip.offset, 0);
    expect(page.offset, 50);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final noAxisModifiers in <bool>[false, true]) {
    testWidgets(
      'shift+wheel scrolls the strip sideways, then bubbles at the end'
      '${noAxisModifiers ? ' (without the framework axis modifiers)' : ''}',
      (tester) async {
        useSize(tester);
        await tester.pumpWidget(app(noAxisModifiers: noAxisModifiers));

        await wheel(tester, 150, shift: true);
        expect(strip.offset, 150);
        expect(page.offset, 0);

        // 剩 250：先滚到头（夹在末端），再滚就交给页面。
        await wheel(tester, 300, shift: true);
        expect(strip.offset, strip.position.maxScrollExtent);
        expect(page.offset, 0);
        // 到头后不再接管、交给外层（默认滚动行为里 Shift 同样把页面的
        // 滚轮换成横向，纵向页面因此不动；去掉换轴时页面照常纵向滚动）。
        await wheel(tester, 100, shift: true);
        expect(strip.offset, strip.position.maxScrollExtent);
        expect(page.offset, noAxisModifiers ? 100 : 0);

        // 往回滚：条带先往回。
        final pageOffset = page.offset;
        await wheel(tester, -100, shift: true);
        expect(strip.offset, strip.position.maxScrollExtent - 100);
        expect(page.offset, pageOffset);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }

  testWidgets('a native horizontal delta scrolls the strip', (tester) async {
    useSize(tester);
    await tester.pumpWidget(app());
    await wheel(tester, 0, dx: 120);
    expect(strip.offset, 120);
    expect(page.offset, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

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
