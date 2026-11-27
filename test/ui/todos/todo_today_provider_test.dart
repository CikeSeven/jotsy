import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/todos/providers/todo_providers.dart';

/// 待办的“今天”：跨过零点自动换到新的一天，回到前台时按此刻校正。
void main() {
  testWidgets('rolls over to the next day at midnight', (tester) async {
    var now = DateTime(2026, 3, 1, 23, 59, 30);
    final container = ProviderContainer(
      overrides: [todoNowProvider.overrideWithValue(() => now)],
    );
    final days = <DateTime>[];
    container.listen<DateTime>(
      todoTodayProvider,
      (DateTime? previous, DateTime next) => days.add(next),
      fireImmediately: true,
    );
    expect(days, <DateTime>[DateTime(2026, 3, 1)]);

    now = DateTime(2026, 3, 2, 0, 0, 1);
    await tester.pump(const Duration(seconds: 31));
    expect(days, <DateTime>[DateTime(2026, 3, 1), DateTime(2026, 3, 2)]);
    // 在测试体里释放：零点计时器随之取消。放进 tearDown 的话，CI 上的
    // flutter_test 先查“还有计时器没走”，再跑 tearDown。
    container.dispose();
  });

  testWidgets('refresh catches up after the device slept past midnight', (
    tester,
  ) async {
    var now = DateTime(2026, 3, 1, 22);
    final container = ProviderContainer(
      overrides: [todoNowProvider.overrideWithValue(() => now)],
    );
    expect(container.read(todoTodayProvider), DateTime(2026, 3, 1));

    // 系统冻结了计时器：零点没有触发，回到前台时校正。
    now = DateTime(2026, 3, 3, 8);
    container.read(todoTodayProvider.notifier).refresh();
    expect(container.read(todoTodayProvider), DateTime(2026, 3, 3));

    // 同一天里再校正不改值。
    now = DateTime(2026, 3, 3, 9);
    container.read(todoTodayProvider.notifier).refresh();
    expect(container.read(todoTodayProvider), DateTime(2026, 3, 3));
    container.dispose();
  });
}
