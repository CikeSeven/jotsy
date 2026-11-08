import 'package:flutter/material.dart';

import '../pages/todo_lists_page.dart';
import '../pages/todo_search_page.dart';
import '../pages/todo_settings_page.dart';
import '../sections/todo_detail_sheet.dart';

/// 待办相关页面的统一导航入口（待办页、日历、日记预览页、通知点开共用）；
/// 禁止另拼路由。

/// 打开一条待办的详情：可拖动的底部面板（日历、日记、搜索、通知点开与窄
/// 窗口的待办页）。宽窗口待办页的三栏布局由页面自己放进右侧详情栏。
Future<void> openTodoDetail(BuildContext context, String todoId) =>
    showTodoDetailSheet(context, todoId);

/// 打开待办搜索页。
Future<void> openTodoSearch(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const TodoSearchPage(),
    ),
  );
}

/// 打开清单管理页（改名、颜色、图标、拖动排序、删除）。
Future<void> openTodoListsManage(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const TodoListsPage(),
    ),
  );
}

/// 打开待办设置页（设置 → 待办）。
Future<void> openTodoSettings(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const TodoSettingsPage(),
    ),
  );
}
