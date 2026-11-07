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
}
