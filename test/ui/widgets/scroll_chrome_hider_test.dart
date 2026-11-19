import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/scroll_chrome_hider.dart';

late BuildContext _context;

ScrollUpdateNotification _update(
  double pixels,
  double delta, {
  Axis axis = Axis.vertical,
  double max = 1000,
}) {
  return ScrollUpdateNotification(
    metrics: FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: max,
      pixels: pixels,
      viewportDimension: 600,
      axisDirection: axis == Axis.vertical
          ? AxisDirection.down
          : AxisDirection.right,
      devicePixelRatio: 1,
    ),
    context: _context,
    scrollDelta: delta,
  );
}

void main() {
  setUpAll(() {
    // ScrollUpdateNotification 需要一个 context；判定本身不读它。
    _context = _DummyElement();
  });

  test('往下滚过阈值才隐藏，往回滚过阈值显示', () {
    final hider = ScrollChromeHider();
    expect(hider.handle(_update(100, 5)), isNull);
    expect(hider.handle(_update(105, 5)), isTrue);
    expect(hider.handle(_update(100, -5)), isNull);
    expect(hider.handle(_update(95, -5)), isFalse);
  });

  test('来回抖动不累计', () {
    final hider = ScrollChromeHider();
    for (var i = 0; i < 10; i++) {
      expect(hider.handle(_update(100, 6)), isNull);
      expect(hider.handle(_update(100, -6)), isNull);
    }
  });

  test('贴在顶端时总是显示，横向滚动不参与', () {
    final hider = ScrollChromeHider();
    expect(hider.handle(_update(0, 20)), isFalse);
    expect(hider.handle(_update(300, 50, axis: Axis.horizontal)), isNull);
  });

  test('滚到底端时只在 revealAtEnd 时显示', () {
    expect(ScrollChromeHider().handle(_update(1000, 20)), isTrue);
    expect(
      ScrollChromeHider(revealAtEnd: true).handle(_update(1000, 20)),
      isFalse,
    );
  });
}

class _DummyElement extends StatelessElement {
  _DummyElement() : super(const _Dummy());
}

class _Dummy extends StatelessWidget {
  const _Dummy();

  @override
  Widget build(BuildContext context) => const SizedBox();
}
