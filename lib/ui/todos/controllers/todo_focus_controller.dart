import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/todo_reminders/todo_notification_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/providers/app_features_provider.dart';
import '../models/todo_focus_run.dart';
import '../models/todo_focus_settings.dart';
import '../providers/todo_providers.dart';
import '../providers/todo_reminder_providers.dart';

/// 专注计时此刻的状态：正在走的一段（[run]），或刚走完、等用户决定下一步
/// 的一段（[ended]）；两者都没有即没在计时。
@immutable
class TodoFocusState {
  const TodoFocusState({this.run, this.ended});

  final TodoFocusRun? run;
  final TodoFocusEnded? ended;

  bool get idle => run == null && ended == null;
}

/// 专注计时（整个应用只有一段）：开始、暂停 / 继续、加时、提前结束、休息。
///
/// - 计时按墙钟推算（[TodoFocusRun]）：退后台、被杀进程、重启后读回本机保存
///   的状态接着走；走完的那一刻按计划时刻记，不按用户回来的时刻；
/// - 状态只存本机（SharedPreferences 键 [storageKey]，不随备份、不同步），
///   专注走完或提前结束（满 60 秒）时才写一行专注记录；
/// - 通知只经 [TodoNotificationGateway]：开始、继续、加时时排倒计时与结束
///   提醒，暂停与提前结束时撤下；走完时不撤（结束提醒正好弹出、倒计时自己
///   收起）；
/// - 应用里每秒看一次是否走完（页面关着也看），回到前台最迟一秒内接上；
/// - 功能关掉（待办或专注计时）时停下，不记录正在走的这一段。
class TodoFocusController extends Notifier<TodoFocusState> {
  /// 本机保存进行中计时的键。
  static const String storageKey = 'app.todos.focus_run';

  Timer? _ticker;
  bool _restored = false;

  @override
  TodoFocusState build() {
    ref.onDispose(() => _ticker?.cancel());
    ref.listen<bool>(
      appFeaturesProvider.select((features) => features.todoFocusEnabled),
      (bool? before, bool on) {
        if (before == true && !on) unawaited(_clear());
      },
    );
    unawaited(_restore());
    return const TodoFocusState();
  }

  DateTime get _now => ref.read(todoNowProvider)();

  TodoFocusSettings get _settings => ref.read(todoSettingsProvider).focus;

  /// 开始专注（第 [round] 轮；不给时接着上一段数）。已经在计时时先停下
  /// 上一段（满 60 秒的照样记下）。
  Future<void> start({required String? todoId, required String title}) async {
    final ended = state.ended;
    final round = ended == null ? 1 : ended.nextRound(_settings);
    if (state.run != null) await stop();
    await _begin(
      TodoFocusRun.start(
        phase: TodoFocusPhase.focus,
        todoId: todoId,
        title: title,
        round: round,
        settings: _settings,
        now: _now,
      ),
    );
  }

  /// 专注走完后开始休息（短休或长休按轮数）。
  Future<void> startBreak() async {
    final ended = state.ended;
    if (ended == null || ended.phase != TodoFocusPhase.focus) return;
    await _begin(
      TodoFocusRun.start(
        phase: ended.nextBreak(_settings),
        todoId: ended.todoId,
        title: ended.title,
        round: ended.round,
        settings: _settings,
        now: _now,
      ),
    );
  }

  /// 走完后接着专注下一轮（跳过休息，或休息完了）。
  Future<void> startNext() async {
    final ended = state.ended;
    if (ended == null) return;
    await _begin(
      TodoFocusRun.start(
        phase: TodoFocusPhase.focus,
        todoId: ended.todoId,
        title: ended.title,
        round: ended.nextRound(_settings),
        settings: _settings,
        now: _now,
      ),
    );
  }

  Future<void> pause() async {
    final run = state.run;
    if (run == null || run.paused) return;
    _ticker?.cancel();
    state = TodoFocusState(run: run.pause(_now));
    await _cancelNotice();
    await _save();
  }

  Future<void> resume() async {
    final run = state.run;
    if (run == null || !run.paused) return;
    await _begin(run.resume(_now));
  }

  /// 加 5 分钟（暂停中也可以加）。
  Future<void> extend() async {
    final run = state.run;
    if (run == null) return;
    final next = run.extend();
    if (next.paused) {
      state = TodoFocusState(run: next);
      await _save();
      return;
    }
    await _begin(next);
  }

  /// 提前结束：专注满 60 秒的记下（按实际专注的秒数）；休息直接结束。
  Future<void> stop() async {
    final run = state.run;
    if (run == null) return;
    _ticker?.cancel();
    final now = _now;
    state = const TodoFocusState();
    await _cancelNotice();
    await _save();
    if (run.phase == TodoFocusPhase.focus) {
      await ref
          .read(appDatabaseProvider)
          .addTodoFocusSession(
            TodoFocusInput(
              todoId: run.todoId,
              startedAt: run.startedAt,
              endedAt: run.pausedAt ?? now,
              plannedSeconds: run.plannedSeconds,
              focusedSeconds: run.elapsed(now),
              outcome: TodoFocusOutcome.stopped,
            ),
          );
    }
  }

  /// 收起“走完了”的提示，回到没在计时。
  Future<void> dismiss() async {
    if (state.ended == null) return;
    state = const TodoFocusState();
    await _save();
  }

