import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/list_make_room.dart';

/// 位置稳定瀑布流（MakeRoomSliverMasonryGrid / RenderStableMasonryGrid）与
/// 锚点保持列表（MakeRoomSliverList）的回归测试。
void main() {
  double heightFor(String id) {
    final num = int.tryParse(id.replaceFirst('item-', '')) ?? 0;
    return 120.0 + (num % 5) * 32.0;
  }

  List<String> makeIds(int count) =>
      List<String>.generate(count, (int i) => 'item-$i');

  Widget buildGridApp({
    required List<String> ids,
    required ScrollController controller,
    int columns = 2,
    MakeRoomController? makeRoom,
  }) {
    final indexByKey = <String, int>{
      for (var i = 0; i < ids.length; i++) 'tile_${ids[i]}': i,
    };
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 800,
          child: CustomScrollView(
            controller: controller,
            slivers: <Widget>[
              MakeRoomSliverMasonryGrid.count(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childCount: ids.length,
                itemKeys: ids,
                findChildIndexCallback: (Key key) =>
                    key is ValueKey<String> ? indexByKey[key.value] : null,
                makeRoom: makeRoom,
                itemBuilder: (BuildContext context, int index) {
                  final id = ids[index];
                  Widget tile = SizedBox(
                    key: ValueKey<String>('box_$id'),
                    height: heightFor(id),
                    child: Center(child: Text(id)),
                  );
                  if (makeRoom != null) {
                    tile = MakeRoomItem(
                      tag: id,
                      controller: makeRoom,
                      child: tile,
                    );
                  }
                  return KeyedSubtree(
                    key: ValueKey<String>('tile_$id'),
                    child: tile,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets(
    'deleting a visible waterfall item deep in the list keeps scroll position '
    'and reuses surviving child elements without remounting',
    (WidgetTester tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final ids = makeIds(50);

      await tester.pumpWidget(buildGridApp(ids: ids, controller: controller));
      await tester.pumpAndSettle();

      // 向下滚动到较深位置（远超默认 250dp cacheExtent）。
      controller.jumpTo(1800);
      await tester.pumpAndSettle();
      final pixelsBefore = controller.position.pixels;
      expect(pixelsBefore, greaterThan(1500));

      // 挑出视口内可见的几个条目：删除中间那张，检查前后存活卡片元素均不重挂。
      final visibleIds = <String>[];
      for (final id in ids) {
        final finder = find.byKey(ValueKey<String>('box_$id'));
        if (finder.evaluate().isEmpty) continue;
        final rect = tester.getRect(finder);
        if (rect.bottom > 0 && rect.top < 800) {
          visibleIds.add(id);
        }
      }
      expect(visibleIds.length, greaterThanOrEqualTo(4));
      final beforeId = visibleIds.first;
      final deletedId = visibleIds[visibleIds.length ~/ 2];
      final afterId = visibleIds.last;
      final beforeElement = tester.element(
        find.byKey(ValueKey<String>('box_$beforeId')),
      );
      final afterElement = tester.element(
        find.byKey(ValueKey<String>('box_$afterId')),
      );
      final beforeTop = tester
          .getTopLeft(find.byKey(ValueKey<String>('box_$beforeId')))
          .dy;

      final nextIds = <String>[
        for (final id in ids)
          if (id != deletedId) id,
      ];
      await tester.pumpWidget(
        buildGridApp(ids: nextIds, controller: controller),
      );
      await tester.pumpAndSettle();

      // 不得回弹到上半部分，滚动偏移与上方可见卡片位置都纹丝不动。
      expect(controller.position.pixels, closeTo(pixelsBefore, 1.0));
      expect(
        tester.getTopLeft(find.byKey(ValueKey<String>('box_$beforeId'))).dy,
        closeTo(beforeTop, 1.0),
      );
      // 存活卡片（删点前与删点后）均复用原有 Element，不触发重建/闪烁。
      expect(
        tester.element(find.byKey(ValueKey<String>('box_$beforeId'))),
        same(beforeElement),
      );
      expect(
        tester.element(find.byKey(ValueKey<String>('box_$afterId'))),
        same(afterElement),
      );

      // 滚回顶部：首张卡片紧贴顶部 0，无残留空位或异常。
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('box_item-0'))).dy,
        closeTo(0.0, 0.5),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deleting or inserting items strictly above the viewport keeps the '
    'visible anchor locked on screen without bogus FLIP bounce',
    (WidgetTester tester) async {
      final ids = makeIds(50);
      late MakeRoomController makeRoom;

      // 删除视口上方（靠前）两条同高且分别落在两列的条目（item-0 与 item-5，
      // 或者先统一等高场景）：这里用等高条目确保两列同步平移，验证 MakeRoom
      // 收到滚动偏移校正后不会对视口内未动的卡片触发伪让位动画。
      final equalController = ScrollController();
      addTearDown(equalController.dispose);
      Widget buildEqualGrid(List<String> list, MakeRoomController mr) {
        final indexByKey = <String, int>{
          for (var i = 0; i < list.length; i++) 'tile_${list[i]}': i,
        };
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 800,
              child: CustomScrollView(
                controller: equalController,
                slivers: <Widget>[
                  MakeRoomSliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childCount: list.length,
                    itemKeys: list,
                    findChildIndexCallback: (Key key) =>
                        key is ValueKey<String> ? indexByKey[key.value] : null,
                    makeRoom: mr,
                    itemBuilder: (BuildContext context, int index) {
                      final id = list[index];
                      return KeyedSubtree(
                        key: ValueKey<String>('tile_$id'),
                        child: MakeRoomItem(
                          tag: id,
                          controller: mr,
                          child: SizedBox(
                            key: ValueKey<String>('box_$id'),
                            height: 160,
                            child: Center(child: Text(id)),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(
        _MakeRoomHost(
          onController: (MakeRoomController value) => makeRoom = value,
          builder: (BuildContext context, MakeRoomController value) =>
              buildEqualGrid(ids, value),
        ),
      );
      await tester.pumpAndSettle();

      for (final offset in <double>[600, 1200, 1800]) {
        equalController.jumpTo(offset);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      late String anchorId;
      late double anchorScreenY;
      for (final id in ids) {
        final finder = find.byKey(ValueKey<String>('box_$id'));
        if (finder.evaluate().isEmpty) continue;
        final rect = tester.getRect(finder);
        if (rect.bottom > 0 && rect.top < 800) {
          anchorId = id;
          anchorScreenY = rect.top;
          break;
        }
      }
      final anchorElement = tester.element(
        find.byKey(ValueKey<String>('box_$anchorId')),
      );

      makeRoom.animateLayoutChange();
      final afterDelete = <String>[
        for (final id in ids)
          if (id != 'item-0' && id != 'item-1') id,
      ];
      await tester.pumpWidget(
        _MakeRoomHost(
          onController: (_) {},
          builder: (BuildContext context, MakeRoomController value) =>
              buildEqualGrid(afterDelete, value),
        ),
      );
      await tester.pump();

      // 锚点屏幕位置锁在原地、元素复用、不产生伪让位位移。
      expect(
        tester.getTopLeft(find.byKey(ValueKey<String>('box_$anchorId'))).dy,
        closeTo(anchorScreenY, 1.0),
      );
      expect(
        tester.element(find.byKey(ValueKey<String>('box_$anchorId'))),
        same(anchorElement),
      );
      expect(makeRoom.isActive, isFalse);

      // 再往视口上方索引 0 插入两条新卡片：锚点依然锁在原位。
      final afterInsert = <String>['item-new-a', 'item-new-b', ...afterDelete];
      await tester.pumpWidget(
        _MakeRoomHost(
          onController: (_) {},
          builder: (BuildContext context, MakeRoomController value) =>
              buildEqualGrid(afterInsert, value),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(ValueKey<String>('box_$anchorId'))).dy,
        closeTo(anchorScreenY, 1.0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mounting a fresh masonry grid with a non-zero initial scroll offset '
    'stays scrolled instead of jumping back to the top',
    (WidgetTester tester) async {
      final controller = ScrollController(initialScrollOffset: 1400);
      addTearDown(controller.dispose);
      final ids = makeIds(50);

      await tester.pumpWidget(buildGridApp(ids: ids, controller: controller));
      await tester.pumpAndSettle();

      expect(controller.position.pixels, closeTo(1400, 1.0));
      expect(find.text('item-0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing column count while scrolled keeps the anchor near the viewport',
    (WidgetTester tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final ids = makeIds(60);

      await tester.pumpWidget(
        buildGridApp(ids: ids, controller: controller, columns: 2),
      );
      await tester.pumpAndSettle();
      for (final offset in <double>[700, 1400, 2100]) {
        controller.jumpTo(offset);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      late String anchorId;
      for (final id in ids) {
        final finder = find.byKey(ValueKey<String>('box_$id'));
        if (finder.evaluate().isEmpty) continue;
        final rect = tester.getRect(finder);
        if (rect.top >= 0 && rect.top < 800) {
          anchorId = id;
          break;
        }
      }

      await tester.pumpWidget(
        buildGridApp(ids: ids, controller: controller, columns: 3),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey<String>('box_$anchorId')), findsOneWidget);
      expect(controller.position.pixels, greaterThan(800));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'handles boundary cases: empty list, single item in 2 columns, and '
    'deleting trailing items at bottom',
    (WidgetTester tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      // 空列表
      await tester.pumpWidget(
        buildGridApp(ids: const <String>[], controller: controller),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 2 列仅 1 项
      await tester.pumpWidget(
        buildGridApp(ids: const <String>['item-0'], controller: controller),
      );
      await tester.pumpAndSettle();
      expect(find.text('item-0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 滚到底部后删除末尾多项：平滑收缩到新底部，不抛断言也不弹回顶部。
      final ids = makeIds(30);
      await tester.pumpWidget(buildGridApp(ids: ids, controller: controller));
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(controller.position.pixels, greaterThan(1000));

      await tester.pumpWidget(
        buildGridApp(ids: ids.sublist(0, 22), controller: controller),
      );
      await tester.pumpAndSettle();
      expect(controller.position.pixels, greaterThan(500));
      expect(tester.takeException(), isNull);
    },
  );
}

class _MakeRoomHost extends StatefulWidget {
  const _MakeRoomHost({required this.onController, required this.builder});

  final ValueChanged<MakeRoomController> onController;
  final Widget Function(BuildContext context, MakeRoomController controller)
  builder;

  @override
  State<_MakeRoomHost> createState() => _MakeRoomHostState();
}

class _MakeRoomHostState extends State<_MakeRoomHost>
    with TickerProviderStateMixin {
  late final MakeRoomController _controller = MakeRoomController(vsync: this);

  @override
  void initState() {
    super.initState();
    widget.onController(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
