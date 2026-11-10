import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';

// ExpressiveMotion.springTo：真弹簧驱动无界控制器——过冲、停稳时落在目标值、
// 中途改目标保留速度、减少动画时直接到位。

/// 挂一个只提供 context 与 vsync 的宿主，返回它持有的无界控制器。
Future<(AnimationController, BuildContext)> _pumpHost(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  late AnimationController controller;
  late BuildContext context;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: _Host(
        onReady: (AnimationController c, BuildContext ctx) {
          controller = c;
          context = ctx;
        },
      ),
    ),
  );
  return (controller, context);
}

class _Host extends StatefulWidget {
  const _Host({required this.onReady});

  final void Function(AnimationController controller, BuildContext context)
  onReady;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onReady(_controller, context);
    return const SizedBox.shrink();
  }
}

void main() {
  testWidgets('overshoots the target and settles exactly on it', (
    tester,
  ) async {
    final (controller, context) = await _pumpHost(tester);
    ExpressiveMotion.springTo(
      context,
      controller,
      100,
      spring: ExpressiveMotion.springSpatialFast,
    );
    expect(controller.isAnimating, isTrue);

    var peak = 0.0;
    for (var i = 0; i < 120 && controller.isAnimating; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      if (controller.value > peak) peak = controller.value;
    }
    // 欠阻尼：越过目标再回落；停稳后精确等于目标（不留容差以内的偏差）。
    expect(peak, greaterThan(102));
    expect(peak, lessThan(125));
    expect(controller.isAnimating, isFalse);
    expect(controller.value, 100);
  });

  testWidgets('retargeting mid-flight keeps the current velocity', (
    tester,
  ) async {
    final (controller, context) = await _pumpHost(tester);
    ExpressiveMotion.springTo(context, controller, 100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final before = controller.value;
    final velocity = controller.velocity;
    expect(velocity, greaterThan(0));

    // 掉头：带着向前的速度，下一帧仍在往前走一点，随后才折返。
    ExpressiveMotion.springTo(context, controller, 0);
    // 新模拟的计时从它的第一帧起算，再推进一帧才有位移。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 8));
    expect(controller.value, greaterThan(before));
    await tester.pumpAndSettle();
    expect(controller.value, 0);
  });

  testWidgets('reduce motion jumps without running a simulation', (
    tester,
  ) async {
    final (controller, context) = await _pumpHost(tester, reduceMotion: true);
    var notified = 0;
    controller.addListener(() => notified++);
    ExpressiveMotion.springTo(context, controller, 42);
    expect(controller.value, 42);
    expect(controller.isAnimating, isFalse);
    expect(notified, 1);
  });

  testWidgets('already resting on the target starts nothing', (tester) async {
    final (controller, context) = await _pumpHost(tester);
    ExpressiveMotion.springTo(context, controller, 0);
    expect(controller.isAnimating, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  test('the spring tokens are underdamped (they overshoot)', () {
    for (final spring in <SpringDescription>[
      ExpressiveMotion.springSpatial,
      ExpressiveMotion.springSpatialFast,
      ExpressiveMotion.springIndicator,
    ]) {
      // 阻尼比 = c / (2·√(k·m))，小于 1 才会过冲。
      final ratio =
          spring.damping / (2 * math.sqrt(spring.stiffness * spring.mass));
      expect(ratio, lessThan(1));
      expect(ratio, greaterThan(0.5));
    }
  });
}
