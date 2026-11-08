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

/// 每个清单里未完成的待办数（键为清单业务 id，收集箱为 null）。
final todoOpenCountsByListProvider = StreamProvider<Map<String?, int>>((
  Ref ref,
) {
  return ref.watch(appDatabaseProvider).watchOpenTodoCountsByList();
});

/// 日历用的按日索引。重新加载期间沿用上一份数据，日期格上的角标不会闪
/// 一下消失；还没有数据时为空索引。只在待办功能开启、日历显示待办时订阅。
final todoCalendarIndexProvider = Provider<TodoCalendarIndex>((Ref ref) {
  final open = ref.watch(openTodosProvider).value;
  final completed = ref.watch(completedTodosProvider).value;
  if (open == null && completed == null) return TodoCalendarIndex.empty;
  final now = DateTime.now();
  return TodoCalendarIndex.build(
    open: open ?? const <TodoRow>[],
    completed: completed ?? const <TodoRow>[],
    today: DateTime(now.year, now.month, now.day),
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
