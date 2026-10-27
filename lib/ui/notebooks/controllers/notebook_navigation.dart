import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/providers/home_tab_request_provider.dart';
import '../providers/home_notebook_scope_provider.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_lock_flow.dart';

/// 从首页之上的页面（预览页的日记本胶囊）打开一本日记本：回到首页、切到
/// “日记”Tab，并把日记页的范围换成这本。
///
/// 顺序：
/// 1. 上锁的先验证（[authorizeNotebookEntry]），未通过停留原处；
/// 2. 先取好范围与 Tab 的 notifier——关掉上层页面后调用方（预览页）的 ref
///    已不能再用；
/// 3. 关掉首页之上的所有页面，切换范围并请求日记 Tab。日记页把这次范围
///    变化视为外部切换，自行播放过渡并退出多选（见
///    `DiariesNotebookScopeController.handleScopeIdChanged`）。
///
/// 已在这本里时只回到首页的日记 Tab。
Future<void> openNotebookFromAnywhere(
  BuildContext context,
  WidgetRef ref,
  NotebookView notebook,
) async {
  // 调用方的视图可能是单独由一行构造的（预览页胶囊），不知道上级是否上锁：
  // 以书架列表里带层级信息的那一份为准。
  final resolved = ref.read(notebookTreeProvider)?[notebook.id] ?? notebook;
  final allowed = await authorizeNotebookEntry(context, ref, resolved);
  if (!allowed || !context.mounted) {
    return;
  }
  final scope = ref.read(homeNotebookScopeProvider.notifier);
  final tabs = ref.read(homeDiariesTabRequestProvider.notifier);
  Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  scope.enter(notebook.id);
  tabs.request();
}
