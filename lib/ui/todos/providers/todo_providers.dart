import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/todo_settings.dart';
import '../viewmodels/todo_calendar_index.dart';

/// 待办的数据与偏好。数据一律经 drift `.watch()` 推送：本机编辑、局域网同步
/// 写入与导入备份后都会自动刷新，所以不必登记到 `syncedDataRefreshProvider`。

/// 全部未完成的待办（按拖动顺序）。
final openTodosProvider = StreamProvider<List<TodoRow>>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchOpenTodos();
});

/// 最近完成的待办（最近的在前，至多 500 条）。
final completedTodosProvider = StreamProvider<List<TodoRow>>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchCompletedTodos();
});

/// 全部清单（按拖动顺序）。
final todoListsProvider = StreamProvider<List<TodoListRow>>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchTodoLists();
});

/// 每个清单的完成进度（键为清单业务 id，收集箱为 null；没有待办的清单不在
/// 表里，按 [TodoListProgress.empty] 处理）。
final todoListProgressProvider = StreamProvider<Map<String?, TodoListProgress>>(
  (Ref ref) {
    return ref.watch(appDatabaseProvider).watchTodoListProgress();
  },
);

/// 取当前时刻的函数（测试替换它来模拟跨过零点）。
final todoNowProvider = Provider<DateTime Function()>(
  (Ref ref) => DateTime.now,
);

/// 本地零点的“今天”：分组、逾期、相对日期与概览卡都以它为准。
///
/// 为什么不在 build 里直接取 `DateTime.now()`：页面只在数据或状态变化时
/// 重建，应用开着跨过零点后，“今天”视图仍停在昨天、昨天的待办也不算逾期，
/// 直到碰巧有别的变化。这里在下一个零点换到新的一天；计时器在后台可能被
/// 系统推迟或冻结，回到前台时由页面调用 [TodoTodayNotifier.refresh] 校正。
final todoTodayProvider = NotifierProvider<TodoTodayNotifier, DateTime>(
  TodoTodayNotifier.new,
);

class TodoTodayNotifier extends Notifier<DateTime> {
  Timer? _midnight;

  @override
  DateTime build() {
    final now = ref.watch(todoNowProvider)();
    ref.onDispose(() => _midnight?.cancel());
    _scheduleAfter(now);
    return DateTime(now.year, now.month, now.day);
  }

  /// 按此刻的时间重算“今天”（日期没变时不通知），并重排下一次零点。
  void refresh() {
    final now = ref.read(todoNowProvider)();
    final today = DateTime(now.year, now.month, now.day);
    if (today != state) state = today;
    _scheduleAfter(now);
  }

  void _scheduleAfter(DateTime now) {
    _midnight?.cancel();
    final next = DateTime(now.year, now.month, now.day + 1);
    // 多等一秒：计时器可能比墙钟早几毫秒触发，落在零点之前就白跑一次。
    // 用日历分量算下一个零点，跨夏令时切换的那天也落在当地零点。
    _midnight = Timer(
      next.difference(now) + const Duration(seconds: 1),
      refresh,
    );
  }
}

/// 整分的“此刻”：只给按分钟变化的说法（“还有 25 分钟”）用，别的界面
/// 不要监听它，免得每分钟重建。
///
/// autoDispose：没有行需要倒数时不留计时器。计时器对齐到下一个整分（多等
/// 一秒，免得早几毫秒触发落在上一分）；退后台时计时器可能被推迟，回到前台
/// 后的第一次触发即校正。
final todoMinuteProvider =
    NotifierProvider.autoDispose<TodoMinuteNotifier, DateTime>(
      TodoMinuteNotifier.new,
    );

class TodoMinuteNotifier extends Notifier<DateTime> {
  Timer? _tick;

  @override
  DateTime build() {
    final now = ref.watch(todoNowProvider)();
    ref.onDispose(() => _tick?.cancel());
    _scheduleAfter(now);
    return _floor(now);
  }

  void _refresh() {
    final now = ref.read(todoNowProvider)();
    state = _floor(now);
    _scheduleAfter(now);
  }

  void _scheduleAfter(DateTime now) {
    _tick?.cancel();
    final next = _floor(now).add(const Duration(minutes: 1));
    _tick = Timer(next.difference(now) + const Duration(seconds: 1), _refresh);
  }

  static DateTime _floor(DateTime t) =>
      DateTime(t.year, t.month, t.day, t.hour, t.minute);
}

/// 日历用的按日索引。重新加载期间沿用上一份数据，日期格上的角标不会闪
/// 一下消失；还没有数据时为空索引。只在待办功能开启、日历显示待办时订阅。
final todoCalendarIndexProvider = Provider<TodoCalendarIndex>((Ref ref) {
  final open = ref.watch(openTodosProvider).value;
  final completed = ref.watch(completedTodosProvider).value;
  if (open == null && completed == null) return TodoCalendarIndex.empty;
  return TodoCalendarIndex.build(
    open: open ?? const <TodoRow>[],
    completed: completed ?? const <TodoRow>[],
    today: ref.watch(todoTodayProvider),
  );
});

/// 单条待办（详情页）；被删除后推送 null。
final todoProvider = StreamProvider.autoDispose.family<TodoRow?, String>((
  Ref ref,
  String todoId,
) {
  return ref.watch(appDatabaseProvider).watchTodo(todoId);
});

/// 搜索结果（含已完成的）；关键词为空时为空列表。
final todoSearchProvider = StreamProvider.autoDispose
    .family<List<TodoRow>, String>((Ref ref, String keyword) {
      return ref.watch(appDatabaseProvider).watchTodoSearch(keyword);
    });

/// 关联了某篇日记的待办（预览页的“相关待办”）。
final todosLinkedToDiaryProvider = StreamProvider.autoDispose
    .family<List<TodoRow>, String>((Ref ref, String diaryId) {
      return ref.watch(appDatabaseProvider).watchTodosLinkedToDiary(diaryId);
    });

/// 关联的日记（不含回收站中的）；进回收站或被彻底删除后推送 null。
final todoLinkedDiaryProvider = StreamProvider.autoDispose
    .family<DiaryWithTags?, String>((Ref ref, String diaryId) {
      return ref.watch(appDatabaseProvider).watchActiveDiaryWithTags(diaryId);
    });

/// 待办的偏好（格式见 [TodoSettings]）。
///
/// 同步 Notifier：settings 未就绪时给默认值；就绪后 build 立即同步解码。
/// 设置页写入、备份恢复与失败回滚、局域网同步设置都会改写 raw notifier；
/// 监听它并按 `==` 去重。
final todoSettingsProvider =
    NotifierProvider<TodoSettingsNotifier, TodoSettings>(
      TodoSettingsNotifier.new,
    );

class TodoSettingsNotifier extends Notifier<TodoSettings> {
  @override
  TodoSettings build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) return TodoSettings.defaults;
    final rawNotifier = settings.todoSettingsRawNotifier;
    void listener() {
      final next = TodoSettings.decode(rawNotifier.value);
      if (next != state) state = next;
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return TodoSettings.decode(rawNotifier.value);
  }
}

/// 持久化待办的偏好；全为默认时移除该键。
Future<void> saveTodoSettings(SettingsService settings, TodoSettings value) =>
    settings.setTodoSettingsRaw(value.encode());
