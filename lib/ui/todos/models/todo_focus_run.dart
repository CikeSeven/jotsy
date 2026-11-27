import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import 'todo_focus_settings.dart';

/// 一段计时是专注还是休息。枚举名即持久化值。
enum TodoFocusPhase {
  focus,
  shortBreak,
  longBreak;

  bool get isBreak => this != focus;
}

/// 正在进行的一段专注或休息（纯数据 + 墙钟推算，无副作用）。
///
/// 只记开始时刻、计划秒数、暂停开始的时刻与累计暂停的秒数，剩余时间随时
/// 由“此刻”算出，不靠逐秒计数：退到后台、进程被杀、重启后读回来都接得上；
/// 系统时间往回拨时已过的时间按 0 算，不会出现负数。
@immutable
class TodoFocusRun {
  const TodoFocusRun({
    required this.phase,
    required this.todoId,
    required this.title,
    required this.round,
    required this.startedAt,
    required this.plannedSeconds,
    this.pausedAt,
    this.pausedSeconds = 0,
  });

  /// 开始一段：专注按设置的时长，休息按 [round] 决定短休还是长休。
  factory TodoFocusRun.start({
    required TodoFocusPhase phase,
    required String? todoId,
    required String title,
    required int round,
    required TodoFocusSettings settings,
    required DateTime now,
  }) {
    final minutes = switch (phase) {
      TodoFocusPhase.focus => settings.focusMinutes,
      TodoFocusPhase.shortBreak => settings.shortBreakMinutes,
      TodoFocusPhase.longBreak => settings.longBreakMinutes,
    };
    return TodoFocusRun(
      phase: phase,
      todoId: todoId,
      title: title,
      round: round,
      startedAt: now,
      plannedSeconds: minutes * 60,
    );
  }

  /// 每次“加时”加多少秒。
  static const int extendSeconds = 5 * 60;

  final TodoFocusPhase phase;

  /// 专注的待办；null 为只计时。
  final String? todoId;

  /// 开始时的待办标题（待办之后被删或改名，计时页仍有字可写）。
  final String title;

  /// 这是这一轮循环里的第几次专注（从 1 起，长休后回到 1）。
  final int round;
  final DateTime startedAt;
  final int plannedSeconds;

  /// 暂停开始的时刻；null 为正在走。
  final DateTime? pausedAt;

  /// 之前各次暂停累计的秒数（不含正在进行的这次）。
  final int pausedSeconds;

  bool get paused => pausedAt != null;

  /// 已经走了多少秒（扣掉暂停），夹在 0 与计划时长之间。
  int elapsed(DateTime now) {
    final until = pausedAt ?? now;
    final seconds = until.difference(startedAt).inSeconds - pausedSeconds;
    return seconds.clamp(0, plannedSeconds);
  }

  int remaining(DateTime now) => plannedSeconds - elapsed(now);

  /// 走完了（暂停中的不算）。
  bool finished(DateTime now) => !paused && remaining(now) <= 0;

  /// 不再暂停时会在什么时刻走完（排结束提醒、记结束时刻用）。
  DateTime get endsAt =>
      startedAt.add(Duration(seconds: pausedSeconds + plannedSeconds));

  TodoFocusRun pause(DateTime now) => paused ? this : _copy(pausedAt: now);

  TodoFocusRun resume(DateTime now) {
    final at = pausedAt;
    if (at == null) return this;
    final gap = now.difference(at).inSeconds;
    return _copy(pausedSeconds: pausedSeconds + (gap < 0 ? 0 : gap));
  }

  /// 加 [extendSeconds] 秒，不超过 [TodoFocusRules.maxPlannedMinutes]。
  TodoFocusRun extend() => _copy(
    plannedSeconds: (plannedSeconds + extendSeconds).clamp(
      0,
      TodoFocusRules.maxPlannedMinutes * 60,
    ),
  );

