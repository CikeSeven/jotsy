import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/keyboard_visibility.dart';

/// 记录自己被构建了几次、最后读到的键盘状态。
class _Probe extends StatelessWidget {
  const _Probe(this.log);

  final List<bool> log;

  @override
  Widget build(BuildContext context) {
    log.add(KeyboardVisibility.of(context));
    return const SizedBox.shrink();
  }
}

class _BuildCounter extends StatelessWidget {
  const _BuildCounter(this.onBuild);

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const SizedBox(height: 10);
  }
}

Future<void> _animateKeyboard(WidgetTester tester, List<double> insets) async {
  for (final inset in insets) {
    tester.view.viewInsets = FakeViewPadding(bottom: inset);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('dependents rebuild only when the keyboard shows or hides', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final log = <bool>[];
    await tester.pumpWidget(
      MaterialApp(home: KeyboardVisibility(child: _Probe(log))),
    );
    expect(log, <bool>[false]);

    await _animateKeyboard(tester, <double>[40, 120, 200, 280, 300]);
    expect(log, <bool>[false, true]);

    await _animateKeyboard(tester, <double>[220, 140, 60, 0]);
    expect(log, <bool>[false, true, false]);
  });

  testWidgets('without a scope it still reports the keyboard state', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final log = <bool>[];
    await tester.pumpWidget(MaterialApp(home: _Probe(log)));
    await _animateKeyboard(tester, <double>[100, 200]);
    // 没有 KeyboardVisibility 祖先时退回直接读 viewInsets：逐帧重建，结果一致。
    expect(log, <bool>[false, true, true]);
  });

  testWidgets('KeyboardInsetPadding follows the keyboard without rebuilding '
      'its child', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var childBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: KeyboardInsetPadding(
            child: _BuildCounter(() => childBuilds++),
          ),
        ),
      ),
    );
    expect(childBuilds, 1);

    await _animateKeyboard(tester, <double>[80, 160, 240]);
    expect(childBuilds, 1);
    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(KeyboardInsetPadding),
        matching: find.byType(Padding),
      ),
    );
    expect(padding.padding, const EdgeInsets.only(bottom: 240));
    expect(tester.getSize(find.byType(KeyboardInsetPadding)).height, 250);
  });

  group('KeyboardShield', () {
    late List<EdgeInsets> insets;
    late List<EdgeInsets> paddings;
    late List<bool> visible;

    Widget shield({required bool shielded}) => MaterialApp(
      home: KeyboardShield(
        shielded: shielded,
        child: Builder(
          builder: (BuildContext context) {
            insets.add(MediaQuery.viewInsetsOf(context));
            paddings.add(MediaQuery.paddingOf(context));
            visible.add(KeyboardVisibility.of(context));
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    setUp(() {
      insets = <EdgeInsets>[];
      paddings = <EdgeInsets>[];
      visible = <bool>[];
    });

    testWidgets('a shielded page never rebuilds for the keyboard', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..viewPadding = const FakeViewPadding(bottom: 24)
        ..padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(shield(shielded: true));
      expect(insets, <EdgeInsets>[EdgeInsets.zero]);

      // 键盘升起：底边 padding 被盖住逐帧变小，viewInsets 逐帧变大。
      for (final inset in <double>[12, 60, 180, 300]) {
        tester.view
          ..viewInsets = FakeViewPadding(bottom: inset)
          ..padding = FakeViewPadding(bottom: (24 - inset).clamp(0, 24));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(insets, <EdgeInsets>[EdgeInsets.zero]);
      expect(paddings, <EdgeInsets>[const EdgeInsets.only(bottom: 24)]);
      expect(visible, <bool>[false]);
    });

    testWidgets('lifting the shield follows the real keyboard and freezing '
        'keeps the value from that moment', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(shield(shielded: false));
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pump();
      expect(insets.last, const EdgeInsets.only(bottom: 200));
      expect(visible.last, isTrue);
      final element = tester.element(find.byType(Builder).last);

      // 盖上别的页面时冻结在此刻：键盘再动也不跟着变，子树不重新挂载。
      await tester.pumpWidget(shield(shielded: true));
      final frozenBuilds = insets.length;
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pump();
      expect(insets.length, frozenBuilds);
      expect(insets.last, const EdgeInsets.only(bottom: 200));
      expect(
        identical(tester.element(find.byType(Builder).last), element),
        isTrue,
      );

      // 揭开后回到真实的键盘高度。
      await tester.pumpWidget(shield(shielded: false));
      expect(insets.last, const EdgeInsets.only(bottom: 320));
    });

    testWidgets('shielded from the first frame ignores a leftover keyboard', (
      tester,
    ) async {
      // 从别的应用切过来时，第一帧可能还带着上一个应用没收起的键盘。
      tester.view
        ..devicePixelRatio = 1
        ..viewPadding = const FakeViewPadding(bottom: 24)
        ..padding = FakeViewPadding.zero
        ..viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(shield(shielded: true));
      expect(insets.last, EdgeInsets.zero);
      expect(paddings.last, const EdgeInsets.only(bottom: 24));
      expect(visible.last, isFalse);

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      expect(insets.last, EdgeInsets.zero);
    });
  });
}
