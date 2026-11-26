import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../providers/todo_providers.dart';
import '../sections/todo_list_callbacks.dart';
import 'todo_actions.dart';
import 'todo_batch_actions.dart';
import 'todo_completion_queue.dart';
import 'todo_page_selection.dart';
import 'todo_reorder.dart';

/// 待办页列表行的交互交给哪里（页面持有的状态经参数传入）。
///
/// - 点行：多选时切换选中；桌面按住 Ctrl / ⌘ 点按进入多选；否则打开详情
///   （[openDetail]：宽窗口放进详情栏，窄窗口弹底部面板）；
/// - 长按：进入或切换多选。iOS 补一次中等触觉；Android 由 InkWell 的长按
///   反馈负责，避免震两次；
/// - 点方框：未完成的先收起再写库（[TodoCompletionQueue]），已完成的直接
///   恢复；右滑与右键菜单的完成 / 恢复直接写库（行已滑出，或桌面不演收起）；
/// - 删除、移到今天、移到清单与逾期组“全部改到今天”各自弹可撤销提示；
/// - 拖动排序交给 [TodoReorder]。
TodoListCallbacks buildTodoPageCallbacks({
  required BuildContext context,
  required WidgetRef ref,
  required TodoPageSelection selection,
  required TodoCompletionQueue queue,
  required TodoReorder reorder,
  required ValueChanged<TodoRow> openDetail,
}) {
  AppDatabase database() => ref.read(appDatabaseProvider);
  DateTime today() => ref.read(todoTodayProvider);

  void onTap(TodoRow row) {
    if (selection.active) {
      selection.toggle(row.todoId);
      return;
    }
    final keys = HardwareKeyboard.instance;
    if (AppPlatform.isDesktop &&
        (keys.isControlPressed || keys.isMetaPressed)) {
      selection.enter(row.todoId);
      return;
    }
    openDetail(row);
  }

  void onLongPress(TodoRow row) {
    if (selection.active) {
      selection.toggle(row.todoId);
      return;
    }
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      unawaited(HapticFeedback.mediumImpact());
    }
    selection.enter(row.todoId);
  }

  return TodoListCallbacks(
    onToggle: (TodoRow row) => row.completedAt != null
        ? unawaited(toggleTodoDone(context, database(), row))
        : queue.start(context, database(), row),
    onSwipeToggle: (TodoRow row) =>
        unawaited(toggleTodoDone(context, database(), row)),
    onTap: onTap,
    onLongPress: onLongPress,
    onDelete: (TodoRow row) =>
        unawaited(deleteTodoWithUndo(context, database(), row.todoId)),
    onMoveToToday: (TodoRow row) =>
        unawaited(todoMoveRowsToDay(context, ref, <TodoRow>[row], today())),
    onMoveToList: (TodoRow row) =>
        unawaited(todoMoveRowsToList(context, ref, <TodoRow>[row])),
    onMoveOverdueToToday: (List<TodoRow> rows) =>
        unawaited(todoMoveRowsToDay(context, ref, rows, today())),
    onReorder: (List<TodoRow> rows, int oldIndex, int newIndex) => reorder.drop(
      database(),
      rows,
      oldIndex,
      newIndex,
      readOpen: () => ref.read(openTodosProvider).value,
    ),
    onReorderStart: reorder.start,
    onReorderEnd: reorder.dropped,
  );
}