  TodoFocusRun _copy({
    int? plannedSeconds,
    int? pausedSeconds,
    DateTime? pausedAt,
  }) => TodoFocusRun(
    phase: phase,
    todoId: todoId,
    title: title,
    round: round,
    startedAt: startedAt,
    plannedSeconds: plannedSeconds ?? this.plannedSeconds,
    // 只有 pause 传 pausedAt；resume 传 pausedSeconds 并清掉暂停。
    pausedAt: pausedSeconds != null ? null : (pausedAt ?? this.pausedAt),
    pausedSeconds: pausedSeconds ?? this.pausedSeconds,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'phase': phase.name,
    if (todoId != null) 'todoId': todoId,
    'title': title,
    'round': round,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'planned': plannedSeconds,
    if (pausedAt != null) 'pausedAt': pausedAt!.millisecondsSinceEpoch,
    'paused': pausedSeconds,
  };

  /// 读回本机保存的计时；坏数据为 null（当作没有在计时）。
  static TodoFocusRun? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final phase = TodoFocusPhase.values.asNameMap()[raw['phase']];
    final todoId = raw['todoId'];
    final title = raw['title'];
    final round = raw['round'];
    final started = raw['startedAt'];
    final planned = raw['planned'];
    final pausedAt = raw['pausedAt'];
    final paused = raw['paused'];
    if (phase == null ||
        (todoId != null && todoId is! String) ||
        title is! String ||
        round is! int ||
        started is! int ||
        planned is! int ||
        planned <= 0 ||
        (pausedAt != null && pausedAt is! int) ||
        paused is! int ||
        paused < 0) {
      return null;
    }
    return TodoFocusRun(
      phase: phase,
      todoId: todoId as String?,
      title: title,
      round: round < 1 ? 1 : round,
      startedAt: DateTime.fromMillisecondsSinceEpoch(started),
      plannedSeconds: planned,
      pausedAt: pausedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(pausedAt as int),
      pausedSeconds: paused,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TodoFocusRun &&
      other.phase == phase &&
      other.todoId == todoId &&
      other.title == title &&
      other.round == round &&
      other.startedAt == startedAt &&
      other.plannedSeconds == plannedSeconds &&
      other.pausedAt == pausedAt &&
      other.pausedSeconds == pausedSeconds;

  @override
  int get hashCode => Object.hash(
    phase,
    todoId,
    title,
    round,
    startedAt,
    plannedSeconds,
    pausedAt,
    pausedSeconds,
  );
}

/// 一段刚走完、等用户决定下一步的计时（专注完了去休息，休息完了再专注）。
@immutable
class TodoFocusEnded {
  const TodoFocusEnded({
    required this.phase,
    required this.todoId,
    required this.title,
    required this.round,
    required this.focusedSeconds,
  });

  final TodoFocusPhase phase;
  final String? todoId;
  final String title;
  final int round;

  /// 专注了多少秒（休息走完时为 0）。
  final int focusedSeconds;

  /// 专注走完后该休哪一种：每 [TodoFocusSettings.longBreakEvery] 轮长休一次。
  TodoFocusPhase nextBreak(TodoFocusSettings settings) =>
      round >= settings.longBreakEvery
      ? TodoFocusPhase.longBreak
      : TodoFocusPhase.shortBreak;

  /// 下一次专注是第几轮：长休之后回到 1，其余接着数（专注完跳过休息也
  /// 一样），数满一轮循环回到 1。
  int nextRound(TodoFocusSettings settings) => phase == TodoFocusPhase.longBreak
      ? 1
      : round % settings.longBreakEvery + 1;

  Map<String, Object?> toJson() => <String, Object?>{
    'phase': phase.name,
    if (todoId != null) 'todoId': todoId,
    'title': title,
    'round': round,
    'focused': focusedSeconds,
  };

  static TodoFocusEnded? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final phase = TodoFocusPhase.values.asNameMap()[raw['phase']];
    final todoId = raw['todoId'];
    final title = raw['title'];
    final round = raw['round'];
    final focused = raw['focused'];
    if (phase == null ||
        (todoId != null && todoId is! String) ||
        title is! String ||
        round is! int ||
        focused is! int) {
      return null;
    }
    return TodoFocusEnded(
      phase: phase,
      todoId: todoId as String?,
      title: title,
      round: round < 1 ? 1 : round,
      focusedSeconds: focused < 0 ? 0 : focused,
    );
  }
}
