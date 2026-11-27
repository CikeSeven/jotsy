/// 专注记录的口径（纯函数，无 IO）。
///
/// 一段专注结束（到点或提前结束）时写一行 `todo_focus_sessions`，写完即不可
/// 变：不改、不删（覆盖恢复整库替换除外）。所以：
/// - 局域网同步与备份合并按 `session_id` 取并集，同一条两边永远相同；
/// - 删除待办时不清空记录上的 `todo_id`：撤销删除后这条待办的累计照旧，指向
///   不存在的待办时按“没有关联”算（总时长照常计入回顾）；
/// - 进行中的计时只存本机（界面层），结束才落库。
library;

import 'package:meta/meta.dart';

/// 一段专注怎么结束的。
enum TodoFocusOutcome {
  /// 到点。
  completed,

  /// 提前结束（已专注的部分照样记下）。
  stopped;

  /// 解析持久化值；认不出时按提前结束算（只影响显示，不影响时长）。
  static TodoFocusOutcome of(String raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return stopped;
  }
}

abstract final class TodoFocusRules {
  /// 专注不到这么多秒不记（误点开始又马上结束）。
  static const int minRecordedSeconds = 60;

  /// 一段专注的计划时长上限（分钟）：异常数据不让统计离谱。
  static const int maxPlannedMinutes = 240;

  /// 规整一段专注的秒数：不小于 0，不超过计划时长（计划时长本身限在
  /// [maxPlannedMinutes] 内）。
  static ({int planned, int focused}) clamp({
    required int plannedSeconds,
    required int focusedSeconds,
  }) {
    final planned = plannedSeconds.clamp(0, maxPlannedMinutes * 60);
    return (planned: planned, focused: focusedSeconds.clamp(0, planned));
  }
}

/// 要记下的一段专注。
@immutable
class TodoFocusInput {
  const TodoFocusInput({
    required this.todoId,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.focusedSeconds,
    required this.outcome,
  });

  /// 专注的待办；null 为只计时、没有关联待办。
  final String? todoId;
  final DateTime startedAt;
  final DateTime endedAt;

  /// 计划时长（含中途“加 5 分钟”）。
  final int plannedSeconds;

  /// 实际专注的秒数（扣掉暂停）。
  final int focusedSeconds;
  final TodoFocusOutcome outcome;
}
