// 点桌面小组件后打开哪个页面（由首页在收到 `homeWidgetLaunchRequestProvider`
// 时调用）。
//
// 每个目标只走应用里的统一入口（AGENTS.md §6）：写日记 `runDiaryCreateEntryFlow`、
// 新待办 `showTodoQuickAddSheet`、日历切 Tab 后经 `calendarFocusRequestProvider`
// 选中那天、搜索 `DiarySearchPage.buildRoute`、纪念日 `openAnniversaryList` /
// `openAnniversaryDetail`、重新配置打开小组件工作室。
//
// 链接来自桌面，可能早于功能开关或日记本的变化：每一步都按当前状态再判断
// 一次——功能已关闭、日记本已不能写时降级为只打开首页或不指定日记本，绝不
// 因为桌面上留着旧链接而绕过功能开关或私密规则。应用锁的遮罩盖在导航
// 之上，打开的页面同样要先解锁。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/home_widgets/home_widget_launch.dart';
import '../../anniversaries/controllers/anniversary_navigation.dart';
import '../../calendar/providers/calendar_focus_request_provider.dart';
import '../../diaries/controllers/diary_create_entry_flow.dart';
import '../../diaries/pages/diary_search_page.dart';
import '../../home/models/home_tab.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../todos/widgets/todo_quick_add_sheet.dart';
import '../pages/home_widget_studio_page.dart';
import '../pages/home_widgets_page.dart';
import '../providers/home_widget_providers.dart';

/// 切到首页的某个 Tab；该 Tab 因功能关闭不可见时返回 false。
typedef HomeTabSwitcher = Future<bool> Function(HomeTab tab);

Future<void> openHomeWidgetLaunch(
  BuildContext context,
  WidgetRef ref,
  HomeWidgetLaunch launch, {
  required HomeTabSwitcher switchToTab,
}) async {
  final features = ref.read(appFeaturesProvider);
  switch (launch) {
    case HomeWidgetOpenAppLaunch():
      return;
    case HomeWidgetWriteLaunch(:final notebookId):
      await runDiaryCreateEntryFlow(
        context,
        ref,
        notebookId: features.notebooks
            ? _writableNotebook(ref, notebookId)
            : null,
      );
    case HomeWidgetNewTodoLaunch():
      if (!features.todos) return;
      await showTodoQuickAddSheet(context);
    case HomeWidgetCalendarLaunch(:final day):
      if (!features.calendar) return;
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      if (!await switchToTab(HomeTab.calendar)) return;
      ref
          .read(calendarFocusRequestProvider.notifier)
          .request(day ?? DateTime.now());
    case HomeWidgetSearchLaunch():
      await Navigator.of(context).push(DiarySearchPage.buildRoute());
    case HomeWidgetAnniversaryLaunch(:final anniversaryId):
      if (!features.anniversariesEnabled) return;
      // 纪念日已被删除时详情页自己显示“已删除”，不必在这里先查。
      if (anniversaryId == null) {
        await openAnniversaryList(context);
      } else {
        await openAnniversaryDetail(context, anniversaryId: anniversaryId);
      }
    case HomeWidgetConfigureLaunch(:final widgetId, :final kind):
      final settings = await ref.read(settingsServiceProvider.future);
      if (!context.mounted) return;
      final resolved =
          kind ??
          ref.read(homeWidgetSettingsProvider).instances[widgetId]?.kind;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          // 种类认不出（旧版本留下的链接）时打开小组件页，用户在列表里选。
          builder: (_) => resolved == null
              ? HomeWidgetsPage(settingsService: settings)
              : HomeWidgetStudioPage(
                  settingsService: settings,
                  kind: resolved,
                  widgetId: widgetId,
                ),
        ),
      );
  }
}

/// 只认现在仍能写进去的普通日记本：已删除、合上、变成私密（含继承）或
/// 变成智能日记本时按不指定处理。
String? _writableNotebook(WidgetRef ref, String? notebookId) {
  if (notebookId == null) return null;
  final notebook = ref.read(notebookTreeProvider)?[notebookId];
  if (notebook == null ||
      !notebook.isManual ||
      notebook.isPrivate ||
      notebook.isClosed) {
    return null;
  }
  return notebookId;
}
