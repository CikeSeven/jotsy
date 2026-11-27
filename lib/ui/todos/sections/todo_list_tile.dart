import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../diaries/widgets/diary_swipe_action_item.dart';
import '../models/todo_settings.dart';
import '../widgets/todo_row_drag.dart';
import '../widgets/todo_tile.dart';
import '../widgets/todo_tile_context_menu.dart';
import 'todo_list_callbacks.dart';

/// 待办页列表里的一行：[TodoTile] 加上按平台的交互外壳。
///
/// - 手机：右滑完成 / 恢复；左滑按设置删除（滑出收起）或改期（弹截止日面板，
///   这一行弹回原位，改了日期后由列表动效滑到新的组）；
/// - 桌面：右键菜单；按住拖动可把这一行（多选时是全部选中的）拖到左栏的
///   今天、收集箱或清单上（[TodoRowDraggable]）；
/// - 读屏：整行挂着完成 / 恢复、改期、删除三个动作，与滑动和右键菜单等价。
///
/// 多选时不挂滑动、右键与读屏动作（点行只切换选中），桌面仍可拖动选中的。
class TodoListTile extends StatelessWidget {
  const TodoListTile({
    super.key,
    required this.row,
    required this.callbacks,
    required this.state,
    required this.today,
    required this.list,
    this.trailing,
  });

  final TodoRow row;
  final TodoListCallbacks callbacks;
  final TodoListRowState state;
  final DateTime today;

  /// 行上显示的所在清单（跨清单的视图里）。
  final TodoListRow? list;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final done = row.completedAt != null;
    final selecting = state.selectionMode;
    final selected = selecting
        ? state.selected.contains(row.todoId)
        : state.highlightedId == row.todoId;
    Widget child = TodoTile(
      row: row,
      today: today,
      list: list,
      trailing: trailing,
      selectionMode: selecting,
      selected: selected,
      onToggle: () => callbacks.onToggle(row),
      onTap: () => callbacks.onTap(row),
      onLongPress: () => callbacks.onLongPress(row),
      stepsExpanded: state.expandedSteps.contains(row.todoId),
      onToggleSteps: () => callbacks.onToggleSteps(row),
      onToggleStep: (TodoStep step) => callbacks.onToggleStep(row, step),
      semanticActions: <CustomSemanticsAction, VoidCallback>{
        CustomSemanticsAction(
          label: done ? l10n.todoMarkUndone : l10n.todoMarkDone,
        ): () =>
            callbacks.onSwipeToggle(row),
        CustomSemanticsAction(label: l10n.todoReschedule): () =>
            callbacks.onReschedule(row),
        CustomSemanticsAction(label: l10n.commonDelete): () =>
            callbacks.onDelete(row),
      },
    );
    if (AppPlatform.isDesktop) {
      final dragged = selecting && state.selected.contains(row.todoId)
          ? state.selected.toList()
          : <String>[row.todoId];
      if (!selecting) {
        child = TodoTileContextMenu(
          done: done,
          onToggle: () => callbacks.onSwipeToggle(row),
          onMoveToToday: () => callbacks.onMoveToToday(row),
          onMoveToList: () => callbacks.onMoveToList(row),
          onDelete: () => callbacks.onDelete(row),
          child: child,
        );
      }
      if (selecting && !dragged.contains(row.todoId)) return child;
      return TodoRowDraggable(
        payload: TodoDragPayload(ids: dragged, title: row.title),
        child: child,
      );
    }
    final reschedule = state.swipeLeft == TodoSwipeAction.reschedule;
    // 按 updated_at 换 key：滑出后组件一直保持收起，重复待办右滑完成后
    // 推到下一次、仍留在原位（清单 / 全部视图）时要换一个新的，不然这一行
    // 一直是 0 高。
    return DiarySwipeActionItem(
      key: ValueKey<DateTime>(row.updatedAt),
      diaryId: row.todoId,
      enabled: !selecting,
      icon: reschedule
          ? FontAwesomeIcons.calendarDay
          : FontAwesomeIcons.trashCan,
      actionColor: reschedule
          ? scheme.tertiaryContainer
          : scheme.errorContainer,
      actionIconColor: reschedule
          ? scheme.onTertiaryContainer
          : scheme.onErrorContainer,
      borderRadius: AppRadii.input,
      collapseOnSwipe: !reschedule,
      onSwiped: () =>
          reschedule ? callbacks.onReschedule(row) : callbacks.onDelete(row),
      startAction: SwipeActionSpec(
        icon: done ? FontAwesomeIcons.rotateLeft : FontAwesomeIcons.check,
        actionColor: done ? scheme.secondaryContainer : scheme.primaryContainer,
        actionIconColor: done
            ? scheme.onSecondaryContainer
            : scheme.onPrimaryContainer,
        onSwiped: () => callbacks.onSwipeToggle(row),
      ),
      child: child,
    );
  }
}
