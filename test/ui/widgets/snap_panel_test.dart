import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/snap_panel.dart';

import '../../support/expressive_test_theme.dart';

const double _height = 600;
const double _half = 300;
const double _headerHeight = 48;
const double _collapsed = SnapPanel.handleExtent + _headerHeight;

class _Host extends StatefulWidget {
  const _Host({required this.onController, required this.itemCount});

  final ValueChanged<SnapPanelController> onController;
  final int itemCount;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final SnapPanelController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SnapPanelController(vsync: this);
    widget.onController(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SnapPanel(
      controller: _controller,
      halfExtent: _half,
      background: const ColoredBox(
        key: ValueKey<String>('background'),
        color: Color(0xFF2E7D32),
      ),
      header: const PreferredSize(
        preferredSize: Size.fromHeight(_headerHeight),
        child: Center(child: Text('header')),
      ),
      body: SnapPanelScrollScope(
        controller: _controller,
        child: ListView(
          children: <Widget>[
            for (var i = 0; i < widget.itemCount; i++)
              SizedBox(height: 50, child: Text('item $i')),
          ],
        ),
      ),
      handleLabel: 'Panel',
      stopLabel: (SnapPanelStop stop) => stop.name,
    );
  }
}

Future<SnapPanelController> _pump(
  WidgetTester tester, {
  double height = _height,
  bool reduceMotion = false,
  int itemCount = 40,
}) async {
  late SnapPanelController controller;
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: height,
                child: _Host(
                  itemCount: itemCount,
                  onController: (SnapPanelController value) =>
                      controller = value,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

ScrollPosition _list(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

/// 面板上沿在屏幕上的位置。
double _panelTop(WidgetTester tester, SnapPanelController controller) =>
    tester.getRect(find.byType(SnapPanel)).bottom - controller.layoutExtent;

Future<void> _settleAt(
  WidgetTester tester,
  SnapPanelController controller,
  SnapPanelStop stop,
) async {
  controller.animateTo(stop);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts at the half stop with the background above it', (
    tester,
  ) async {
    final controller = await _pump(tester);
    expect(controller.stop, SnapPanelStop.half);
    expect(controller.extent, _half);
    expect(controller.extentOf(SnapPanelStop.collapsed), _collapsed);
    expect(controller.extentOf(SnapPanelStop.expanded), _height);
    // 背景铺到面板上沿再多一个圆角半径，圆角压在背景上而不是露出空白。
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('background'))).height,
      _height - _half + SnapPanel.cornerRadius,
    );
    expect(
      tester.getTopLeft(find.text('item 0')).dy,
      greaterThan(_panelTop(tester, controller) + _collapsed - 1),
    );
  });

  testWidgets('the header follows the finger and snaps to the nearest stop', (
    tester,
  ) async {
    final controller = await _pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('header')),
    );
    await gesture.moveBy(
      const Offset(0, -40),
      timeStamp: const Duration(milliseconds: 100),
    );
    await tester.pump();
    final start = controller.extent;
    final top = _panelTop(tester, controller);
    await gesture.moveBy(
      const Offset(0, -200),
      timeStamp: const Duration(milliseconds: 200),
    );
    await tester.pump();
    expect(controller.extent, closeTo(start + 200, 0.01));
    expect(_panelTop(tester, controller), closeTo(top - 200, 0.01));
    // 停住再松手：没有速度，落到最近的档位（离最高档更近）。
    await gesture.up(timeStamp: const Duration(seconds: 2));
    await tester.pump();
    expect(controller.stop, SnapPanelStop.expanded);
    await tester.pumpAndSettle();
    expect(controller.extent, _height);
  });

  testWidgets('a fling moves one stop in its direction', (tester) async {
    final controller = await _pump(tester);
    await _settleAt(tester, controller, SnapPanelStop.collapsed);
    expect(controller.extent, _collapsed);

    await tester.fling(find.text('header'), const Offset(0, -60), 1500);
    await tester.pumpAndSettle();
    expect(controller.stop, SnapPanelStop.half);
    expect(controller.extent, _half);

    await tester.fling(find.text('header'), const Offset(0, -60), 1500);
    await tester.pumpAndSettle();
    expect(controller.stop, SnapPanelStop.expanded);

    await tester.fling(find.text('header'), const Offset(0, 60), 1500);
    await tester.pumpAndSettle();
    expect(controller.stop, SnapPanelStop.half);
    expect(controller.extent, _half);
  });

  testWidgets('the list scrolls first and pulling down at its top collapses', (
    tester,
  ) async {
    final controller = await _pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(
      const Offset(0, -40),
      timeStamp: const Duration(milliseconds: 100),
    );
    await gesture.moveBy(
      const Offset(0, -60),
      timeStamp: const Duration(milliseconds: 200),
    );
    await tester.pump();
    // 往上滑只滚动内容，面板留在中档。
    expect(controller.extent, _half);
    final scrolled = _list(tester).pixels;
    expect(scrolled, greaterThan(50));

    // 往回拉：先把内容滚回顶端，剩下的位移收起面板。
    await gesture.moveBy(
      Offset(0, scrolled + 80),
      timeStamp: const Duration(milliseconds: 300),
    );
    await tester.pump();
    expect(_list(tester).pixels, 0);
    expect(controller.extent, closeTo(_half - 80, 0.01));

    // 同一次拖动里反向：先把面板推回原位，内容不动。
    await gesture.moveBy(
      const Offset(0, -50),
      timeStamp: const Duration(milliseconds: 400),
    );
    await tester.pump();
    expect(controller.extent, closeTo(_half - 30, 0.01));
    expect(_list(tester).pixels, 0);

    // 再往上：面板回到原位后，剩下的位移重新滚动内容。
    await gesture.moveBy(
      const Offset(0, -70),
      timeStamp: const Duration(milliseconds: 500),
    );
    await tester.pump();
    expect(controller.extent, closeTo(_half, 0.01));
    expect(_list(tester).pixels, closeTo(40, 0.01));
    await gesture.up(timeStamp: const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(controller.stop, SnapPanelStop.half);
  });

  testWidgets('a downward fling at the top of the list collapses the panel', (
    tester,
  ) async {
    final controller = await _pump(tester);
    await tester.fling(find.byType(ListView), const Offset(0, 80), 1500);
    await tester.pumpAndSettle();
    expect(controller.stop, SnapPanelStop.collapsed);
    expect(controller.extent, _collapsed);
    expect(_list(tester).pixels, 0);
  });

  testWidgets('pushing up at the end of the list keeps the panel in place', (
    tester,
  ) async {
    final controller = await _pump(tester);
    final position = _list(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(controller.stop, SnapPanelStop.half);
    expect(controller.extent, _half);
  });

  testWidgets('expanding keeps a list scrolled to its end against the bottom', (
    tester,
  ) async {
    final controller = await _pump(tester);
    final position = _list(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    final lastBottom = tester.getBottomLeft(find.text('item 39')).dy;
    controller.animateTo(SnapPanelStop.expanded);
    // 逐帧检查：视口变大的每一帧都不越过末端，最后一项的底边不会升到原位置
    // 以上（不露出空白再回弹）。弹簧回落时可能略低于原位置，那部分被遮住。
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      final list = _list(tester);
      expect(list.pixels, lessThanOrEqualTo(list.maxScrollExtent));
      expect(
        tester.getBottomLeft(find.text('item 39')).dy,
        greaterThanOrEqualTo(lastBottom - 0.01),
      );
    }
    await tester.pumpAndSettle();
    expect(controller.extent, _height);
    expect(_list(tester).pixels, _list(tester).maxScrollExtent);
  });

  testWidgets('reduced motion snaps without animating', (tester) async {
    final controller = await _pump(tester, reduceMotion: true);
    await tester.fling(find.text('header'), const Offset(0, -60), 1500);
    // 不推进时间：松手时就已到位。
    expect(controller.stop, SnapPanelStop.expanded);
    expect(controller.extent, _height);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('tapping the handle walks the stops back and forth', (
    tester,
  ) async {
    final controller = await _pump(tester);
    Future<void> tapHandle() async {
      final rect = tester.getRect(find.byType(SnapPanel));
      await tester.tapAt(
        Offset(
          rect.center.dx,
          _panelTop(tester, controller) + SnapPanel.handleExtent / 2,
        ),
      );
      await tester.pumpAndSettle();
    }

    final visited = <SnapPanelStop>[];
    for (var i = 0; i < 4; i++) {
      await tapHandle();
      visited.add(controller.stop);
    }
    expect(visited, <SnapPanelStop>[
      SnapPanelStop.expanded,
      SnapPanelStop.half,
      SnapPanelStop.collapsed,
      SnapPanelStop.half,
    ]);
  });

  testWidgets('screen readers step the handle like an adjustable control', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = await _pump(tester);
    final handle = find.semantics.byLabel('Panel');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Panel')),
      matchesSemantics(
        label: 'Panel',
        value: 'half',
        increasedValue: 'expanded',
        decreasedValue: 'collapsed',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        hasTapAction: true,
      ),
    );
    // 表头的拖动手势不映射成滚动动作，标签栏不会被读成可滚动区域。
    final header = tester.getSemantics(find.text('header')).getSemanticsData();
    expect(header.hasAction(SemanticsAction.scrollUp), isFalse);
    expect(header.hasAction(SemanticsAction.scrollDown), isFalse);
    tester.semantics.decrease(handle);
    await tester.pumpAndSettle();
    expect(controller.stop, SnapPanelStop.collapsed);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Panel')),
      matchesSemantics(
        label: 'Panel',
        value: 'collapsed',
        increasedValue: 'half',
        hasIncreaseAction: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.increase(handle);
    await tester.pumpAndSettle();
    tester.semantics.increase(handle);
    await tester.pumpAndSettle();
    expect(controller.stop, SnapPanelStop.expanded);
    semantics.dispose();
  });

  testWidgets('the body fades out at the bottom stop', (tester) async {
    final controller = await _pump(tester);
    double opacity() => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byType(ListView),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(opacity(), 1);
    await _settleAt(tester, controller, SnapPanelStop.collapsed);
    expect(opacity(), 0);
    // 收起时内容不进读屏。
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(find.semantics.byLabel('item 0'), findsNothing);
    semantics.dispose();
  });

  for (final height in <double>[600, 120, 40]) {
    testWidgets('never overflows in a ${height.toInt()}dp area', (
      tester,
    ) async {
      final controller = await _pump(tester, height: height);
      for (final stop in SnapPanelStop.values) {
        await _settleAt(tester, controller, stop);
        expect(tester.takeException(), isNull);
        expect(controller.layoutExtent, lessThanOrEqualTo(height));
      }
    });
  }

  testWidgets('a resting panel keeps its stop when the area resizes', (
    tester,
  ) async {
    final height = ValueNotifier<double>(_height);
    addTearDown(height.dispose);
    late SnapPanelController controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ValueListenableBuilder<double>(
              valueListenable: height,
              builder: (BuildContext context, double value, Widget? child) =>
                  SizedBox(height: value, child: child),
              child: _Host(
                itemCount: 40,
                onController: (SnapPanelController value) => controller = value,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _settleAt(tester, controller, SnapPanelStop.expanded);
    height.value = 500;
    await tester.pump();
    expect(controller.stop, SnapPanelStop.expanded);
    expect(controller.extent, 500);
    height.value = 560;
    await tester.pump();
    expect(controller.extent, 560);
    expect(tester.takeException(), isNull);
  });
}
