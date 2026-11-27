import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/todos/models/todo_focus_run.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_focus_format.dart';

/// 专注计时的墙钟推算：暂停扣掉、时钟往回拨按 0、加时有上限、读回坏数据
/// 当作没在计时；轮数与长短休；节奏设置的容错读写。
void main() {
  final start = DateTime(2026, 11, 28, 9);
  TodoFocusRun run({int planned = 1500}) => TodoFocusRun(
    phase: TodoFocusPhase.focus,
    todoId: 't1',
    title: '写报告',
    round: 1,
    startedAt: start,
    plannedSeconds: planned,
  );
  DateTime at(int seconds) => start.add(Duration(seconds: seconds));

  test('remaining time follows the wall clock and skips pauses', () {
    var r = run();
    expect(r.remaining(at(600)), 900);
    r = r.pause(at(600));
    expect(r.remaining(at(1200)), 900, reason: '暂停时不走');
    expect(r.finished(at(99999)), isFalse, reason: '暂停中的不算走完');
    r = r.resume(at(1200));
    expect(r.pausedSeconds, 600);
    expect(r.remaining(at(1500)), 600);
    expect(r.endsAt, at(2100));
    expect(r.finished(at(2100)), isTrue);
    expect(r.elapsed(at(9999)), 1500, reason: '不超过计划时长');
  });

  test('a clock set back counts as nothing elapsed', () {
    final r = run();
    expect(r.elapsed(start.subtract(const Duration(hours: 1))), 0);
    expect(
      r.pause(at(60)).resume(at(30)).pausedSeconds,
      0,
      reason: '往回拨的暂停不算负数',
    );
  });

  test('extending adds five minutes up to the cap', () {
    expect(run().extend().plannedSeconds, 1800);
    expect(run(planned: 240 * 60 - 60).extend().plannedSeconds, 240 * 60);
    final paused = run().pause(at(10)).extend();
    expect(paused.paused, isTrue, reason: '暂停中加时仍是暂停');
  });

  test('saved runs round-trip; bad data reads as no run', () {
    final r = run().pause(at(42));
    expect(TodoFocusRun.fromJson(r.toJson()), r);
    expect(TodoFocusRun.fromJson(<String, Object?>{'phase': 'focus'}), isNull);
    expect(
      TodoFocusRun.fromJson(<String, Object?>{...r.toJson(), 'planned': 0}),
      isNull,
    );
    expect(TodoFocusRun.fromJson('x'), isNull);
    const ended = TodoFocusEnded(
      phase: TodoFocusPhase.focus,
      todoId: null,
      title: '',
      round: 2,
      focusedSeconds: 1500,
    );
    final back = TodoFocusEnded.fromJson(ended.toJson())!;
    expect(
      (back.phase, back.round, back.focusedSeconds),
      (TodoFocusPhase.focus, 2, 1500),
    );
  });

  test('rounds cycle and every fourth focus earns a long break', () {
    const settings = TodoFocusSettings();
    TodoFocusEnded ended(TodoFocusPhase phase, int round) => TodoFocusEnded(
      phase: phase,
      todoId: null,
      title: '',
      round: round,
      focusedSeconds: 0,
    );
    expect(
      ended(TodoFocusPhase.focus, 3).nextBreak(settings),
      TodoFocusPhase.shortBreak,
    );
    expect(
      ended(TodoFocusPhase.focus, 4).nextBreak(settings),
      TodoFocusPhase.longBreak,
    );
    expect(ended(TodoFocusPhase.shortBreak, 2).nextRound(settings), 3);
    expect(ended(TodoFocusPhase.longBreak, 4).nextRound(settings), 1);
    expect(ended(TodoFocusPhase.focus, 4).nextRound(settings), 1);
  });

  test('focus settings are read field by field and written only when set', () {
    final settings = TodoSettings.decode(
      '{"focus": {"focusMinutes": 50, "shortBreakMinutes": 7, '
      '"longBreakEvery": 3}}',
    );
    expect(settings.focus.focusMinutes, 50);
    expect(settings.focus.shortBreakMinutes, 5, reason: '不在可选值里回到默认');
    expect(settings.focus.longBreakEvery, 3);
    expect(TodoSettings.defaults.encode(), isNull);
    final again = TodoSettings.decode(settings.encode());
    expect(again.focus, settings.focus);
  });

  test('clock and duration formatting', () {
    expect(TodoFocusFormat.clock(1500), '25:00');
    expect(TodoFocusFormat.clock(3725), '1:02:05');
    expect(TodoFocusFormat.clock(-3), '00:00');
  });
}
