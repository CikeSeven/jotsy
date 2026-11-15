// 点桌面小组件打开应用时带的链接：`jotsy://widget/<目标>?参数`。
//
// 链接由原生拼好（`WidgetLaunch.kt`），这里只负责解析成 [HomeWidgetLaunch]；
// 打开哪个页面由首页的 `HomeWidgetLaunchRouter` 按功能开关与隐私规则决定
// （坏链接、私密日记、功能已关闭时只打开首页）。两端的目标名一一对应，
// 改动须同步。

import 'home_widget_kind.dart';

const String kHomeWidgetLaunchScheme = 'jotsy';
const String kHomeWidgetLaunchHost = 'widget';

sealed class HomeWidgetLaunch {
  const HomeWidgetLaunch();

  /// 解析链接；不是小组件链接返回 null，认不出的目标按“打开应用”处理。
  static HomeWidgetLaunch? parse(Uri? uri) {
    if (uri == null ||
        uri.scheme != kHomeWidgetLaunchScheme ||
        uri.host != kHomeWidgetLaunchHost) {
      return null;
    }
    final segments = uri.pathSegments;
    final target = segments.isEmpty ? '' : segments.first;
    final query = uri.queryParameters;
    switch (target) {
      case 'write':
        final notebook = query['notebook'];
        return HomeWidgetWriteLaunch(
          notebookId: notebook == null || notebook.isEmpty ? null : notebook,
        );
      case 'todo-new':
        final list = query['list'];
        return HomeWidgetNewTodoLaunch(
          listId: list == null || list.isEmpty ? null : list,
        );
      case 'todo':
        final id = query['id'];
        return id == null || id.isEmpty
            ? const HomeWidgetOpenAppLaunch()
            : HomeWidgetTodoLaunch(todoId: id);
      case 'calendar':
        return HomeWidgetCalendarLaunch(day: _parseDay(query['day']));
      case 'search':
        return const HomeWidgetSearchLaunch();
      case 'anniversary':
        final id = query['id'];
        return HomeWidgetAnniversaryLaunch(
          anniversaryId: id == null || id.isEmpty ? null : id,
        );
      case 'configure':
        final id = int.tryParse(query['id'] ?? '');
        return id == null
            ? const HomeWidgetOpenAppLaunch()
            : HomeWidgetConfigureLaunch(
                widgetId: id,
                kind: HomeWidgetKind.byId(query['kind']),
              );
      default:
        return const HomeWidgetOpenAppLaunch();
    }
  }

  static DateTime? _parseDay(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    // 拒绝 2026-02-31 这类会被 DateTime 自动进位的日期。
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}

/// 只打开应用（回到首页）。
class HomeWidgetOpenAppLaunch extends HomeWidgetLaunch {
  const HomeWidgetOpenAppLaunch();
}

/// 写日记；[notebookId] 为要写进的普通日记本。
class HomeWidgetWriteLaunch extends HomeWidgetLaunch {
  const HomeWidgetWriteLaunch({this.notebookId});

  final String? notebookId;
}

/// 新建待办；[listId] 为预先选好的清单。
class HomeWidgetNewTodoLaunch extends HomeWidgetLaunch {
  const HomeWidgetNewTodoLaunch({this.listId});

  final String? listId;
}

/// 打开一条待办的详情。
class HomeWidgetTodoLaunch extends HomeWidgetLaunch {
  const HomeWidgetTodoLaunch({required this.todoId});

  final String todoId;
}

/// 打开日历，选中 [day]（null 为今天）。
class HomeWidgetCalendarLaunch extends HomeWidgetLaunch {
  const HomeWidgetCalendarLaunch({this.day});

  final DateTime? day;
}

/// 打开搜索。
class HomeWidgetSearchLaunch extends HomeWidgetLaunch {
  const HomeWidgetSearchLaunch();
}

/// 打开纪念日：给了 [anniversaryId] 打开它的详情，否则打开纪念日列表。
class HomeWidgetAnniversaryLaunch extends HomeWidgetLaunch {
  const HomeWidgetAnniversaryLaunch({this.anniversaryId});

  final String? anniversaryId;
}

/// 长按小组件“重新配置”：打开这个实例的小组件工作室。
class HomeWidgetConfigureLaunch extends HomeWidgetLaunch {
  const HomeWidgetConfigureLaunch({required this.widgetId, this.kind});

  final int widgetId;

  /// 原生知道的种类；认不出时为 null，由设置里的记录补上。
  final HomeWidgetKind? kind;
}
