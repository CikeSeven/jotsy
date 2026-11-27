import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/list_make_room.dart';

/// 让位控制器按整个滚动视图的坐标记位置（[MakeRoomController.acrossSlivers]）：
/// 一项从一个 sliver 换到另一个时从原位置滑过去，前面的 sliver 变高时
/// 后面的项也滑到新位置。
void main() {
  Future<void> pumpLists(
    WidgetTester tester, {
    required List<String> top,
    required List<String> bottom,
    double header = 0,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TwoLists(top: top, bottom: bottom, header: header),
        ),
      ),
    );
  }

  double topOf(WidgetTester tester, String id) =>
      tester.getTopLeft(find.byKey(ValueKey<String>('box_$id'))).dy;

  testWidgets('an item moving to another sliver slides from where it was', (
    tester,
  ) async {
    await pumpLists(tester, top: <String>['a', 'x'], bottom: <String>['b']);
    final before = topOf(tester, 'x');
    expect(before, 100);

    await pumpLists(tester, top: <String>['a'], bottom: <String>['b', 'x']);
    // 新布局里它在第二个 sliver 的末尾，但这一帧仍画在原位置。
    expect(topOf(tester, 'x'), moreOrLessEquals(before));

    // 弹簧在帧后起步，下一帧才开始计时。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final mid = topOf(tester, 'x');
    expect(mid, greaterThan(before));
    expect(mid, lessThan(200));

    await tester.pumpAndSettle();
    expect(topOf(tester, 'x'), moreOrLessEquals(200));
  });

  testWidgets('items after a growing sliver slide instead of jumping', (
    tester,
  ) async {
    await pumpLists(tester, top: <String>['a'], bottom: <String>['b']);
    final before = topOf(tester, 'b');

    await pumpLists(
      tester,
      top: <String>['a'],
      bottom: <String>['b'],
      header: 60,
    );
    expect(topOf(tester, 'b'), moreOrLessEquals(before));

    await tester.pumpAndSettle();
    expect(topOf(tester, 'b'), moreOrLessEquals(before + 60));
  });
}

/// 两个让位列表（中间可垫一段 [header]），换数据的那一次 build 里调用
/// [MakeRoomController.animateLayoutChange]（与列表宿主的用法相同）。
class _TwoLists extends StatefulWidget {
  const _TwoLists({
    required this.top,
    required this.bottom,
    required this.header,
  });

  final List<String> top;
  final List<String> bottom;
  final double header;

  @override
  State<_TwoLists> createState() => _TwoListsState();
}

class _TwoListsState extends State<_TwoLists>
    with SingleTickerProviderStateMixin {
  late final MakeRoomController _controller = MakeRoomController(
    vsync: this,
    acrossSlivers: true,
  );

  @override
  void didUpdateWidget(covariant _TwoLists oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.animateLayoutChange();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _list(List<String> ids) => MakeRoomSliverList(
    makeRoom: _controller,
    delegate: SliverChildBuilderDelegate(
      (BuildContext context, int index) => KeyedSubtree(
        key: ValueKey<String>('item_${ids[index]}'),
        child: MakeRoomItem(
          tag: ids[index],
          controller: _controller,
          child: SizedBox(
            key: ValueKey<String>('box_${ids[index]}'),
            height: 100,
            child: Text(ids[index]),
          ),
        ),
      ),
      childCount: ids.length,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        _list(widget.top),
        SliverToBoxAdapter(child: SizedBox(height: widget.header)),
        _list(widget.bottom),
      ],
    );
  }
}
