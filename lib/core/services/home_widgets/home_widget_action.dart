// 桌面小组件上不打开应用就能完成的操作（docs/rules/home_widgets.md「桌面上的
// 操作」）：`jotsy://widget-action/<动作>?参数`。
//
// 原生点按时先改界面（乐观更新，`WidgetOverlay.kt`），再经 home_widget 的后台
// 回调把链接交给 Dart（`homeWidgetBackgroundCallback`），由这里解析并写库。
// 写库的口径只有 [applyHomeWidgetAction]：主 isolate 与后台引擎都调它。

import '../../database/app_database.dart';

const String kHomeWidgetActionHost = 'widget-action';

sealed class HomeWidgetAction {
  const HomeWidgetAction();

  /// 解析链接；不是小组件操作或参数不对时返回 null（什么都不做）。
  static HomeWidgetAction? parse(Uri? uri) {
    if (uri == null ||
        uri.scheme != 'jotsy' ||
        uri.host != kHomeWidgetActionHost) {
      return null;
    }
    final segments = uri.pathSegments;
    final target = segments.isEmpty ? '' : segments.first;
    final query = uri.queryParameters;
    switch (target) {
      case 'mood':
        final day = parseAnniversaryDate(query['day'] ?? '');
        if (day == null) return null;
        final raw = query['mood'] ?? '';
        final mood = DayMood.parse(raw);
        // 空串表示取消；认不出的心情（更新版本的原生）不写。
        if (raw.isNotEmpty && mood == null) return null;
        return HomeWidgetSetMoodAction(day: day, mood: mood);
      case 'todo-complete':
        final id = query['id'] ?? '';
        if (id.isEmpty) return null;
        final due = query['due'] ?? '';
        return HomeWidgetCompleteTodoAction(
          todoId: id,
          occurrence: due.isEmpty ? null : due,
        );
      case 'todo-reopen':
        final id = query['id'] ?? '';
        return id.isEmpty ? null : HomeWidgetReopenTodoAction(todoId: id);
      default:
        return null;
    }
  }
}

/// 记下（[mood] 为 null 时取消）某天的心情。
class HomeWidgetSetMoodAction extends HomeWidgetAction {
  const HomeWidgetSetMoodAction({required this.day, required this.mood});

  final DateTime day;
  final DayMood? mood;
}

/// 完成一条待办的这一次（[occurrence] 为小组件上显示的截止日）。
class HomeWidgetCompleteTodoAction extends HomeWidgetAction {
  const HomeWidgetCompleteTodoAction({required this.todoId, this.occurrence});

  final String todoId;
  final String? occurrence;
}

/// 把刚完成的待办恢复为未完成（与待办列表里取消勾选同一口径）。
class HomeWidgetReopenTodoAction extends HomeWidgetAction {
  const HomeWidgetReopenTodoAction({required this.todoId});

  final String todoId;
}

/// 按动作写库；返回是否写了库。
Future<bool> applyHomeWidgetAction(
  AppDatabase database,
  HomeWidgetAction action,
) async {
  switch (action) {
    case HomeWidgetSetMoodAction(:final day, :final mood):
      if (mood == null) {
        return await database.clearDayMood(day) != null;
      }
      await database.setDayMood(day, mood);
      return true;
    case HomeWidgetCompleteTodoAction(:final todoId, :final occurrence):
      final row = await database.getTodo(todoId);
      if (row == null || row.completedAt != null) return false;
      // 只完成小组件上显示的那一次：另一台设备或应用里已经完成、重复待办已经
      // 推到下一次时不再重复完成（与通知上的“完成”同一口径）。
      if (row.dueDate != occurrence) return false;
      return await database.completeTodo(todoId) != null;
    case HomeWidgetReopenTodoAction(:final todoId):
      final row = await database.getTodo(todoId);
      if (row == null || row.completedAt == null) return false;
      await database.uncompleteTodo(todoId);
      return true;
  }
}
