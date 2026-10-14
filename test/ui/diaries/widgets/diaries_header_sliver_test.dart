import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/widgets/diaries_header_sliver.dart';

class _Probe extends StatefulWidget {
  const _Probe({required this.label});

  final String label;

  static int created = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

Widget _host(ScrollController controller, {required bool pinned}) {
  return MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        controller: controller,
        slivers: <Widget>[
          DiariesHeaderSliver(
            pinned: pinned,
            height: 68,
            backgroundColor: const Color(0xFFEEEEEE),
            child: SizedBox(
              height: 68,
              child: _Probe(label: pinned ? 'selecting' : 'normal'),
            ),
          ),
          const PinnedHeaderSliver(
            child: SizedBox(height: 40, child: Text('tags')),
          ),
          SliverList.builder(
            itemCount: 100,
            itemBuilder: (context, index) =>
                SizedBox(height: 60, child: Text('item $index')),
          ),
        ],
      ),
    ),
  );
}

double _tagsTop(WidgetTester tester) => tester.getTopLeft(find.text('tags')).dy;

void main() {
  setUp(() => _Probe.created = 0);

  testWidgets('selection header slides in and out together with the tag bar', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, pinned: false));
    controller.jumpTo(600);
    await tester.pump();
    // 浮动顶栏已滚出，标签栏固定在最顶部。
    expect(_tagsTop(tester), 0);
    final itemTop = tester.getTopLeft(find.text('item 12')).dy;

    await tester.pumpWidget(_host(controller, pinned: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // 顶栏从顶部滑下，标签栏随之同步下移，而不是瞬移一整个顶栏高度。
    expect(_tagsTop(tester), inExclusiveRange(0, 68));
    // 列表本身不随过渡移动。
    expect(tester.getTopLeft(find.text('item 12')).dy, itemTop);
    await tester.pumpAndSettle();
    expect(_tagsTop(tester), 68);

    await tester.pumpWidget(_host(controller, pinned: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_tagsTop(tester), inExclusiveRange(0, 68));
    await tester.pumpAndSettle();
    expect(_tagsTop(tester), 0);
    expect(tester.getTopLeft(find.text('item 12')).dy, itemTop);

    // 切换形态时顶栏内容整体迁移，内部状态（如交叉淡入）不重建。
    expect(_Probe.created, 1);
  });

  testWidgets('header already visible at the top switches without motion', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, pinned: false));
    expect(_tagsTop(tester), 68);

    await tester.pumpWidget(_host(controller, pinned: true));
    expect(_tagsTop(tester), 68);
    await tester.pumpWidget(_host(controller, pinned: false));
    expect(_tagsTop(tester), 68);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('selection header appears at once under reduce motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, pinned: false));
    controller.jumpTo(600);
    await tester.pump();

    await tester.pumpWidget(_host(controller, pinned: true));
    expect(_tagsTop(tester), 68);
    await tester.pumpWidget(_host(controller, pinned: false));
    expect(_tagsTop(tester), 0);
  });
}
