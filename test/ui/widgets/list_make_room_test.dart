import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/list_make_room.dart';

/// 列表让位（FLIP）：插进新卡片后，其余卡片从原位置滑到新位置。
void main() {
  late MakeRoomController controller;
  late BuildContext hostContext;

  Future<void> pumpList(WidgetTester tester, List<String> items) {
    return tester.pumpWidget(
      MaterialApp(
        home: _Host(
          onController: (c, context) {
            controller = c;
            hostContext = context;
          },
          items: items,
        ),
      ),
    );
  }

  Offset topLeftOf(WidgetTester tester, String id) =>
      tester.getTopLeft(find.byKey(ValueKey<String>('item_$id')));

  testWidgets('existing items slide from where they were to make room', (
    tester,
  ) async {
    await pumpList(tester, <String>['a', 'b']);
    final aBefore = topLeftOf(tester, 'a');
    final bBefore = topLeftOf(tester, 'b');
    controller.captureBaseline();

    await pumpList(tester, <String>['new', 'a', 'b']);
    // 新布局已排好，但让位还没开始：各项照新位置画（被整页盖着时看不见）。
    expect(topLeftOf(tester, 'a').dy, greaterThan(aBefore.dy));

    controller.play(hostContext);
    await tester.pump();
    // 从原来的位置出发。
    expect(topLeftOf(tester, 'a').dy, moreOrLessEquals(aBefore.dy));
    expect(topLeftOf(tester, 'b').dy, moreOrLessEquals(bBefore.dy));
    expect(controller.isActive, isTrue);

    await tester.pump(const Duration(milliseconds: 80));
    final mid = topLeftOf(tester, 'a').dy;
    expect(mid, greaterThan(aBefore.dy));
    expect(mid, lessThan(aBefore.dy + 100));

    await tester.pumpAndSettle();
    expect(topLeftOf(tester, 'a').dy, moreOrLessEquals(aBefore.dy + 100));
    expect(controller.isActive, isFalse);
  });

  testWidgets('play without a baseline does nothing', (tester) async {
    await pumpList(tester, <String>['a']);
    controller.play(hostContext);
    await tester.pump();
    expect(controller.isActive, isFalse);
  });

  testWidgets('reduced motion jumps straight to the new layout', (
    tester,
  ) async {
    await pumpList(tester, <String>['a']);
    controller.captureBaseline();
    await pumpList(tester, <String>['new', 'a']);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    controller.play(hostContext);
    await tester.pump();
    expect(controller.isActive, isFalse);
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.onController, required this.items});

  final void Function(MakeRoomController controller, BuildContext context)
  onController;
  final List<String> items;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  late final MakeRoomController _controller = MakeRoomController(vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onController(_controller, context);
    return Scaffold(
      body: Column(
        children: <Widget>[
          for (final id in widget.items)
            MakeRoomItem(
              key: ValueKey<String>('make_room_$id'),
              tag: id,
              controller: _controller,
              child: SizedBox(
                key: ValueKey<String>('item_$id'),
                height: 100,
                child: Text(id),
              ),
            ),
        ],
      ),
    );
  }
}
