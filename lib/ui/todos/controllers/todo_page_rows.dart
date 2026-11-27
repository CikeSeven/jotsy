import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../sections/todo_list_callbacks.dart';
import '../widgets/todo_due_sheet.dart';
import '../widgets/todo_row_drag.dart';
import 'todo_actions.dart';
import 'todo_batch_actions.dart';
import 'todo_completion_queue.dart';
import 'todo_completion_undo.dart';
import 'todo_page_selection.dart';
import 'todo_reorder.dart';

/// 待办页列表行的交互交给哪里（页面持有的状态经参数传入）。
///
/// - 点行：多选时切换选中；桌面按住 Ctrl / ⌘ 点按进入多选、按住 Shift 点按
///   从上一次点选的一行连选到这一行（[visibleRows] 的顺序）；否则打开详情
///   （[openDetail]：宽窗口放进详情栏，窄窗口弹底部面板）；
/// - 长按：进入或切换多选。iOS 补一次中等触觉；Android 由 InkWell 的长按
///   反馈负责，避免震两次；
/// - 点方框：未完成的先收起再写库（[TodoCompletionQueue]），已完成的直接
///   恢复；右滑、右键菜单与读屏的完成 / 恢复直接写库（行已滑出，或桌面不
///   演收起）。接连完成的几条合并成一条撤销提示（[undo]）；
/// - 删除、移到清单与逾期组“全部改到今天”各自弹可撤销提示；
/// - 改期（左滑设为改期、右键菜单、读屏动作）：改期面板，选了就写库并可
///   撤销；
/// - 步骤胶囊：就地展开 / 收起（[onToggleSteps]，页面持有展开的行），展开
///   后勾选某一步直接写库；
/// - 拖动排序交给 [TodoReorder]。
TodoListCallbacks buildTodoPageCallbacks({
  required BuildContext context,
  required WidgetRef ref,
  required TodoPageSelection selection,
  required TodoCompletionQueue queue,
  required TodoReorder reorder,
  required TodoCompletionUndo undo,
  required ValueChanged<TodoRow> openDetail,
  required ValueChanged<TodoRow> onToggleSteps,
  required List<TodoRow> Function() visibleRows,
}) {
  AppDatabase database() => ref.read(appDatabaseProvider);
  DateTime today() => ref.read(todoTodayProvider);

  void onTap(TodoRow row) {
    if (selection.active) {
      if (AppPlatform.isDesktop && HardwareKeyboard.instance.isShiftPressed) {
        selection.extendTo(row.todoId, visibleRows());
      } else {
        selection.toggle(row.todoId);
      }
      return;
    }
    final keys = HardwareKeyboard.instance;
    if (AppPlatform.isDesktop && keys.isShiftPressed) {
      selection.extendTo(row.todoId, visibleRows());
      return;
    }
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
        unawaited(toggleTodoDone(context, database(), row, undo: undo)),
    onTap: onTap,
    onLongPress: onLongPress,
    onDelete: (TodoRow row) =>
        unawaited(deleteTodoWithUndo(context, database(), row.todoId)),
    onMoveToList: (TodoRow row) =>
        unawaited(todoMoveRowsToList(context, ref, <TodoRow>[row])),
    onMoveOverdueToToday: (List<TodoRow> rows) =>
        unawaited(todoMoveRowsToDay(context, ref, rows, today())),
    onReschedule: (TodoRow row) => unawaited(_reschedule(context, ref, row)),
    onToggleSteps: onToggleSteps,
    onToggleStep: (TodoRow row, TodoStep step) =>
        unawaited(database().setTodoStepDone(row.todoId, step.id, !step.done)),
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

/// 改期一条：截止日面板（带着原来的日期与时刻），选了就写库并可撤销。
Future<void> _reschedule(
  BuildContext context,
  WidgetRef ref,
  TodoRow row,
) async {
  final due = row.dueDate;
  final choice = await showTodoDueSheet(
    context,
    date: due == null ? null : parseAnniversaryDate(due),
    minute: row.dueMinute,
    today: ref.read(todoTodayProvider),
  );
  if (choice == null || !context.mounted) return;
  await setTodosDueWithUndo(
    context,
    ref.read(appDatabaseProvider),
    <TodoRow>[row],
    date: choice.date,
    minute: choice.minute,
  );
}

/// 桌面上把待办拖到左栏的 [target] 上：今天改到今天，收集箱与清单移进去，
/// 各自弹可撤销提示；其余视图不接（见 [TodoView.acceptsDrop]）。拖的是多选里的
/// 几条时先退出多选。
Future<void> dropTodosOnView(
  BuildContext context,
  WidgetRef ref, {
  required TodoView target,
  required TodoDragPayload payload,
  required TodoPageSelection selection,
}) async {
  final ids = payload.ids.toSet();
  final rows = <TodoRow>[
    for (final row in ref.read(openTodosProvider).value ?? const <TodoRow>[])
      if (ids.contains(row.todoId)) row,
  ];
  if (rows.isEmpty) return;
  selection.clear();
  final database = ref.read(appDatabaseProvider);
  if (target.smart == TodoSmartView.today) {
    await todoMoveRowsToDay(context, ref, rows, ref.read(todoTodayProvider));
    return;
  }
  final listId = target.listId;
  if (listId == null && target.smart != TodoSmartView.inbox) return;
  var name = context.l10n.todoViewInbox;
  if (listId != null) {
    final list = await database.getTodoList(listId);
    if (list == null || !context.mounted) return;
    name = list.name;
  }
  await moveTodosToListWithUndo(
    context,
    database,
    rows.map((TodoRow row) => row.todoId),
    listId: listId,
    listName: name,
  );
}

/// 桌面上把待办拖到计划视图周条的某一天 [day] 上：改到那天（各自保留时刻），
/// 可撤销。
Future<void> dropTodosOnDay(
  BuildContext context,
  WidgetRef ref, {
  required DateTime day,
  required TodoDragPayload payload,
}) async {
  final ids = payload.ids.toSet();
  final rows = <TodoRow>[
    for (final row in ref.read(openTodosProvider).value ?? const <TodoRow>[])
      if (ids.contains(row.todoId)) row,
  ];
  if (rows.isEmpty) return;
  await todoMoveRowsToDay(context, ref, rows, day);
}
