import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/list_item_presence.dart';

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 100, child: Text('card'));
}

Widget _host({
  required bool visible,
  required bool appearing,
  Duration duration = const Duration(milliseconds: 250),
  bool resize = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: <Widget>[
          ListItemPresence(
            visible: visible,
            appearing: appearing,
            duration: duration,
            resize: resize,
            child: const _Probe(),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('card state survives appear and exit animations', (tester) async {
    await tester.pumpWidget(_host(visible: true, appearing: true));
    final probe = tester.state<_ProbeState>(find.byType(_Probe));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.state(find.byType(_Probe)), same(probe));

    await tester.pumpAndSettle();
    // 动画结束切换到静止态时不能重新挂载卡片子树。
    expect(tester.state(find.byType(_Probe)), same(probe));

    await tester.pumpWidget(_host(visible: false, appearing: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.state(find.byType(_Probe)), same(probe));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ListItemPresence)).height, 0);
  });

  testWidgets('settled item does not clip its shadow', (tester) async {
    await tester.pumpWidget(_host(visible: true, appearing: false));
    final clip = tester.widget<ClipRect>(
      find.descendant(
        of: find.byType(ListItemPresence),
        matching: find.byType(ClipRect),
      ),
    );
    expect(clip.clipBehavior, Clip.none);
    expect(tester.getSize(find.byType(ListItemPresence)).height, 100);
  });

  testWidgets('zero duration settles immediately for reduce motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(visible: true, appearing: true, duration: Duration.zero),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(ListItemPresence)).height, 100);
  });

  testWidgets('without resizing the item keeps its height and scales', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(visible: true, appearing: false, resize: false),
    );
    final probe = tester.state<_ProbeState>(find.byType(_Probe));
    Transform transform() => tester.widget<Transform>(
      find.descendant(
        of: find.byType(ListItemPresence),
        matching: find.byType(Transform),
      ),
    );
    expect(transform().transform.entry(0, 0), 1);

    await tester.pumpWidget(
      _host(visible: false, appearing: false, resize: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // 原尺寸退场：高度不变（瀑布流里别的卡片不会逐帧换列），只缩小、淡出。
    expect(tester.getSize(find.byType(ListItemPresence)).height, 100);
    expect(transform().transform.entry(0, 0), lessThan(1));
    expect(tester.state(find.byType(_Probe)), same(probe));

    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ListItemPresence)).height, 100);
    expect(
      transform().transform.entry(0, 0),
      moreOrLessEquals(ListItemPresence.hiddenScale),
    );
  });
}