  /// 看一下是否走完（每秒、回到前台与读回时）。
  Future<void> check() async {
    final run = state.run;
    if (run == null || !run.finished(_now)) return;
    _ticker?.cancel();
    final focused = run.phase == TodoFocusPhase.focus ? run.plannedSeconds : 0;
    state = TodoFocusState(
      ended: TodoFocusEnded(
        phase: run.phase,
        todoId: run.todoId,
        title: run.title,
        round: run.round,
        focusedSeconds: focused,
      ),
    );
    await _save();
    if (run.phase == TodoFocusPhase.focus) {
      await ref
          .read(appDatabaseProvider)
          .addTodoFocusSession(
            TodoFocusInput(
              todoId: run.todoId,
              startedAt: run.startedAt,
              endedAt: run.endsAt,
              plannedSeconds: run.plannedSeconds,
              focusedSeconds: run.plannedSeconds,
              outcome: TodoFocusOutcome.completed,
            ),
          );
    }
  }

  Future<void> _begin(TodoFocusRun run) async {
    if (!ref.read(appFeaturesProvider).todoFocusEnabled) return;
    state = TodoFocusState(run: run);
    _tick();
    await _save();
    await _notify(run);
  }

  void _tick() {
    _ticker?.cancel();
    final run = state.run;
    if (run == null || run.paused) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(check());
    });
  }

  TodoNotificationGateway? get _gateway =>
      ref.read(todoNotificationGatewayProvider);

  /// 撤下倒计时与结束提醒；失败（插件出错）不影响计时。
  Future<void> _cancelNotice() async {
    try {
      await _gateway?.cancelFocus();
    } catch (error) {
      debugPrint('todo focus: cancelling the notice failed: $error');
    }
  }

  Future<void> _notify(TodoFocusRun run) async {
    final l10n = lookupAppLocalizations(_locale);
    final title = run.title.trim();
    final minutes = (run.plannedSeconds / 60).round();
    try {
      final gateway = _gateway;
      if (gateway == null) return;
      await gateway.showFocus(
        TodoFocusNotice(
          title: run.phase.isBreak
              ? l10n.todoFocusBreakRunningTitle
              : title.isEmpty
              ? l10n.todoFocusRunningUntitled
              : l10n.todoFocusRunningTitle(title),
          endsAt: run.endsAt,
          endTitle: run.phase.isBreak
              ? l10n.todoFocusBreakEndTitle
              : l10n.todoFocusEndTitle,
          endBody: run.phase.isBreak
              ? l10n.todoFocusBreakEndBody
              : l10n.todoFocusEndBody(minutes),
          channelName: l10n.todoFocusChannelName,
          channelDescription: l10n.todoFocusChannelDescription,
        ),
      );
    } catch (error) {
      // 通知只是锦上添花：排不上（没有权限、插件出错）时计时照常。
      debugPrint('todo focus: notice failed: $error');
    }
  }

  Locale get _locale =>
      ref.read(settingsServiceProvider).asData?.value.localeNotifier.value ??
      const Locale('en');

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final run = state.run;
    final ended = state.ended;
    if (run == null && ended == null) {
      await prefs.remove(storageKey);
      return;
    }
    await prefs.setString(
      storageKey,
      jsonEncode(<String, Object?>{
        if (run != null) 'run': run.toJson(),
        if (ended != null) 'ended': ended.toJson(),
      }),
    );
  }

  /// 读回本机保存的计时（只一次）：走完的按计划时刻记下，没走完的接着走。
  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || !state.idle) return;
    Object? node;
    try {
      node = jsonDecode(raw);
    } on FormatException {
      node = null;
    }
    final run = node is Map ? TodoFocusRun.fromJson(node['run']) : null;
    final ended = node is Map ? TodoFocusEnded.fromJson(node['ended']) : null;
    if (run == null && ended == null) {
      await prefs.remove(storageKey);
      return;
    }
    state = TodoFocusState(run: run, ended: run == null ? ended : null);
    if (run != null) {
      await check();
      if (state.run != null) _tick();
    }
  }

  /// 功能关掉：停下、撤掉通知，不记正在走的这一段。
  Future<void> _clear() async {
    _ticker?.cancel();
    state = const TodoFocusState();
    await _cancelNotice();
    await _save();
  }
}

/// 专注计时（整个应用只有一段）。
final todoFocusProvider = NotifierProvider<TodoFocusController, TodoFocusState>(
  TodoFocusController.new,
);

/// 从 [since]（本周一零点）起一共专注了多少秒（回顾卡的“本周专注”）。
final todoFocusSinceProvider = StreamProvider.autoDispose.family<int, DateTime>(
  (Ref ref, DateTime since) => ref
      .watch(appDatabaseProvider)
      .watchTodoFocusSince(since)
      .map(
        (List<TodoFocusRow> rows) => rows.fold<int>(
          0,
          (int sum, TodoFocusRow row) => sum + row.focusedSeconds,
        ),
      ),
);

/// 一条待办累计专注了多少秒（详情里的“累计专注”）。
final todoFocusSecondsProvider = StreamProvider.autoDispose.family<int, String>(
  (Ref ref, String todoId) =>
      ref.watch(appDatabaseProvider).watchTodoFocusSeconds(todoId),
);
