import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/todos/controllers/todo_focus_controller.dart';
import 'package:node_diary/ui/todos/models/todo_focus_run.dart';
import 'package:node_diary/ui/todos/providers/todo_providers.dart';
import 'package:node_diary/ui/todos/providers/todo_reminder_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_todo_notifications.dart';

/// 专注计时的控制器：开始排通知、暂停撤下、继续按新的结束时刻重排；走完按
/// 计划时刻记一行；提前结束满 60 秒才记；进程重启后读回接着算；休息与下一
/// 轮；功能关掉时停下、不记。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SettingsService settings;
  late FakeTodoNotificationGateway gateway;
  final start = DateTime(2026, 11, 28, 9);
  late DateTime clock;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    await settings.setAppFeaturesRaw('{"todos":true}');
    gateway = FakeTodoNotificationGateway();
    clock = start;
  });
  tearDown(() => db.close());

  Future<ProviderContainer> container() async {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsServiceProvider.overrideWith((ref) async => settings),
        todoNowProvider.overrideWithValue(() => clock),
        todoNotificationGatewayProvider.overrideWithValue(gateway),
      ],
    );
    await c.read(settingsServiceProvider.future);
    c.read(todoFocusProvider);
    // 读回本机保存的计时是异步的。
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return c;
  }

  Future<List<TodoFocusRow>> sessions() =>
      db.select(db.todoFocusSessions).get();

  test('pausing and resuming moves the end; running out records it', () async {
    final c = await container();
    final focus = c.read(todoFocusProvider.notifier);
    await focus.start(todoId: 't1', title: '写报告');
    expect(gateway.focus!.endsAt, start.add(const Duration(minutes: 25)));
    expect(gateway.focus!.title, contains('写报告'));

    clock = start.add(const Duration(minutes: 10));
    await focus.pause();
    expect(gateway.focus, isNull);
    clock = start.add(const Duration(minutes: 15));
    await focus.resume();
    expect(gateway.focus!.endsAt, start.add(const Duration(minutes: 30)));

    clock = start.add(const Duration(minutes: 31));
    await focus.check();
    final state = c.read(todoFocusProvider);
    expect(state.run, isNull);
    expect(state.ended!.focusedSeconds, 1500);
    final row = (await sessions()).single;
    expect(row.todoId, 't1');
    expect(row.endedAt, start.add(const Duration(minutes: 30)));
    expect(row.focusedSeconds, 1500);
    expect(TodoFocusOutcome.of(row.outcome), TodoFocusOutcome.completed);
    c.dispose();
  });

  test('ending early keeps what was focused, from a minute on', () async {
    final c = await container();
    final focus = c.read(todoFocusProvider.notifier);
    await focus.start(todoId: null, title: '');
    clock = start.add(const Duration(minutes: 10));
    await focus.stop();
    expect(c.read(todoFocusProvider).idle, isTrue);
    await focus.start(todoId: null, title: '');
    clock = clock.add(const Duration(seconds: 30));
    await focus.stop();
    final rows = await sessions();
    expect(rows.single.focusedSeconds, 600);
    expect(TodoFocusOutcome.of(rows.single.outcome), TodoFocusOutcome.stopped);
    expect(gateway.focusCancels, greaterThanOrEqualTo(2));
    c.dispose();
  });

  test('after a restart a run that ran out is recorded at its end', () async {
    var c = await container();
    await c.read(todoFocusProvider.notifier).start(todoId: 't1', title: '写报告');
    c.dispose();

    clock = start.add(const Duration(hours: 2));
    c = await container();
    final state = c.read(todoFocusProvider);
    expect(state.ended?.phase, TodoFocusPhase.focus);
    final row = (await sessions()).single;
    expect(row.endedAt, start.add(const Duration(minutes: 25)));
    c.dispose();

    // 再开一次不重复记。
    c = await container();
    expect(await sessions(), hasLength(1));
    expect(c.read(todoFocusProvider).ended, isNotNull);
    c.dispose();
  });

  test('a break follows a focus, then the next round', () async {
    final c = await container();
    final focus = c.read(todoFocusProvider.notifier);
    await focus.start(todoId: 't1', title: '写报告');
    clock = start.add(const Duration(minutes: 26));
    await focus.check();
    await focus.startBreak();
    var run = c.read(todoFocusProvider).run!;
    expect(run.phase, TodoFocusPhase.shortBreak);
    expect(run.plannedSeconds, 5 * 60);
    clock = clock.add(const Duration(minutes: 6));
    await focus.check();
    expect(c.read(todoFocusProvider).ended!.phase, TodoFocusPhase.shortBreak);
    await focus.startNext();
    run = c.read(todoFocusProvider).run!;
    expect((run.phase, run.round, run.todoId), (TodoFocusPhase.focus, 2, 't1'));
    expect(await sessions(), hasLength(1), reason: '休息不记');
    c.dispose();
  });

  test('turning the timer off stops it without recording', () async {
    final c = await container();
    await c.read(todoFocusProvider.notifier).start(todoId: null, title: '');
    clock = start.add(const Duration(minutes: 10));
    await settings.setAppFeaturesRaw('{"todos":true,"todoFocus":false}');
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.read(todoFocusProvider).idle, isTrue);
    expect(gateway.focus, isNull);
    expect(await sessions(), isEmpty);
    await c.read(todoFocusProvider.notifier).start(todoId: null, title: '');
    expect(c.read(todoFocusProvider).idle, isTrue, reason: '关着时不能开始');
    c.dispose();
  });
}
