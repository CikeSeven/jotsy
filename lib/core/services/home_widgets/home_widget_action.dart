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
  }
}
