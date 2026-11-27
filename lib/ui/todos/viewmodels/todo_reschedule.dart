import 'package:flutter/foundation.dart';

/// 改期面板里几个快捷日子（都按本地零点的 [today] 算，纯函数）：
/// - [tomorrow]：明天；
/// - [weekend]：本周末，这个周六；今天已是周六时就是今天，周日时为下周六；
/// - [nextMonday]：下周一（今天是周一时为七天后）；
/// - [inAWeek]：七天后。
@immutable
class TodoRescheduleDays {
  factory TodoRescheduleDays.of(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    DateTime plus(int days) => DateTime(day.year, day.month, day.day + days);
    final toSaturday = (DateTime.saturday - day.weekday + 7) % 7;
    final toMonday = (DateTime.monday - day.weekday + 7) % 7;
    return TodoRescheduleDays._(
      today: day,
      tomorrow: plus(1),
      weekend: plus(toSaturday),
      nextMonday: plus(toMonday == 0 ? 7 : toMonday),
      inAWeek: plus(7),
    );
  }

  const TodoRescheduleDays._({
    required this.today,
    required this.tomorrow,
    required this.weekend,
    required this.nextMonday,
    required this.inAWeek,
  });

  final DateTime today;
  final DateTime tomorrow;
  final DateTime weekend;
  final DateTime nextMonday;
  final DateTime inAWeek;
}
