import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/fast_scroller/fast_scroller.dart';
import 'package:node_diary/ui/widgets/fast_scroller/fast_scroller_parts.dart';

/// 快速滚动条：按“第几项”跳转、跳到未加载部分时请求加载、远距离分帧移动、
/// 显隐与桌面行为。
///
/// 列表项高度不一（60–140），用来验证落点按实际布局校正，而不是按平均
/// 高度估算。
void main() {
  const double headerHeight = 120;
  const double trackTop = 50;
  const double trackBottom = 50;

  double heightOf(int index) => 60.0 + (index % 5) * 20;

  /// 第 [index] 项在列表 sliver 里的起点。
  double offsetOf(int index) {
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      offset += heightOf(i);
    }
    return offset;
  }

  late GlobalKey listKey;
  late List<int> requests;

  /// 已交给列表的项数与列表身份：测试可直接改它们模拟数据到达、换筛选。
  late ValueNotifier<int> loadedCount;
  late ValueNotifier<Object> identity;

  setUp(() {
    listKey = GlobalKey();
    requests = <int>[];
    identity = ValueNotifier<Object>('a');
  });

  Future<void> pumpScroller(
    WidgetTester tester, {
    required int total,
    int? loaded,
    bool growOnRequest = true,
    bool masonry = false,
    bool topBars = false,
  }) async {
    loadedCount = ValueNotifier<int>(loaded ?? total);
    addTearDown(loadedCount.dispose);
    addTearDown(identity.dispose);
    Widget list(int count) => masonry
        ? SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childCount: count,
            itemBuilder: (BuildContext context, int index) =>
                SizedBox(height: heightOf(index), child: Text('item $index')),
          )
        : SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) =>
                  SizedBox(height: heightOf(index), child: Text('item $index')),
              childCount: count,
            ),
          );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[loadedCount, identity]),
            builder: (BuildContext context, Widget? _) {
              return FastScroller(
                listKey: listKey,
                itemCount: total,
                loadedCount: loadedCount.value,
                listIdentity: identity.value,
                // 顶栏：状态栏那一条 44 + 标签栏 46。
                pinnedExtent: topBars ? 90 : 0,
                labelBuilder: (int index) =>
                    FastScrollLabel('L$index', caption: 'C${index ~/ 50}'),
                sections: <FastScrollSection>[
                  for (var i = 0; i < total; i += 50)
                    FastScrollSection(index: i, label: 'S$i'),
                ],
                onNeedItems: (int count) {
                  requests.add(count);
                  if (growOnRequest && count > loadedCount.value) {
                    loadedCount.value = count;
                  }
                },
                padding: const EdgeInsets.only(
                  top: trackTop,
                  bottom: trackBottom,
                ),
                child: CustomScrollView(
                  slivers: <Widget>[
                    // 与日记页相同的顶栏：玻璃时“浮动 + 固定”的刊头（收起
                    // 到状态栏那一条）、固定的标签栏、随内容滚走的间距。
                    if (topBars) ...<Widget>[
                      SliverPersistentHeader(
                        pinned: true,
                        floating: true,
                        delegate: _MastheadDelegate(),
                      ),
                      const PinnedHeaderSliver(child: SizedBox(height: 46)),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ] else
                      const SliverToBoxAdapter(
                        child: SizedBox(height: headerHeight),
                      ),
                    KeyedSubtree(key: listKey, child: list(loadedCount.value)),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  ScrollPosition positionOf(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position;

  /// 顶线所在的项：列表 sliver 坐标里覆盖视口上缘的那一项。
  int topItem(WidgetTester tester) {
    final top = positionOf(tester).pixels - headerHeight;
    var index = 0;
    var offset = 0.0;
    while (offset + heightOf(index) <= top) {
      offset += heightOf(index);
      index++;
    }
    return index;
  }

  Future<void> revealByScrolling(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// 按住按钮并把它的中心拖到轨道上 [fraction] 处（0–1），每一步之间出帧。
  Future<TestGesture> dragThumbTo(
    WidgetTester tester,
    double fraction, {
    int steps = 6,
  }) async {
    final start = tester.getCenter(find.byType(FastScrollThumb));
    final travel =
        tester.view.physicalSize.height / tester.view.devicePixelRatio -
        trackTop -
        trackBottom -
        FastScrollMetrics.slot;
    final targetY = trackTop + FastScrollMetrics.slot / 2 + fraction * travel;
    final gesture = await tester.startGesture(start);
    await tester.pump();
    final dy = (targetY - start.dy) / steps;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, dy));
      await tester.pump();
    }
    return gesture;
  }

  Future<void> settle(WidgetTester tester, {int frames = 60}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('appears while scrolling and fades out after a pause', (
    WidgetTester tester,
  ) async {
    await pumpScroller(tester, total: 200);
    expect(find.byType(FastScrollThumb), findsNothing);

    await revealByScrolling(tester);
    expect(find.byType(FastScrollThumb), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FastScrollThumb), findsNothing);
  });

  testWidgets('never shows for lists shorter than a few screens', (
    WidgetTester tester,
  ) async {
    await pumpScroller(tester, total: 8);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FastScrollThumb), findsNothing);
  });

  testWidgets('dragging brings the item under the thumb to the top line', (
    WidgetTester tester,
  ) async {
    await pumpScroller(tester, total: 400);
    await revealByScrolling(tester);

    final gesture = await dragThumbTo(tester, 0.5);
    await settle(tester);

    final position = positionOf(tester);
    expect(topItem(tester), 200);
    expect(
      position.pixels,
      moreOrLessEquals(headerHeight + offsetOf(200), epsilon: 1),
      reason: '落点按实际布局校正到那一项的上缘',
    );
    // 气泡显示同一项的标签。
    expect(find.text('L200'), findsOneWidget);
    expect(find.text('C4'), findsOneWidget);
    // 分段刻度按住时出现。
    expect(find.text('S0'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('L200'), findsNothing, reason: '松手后气泡淡出');
    expect(topItem(tester), 200, reason: '松手不改变位置');
  });

  testWidgets('far jumps are spread over frames and land exactly', (
    WidgetTester tester,
  ) async {
    await pumpScroller(tester, total: 2000);
    await revealByScrolling(tester);
    final viewport = positionOf(tester).viewportDimension;

    final gesture = await dragThumbTo(tester, 0.75, steps: 1);
    final moved = <double>[];
    var last = positionOf(tester).pixels;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final pixels = positionOf(tester).pixels;
      moved.add((pixels - last).abs());
      last = pixels;
    }
    // 每帧最多约 32 项（平均高 100，按 SliverList 的估算会略有出入）或 3 屏。
    final cap = viewport * 3 > 3200 ? viewport * 3 : 3200.0;
    expect(moved.reduce((a, b) => a > b ? a : b), lessThan(cap * 1.1));
    expect(moved.where((step) => step > 1).length, greaterThan(5));
    expect(topItem(tester), 1500);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('reduced motion jumps straight to the target', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpScroller(tester, total: 2000);
    await revealByScrolling(tester);

    final gesture = await dragThumbTo(tester, 0.75, steps: 1);
    await tester.pump();
    await tester.pump();
    expect(topItem(tester), 1500);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('dragging past the loaded part requests every item once', (
    WidgetTester tester,
  ) async {
    await pumpScroller(tester, total: 400, loaded: 40);
    await revealByScrolling(tester);

    final gesture = await dragThumbTo(tester, 0.5);
    await settle(tester);

    expect(requests, isNotEmpty);
    expect(requests.toSet(), <int>{400});
    expect(topItem(tester), 200);
    expect(find.text('L200'), findsOneWidget);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('waits at the end of the loaded part until items arrive', (
    WidgetTester tester,
  ) async {
    await pumpScroller(tester, total: 400, loaded: 40, growOnRequest: false);
    await revealByScrolling(tester);

    final gesture = await dragThumbTo(tester, 0.5);
    await settle(tester);
    final position = positionOf(tester);
    expect(position.pixels, position.maxScrollExtent);
    expect(requests, isNotEmpty);
    // 气泡仍显示目标处的标签（来自完整的项数，不是已加载的末尾）。
    expect(find.text('L200'), findsOneWidget);
    await gesture.up();
    await tester.pump();

    // 等数据期间不挡列表：用户按住列表拖动即放弃这次跳转。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump();
    await settle(tester, frames: 10);
    expect(position.pixels, lessThan(position.maxScrollExtent));
  });

  testWidgets('works on a waterfall grid', (WidgetTester tester) async {
    await pumpScroller(tester, total: 400, masonry: true);
    await revealByScrolling(tester);

    final gesture = await dragThumbTo(tester, 0.5);
    await settle(tester);

    // 第 200 项落在顶线上（滚动视图上缘，这里没有固定的标签栏）。
    expect(tester.getTopLeft(find.text('item 200')).dy, moreOrLessEquals(0));
    expect(find.text('L200'), findsOneWidget);
    await gesture.up();
    await tester.pump();
  });

  for (final masonry in <bool>[false, true]) {
    testWidgets('a slow drag moves the ${masonry ? 'waterfall' : 'list'} '
        'one way only', (WidgetTester tester) async {
      await pumpScroller(tester, total: 400, masonry: masonry);
      await revealByScrolling(tester);
      final position = positionOf(tester);

      // 手指每帧 1dp 往下、再往上：瀑布流两列交错，相邻两篇的上缘谁高谁
      // 低不一定，列表也不能因此来回跳。
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FastScrollThumb)),
      );
      await tester.pump();
      for (final step in <double>[1, -1]) {
        var last = position.pixels;
        for (var i = 0; i < 150; i++) {
          await gesture.moveBy(Offset(0, step));
          await tester.pump(const Duration(milliseconds: 16));
          final delta = position.pixels - last;
          expect(
            delta * step,
            greaterThanOrEqualTo(-0.5),
            reason: 'frame $i moved $delta against the finger',
          );
          last = position.pixels;
        }
      }
      await gesture.up();
      await tester.pump();
    });
  }

  for (final masonry in <bool>[false, true]) {
    testWidgets('resting near the top of the '
        '${masonry ? 'waterfall' : 'list'} under pinned bars is stable', (
      WidgetTester tester,
    ) async {
      await pumpScroller(tester, total: 400, topBars: true, masonry: masonry);
      await revealByScrolling(tester);
      final position = positionOf(tester);

      // 拖到最顶，再往下一点点停在头一两篇之间：这里列表正从顶栏下方滑进
      // 去，滚动条换算若跟着被挡住的高度变，会每帧来回跳（实机上刊头随之
      // 反复弹出收起、整屏闪烁），松手后也停不下来。
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FastScrollThumb)),
      );
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await settle(tester, frames: 10);
      expect(position.pixels, 0);
      // 手指已越过轨道顶端：松开，在按钮上重新按住。
      await gesture.up();
      await tester.pump();
      final regrab = await tester.startGesture(
        tester.getCenter(find.byType(FastScrollThumb)),
      );
      await tester.pump();

      Future<void> expectStill(String when) async {
        final samples = <double>[];
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          samples.add(position.pixels);
        }
        final spread =
            samples.reduce((a, b) => a > b ? a : b) -
            samples.reduce((a, b) => a < b ? a : b);
        expect(spread, lessThan(0.5), reason: '$when: $samples');
      }

      // 第一步越过拖动阈值（2dp），之后每步约半篇。
      for (final step in <double>[3, 0.5, 0.5, 0.5]) {
        await regrab.moveBy(Offset(0, step));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await expectStill('holding');
      }
      await regrab.up();
      await tester.pump();
      await expectStill('released');
    });
  }

  testWidgets('a pending jump is dropped when the list changes', (
    WidgetTester tester,
  ) async {
    await pumpScroller(tester, total: 400, loaded: 40, growOnRequest: false);
    await revealByScrolling(tester);
    final gesture = await dragThumbTo(tester, 0.5);
    await settle(tester);
    await gesture.up();
    await tester.pump();
    final position = positionOf(tester);
    final waitingAt = position.pixels;

    // 换了筛选（列表身份变化），之后新列表的数据到了：不再跳到旧目标。
    identity.value = 'b';
    await tester.pump();
    loadedCount.value = 400;
    await settle(tester, frames: 20);
    expect(position.pixels, moreOrLessEquals(waitingAt));
  });

  testWidgets('ticks on grab and when crossing a section', (
    WidgetTester tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpScroller(tester, total: 200);
    await revealByScrolling(tester);

    final gesture = await dragThumbTo(tester, 0.6, steps: 12);
    await gesture.up();
    await tester.pump();
    // 按下一次；拖过 S50、S100 两个分段边界（起点已在第一段）。
    expect(haptics.length, greaterThanOrEqualTo(3));
    expect(haptics.toSet(), <String>{'HapticFeedbackType.selectionClick'});
  });

  testWidgets('on desktop, hovering the edge shows it and clicking the track '
      'jumps there', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pumpScroller(tester, total: 400);
      // 先滚动一下，让滚动条拿到滚动位置。
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -20));
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(FastScrollThumb), findsNothing);

      final size = tester.getSize(find.byType(CustomScrollView));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset(size.width - 4, size.height / 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FastScrollThumb), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(FastScrollThumb), findsOneWidget, reason: '悬停时保持');

      // 点按轨道正中：按钮中心对准指针，跳到一半处。
      await tester.tapAt(Offset(size.width - 4, size.height / 2));
      await settle(tester);
      expect(topItem(tester), 200);

      // 轨道挡在列表上，滚轮仍交给列表。
      final before = positionOf(tester).pixels;
      final wheel = TestPointer(2, PointerDeviceKind.mouse)
        ..hover(Offset(size.width - 4, size.height / 2));
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 120)));
      await tester.pump();
      expect(positionOf(tester).pixels, greaterThan(before));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

/// 日记页玻璃顶栏的刊头：最大 100（状态栏 44 + 内容 56），收起到 44。
class _MastheadDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 100;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => const ColoredBox(color: Color(0xFF8899AA));

  @override
  bool shouldRebuild(covariant _MastheadDelegate oldDelegate) => false;
}
