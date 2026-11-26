import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/sliver_collapse.dart';

/// 可动画折叠的 sliver：整块按高度弹簧收起 / 展开、后面的内容随之移动，
/// 收起停稳后卸下子 sliver、点不到也读不到，减少动画时直接到位。
void main() {
  Future<void> pumpGroup(
    WidgetTester tester, {
    required bool expanded,
    bool disableAnimations = false,
    VoidCallback? onTapRow,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: CustomScrollView(
              slivers: <Widget>[
                AnimatedSliverCollapse(
                  expanded: expanded,
                  sliver: SliverList.builder(
                    itemCount: 3,
                    itemBuilder: (BuildContext context, int index) =>
                        GestureDetector(
                          onTap: onTapRow,
                          child: SizedBox(
                            height: 100,
                            child: Text('row $index'),
                          ),
                        ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 50, child: Text('after')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double afterTop(WidgetTester tester) =>
      tester.getTopLeft(find.text('after')).dy;

  testWidgets('collapsing slides what follows up and then unmounts the rows', (
    tester,
  ) async {
    await pumpGroup(tester, expanded: true);
    final expandedTop = afterTop(tester);
    expect(expandedTop, 300);

    await pumpGroup(tester, expanded: false);
    await tester.pump(const Duration(milliseconds: 60));
    final mid = afterTop(tester);
    expect(mid, lessThan(expandedTop));
    expect(mid, greaterThan(0));
    // 收起途中各行还在，只是被裁掉一部分。
    expect(find.text('row 0'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(afterTop(tester), 0);
    expect(find.text('row 0'), findsNothing);
  });

  testWidgets('expanding again rebuilds the rows and pushes content down', (
    tester,
  ) async {
    await pumpGroup(tester, expanded: false);
    expect(afterTop(tester), 0);
    expect(find.text('row 0'), findsNothing);

    await pumpGroup(tester, expanded: true);
    await tester.pump(const Duration(milliseconds: 60));
    expect(afterTop(tester), greaterThan(0));
    expect(afterTop(tester), lessThan(300));

    await tester.pumpAndSettle();
    expect(afterTop(tester), 300);
    expect(find.text('row 2'), findsOneWidget);
  });

  testWidgets('the clipped part does not take taps', (tester) async {
    var taps = 0;
    await pumpGroup(tester, expanded: true, onTapRow: () => taps++);
    await pumpGroup(tester, expanded: false, onTapRow: () => taps++);
    await tester.pump(const Duration(milliseconds: 60));
    // 收起后范围之外、原本还是某一行的地方：已经让给后面的内容。
    final top = afterTop(tester);
    expect(top, lessThan(290));
    await tester.tapAt(Offset(20, top + 10));
    expect(taps, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion collapses and expands at once', (tester) async {
    await pumpGroup(tester, expanded: true, disableAnimations: true);
    await pumpGroup(tester, expanded: false, disableAnimations: true);
    await tester.pump();
    expect(afterTop(tester), 0);
    expect(find.text('row 0'), findsNothing);

    await pumpGroup(tester, expanded: true, disableAnimations: true);
    await tester.pump();
    expect(afterTop(tester), 300);
  });
}
