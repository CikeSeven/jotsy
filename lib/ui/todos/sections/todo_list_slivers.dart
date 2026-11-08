import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../diaries/widgets/diary_swipe_action_item.dart';
import '../../widgets/expressive_reorder_proxy.dart';
import '../../widgets/list_item_presence.dart';
import '../../widgets/reorder_handle.dart';
import '../viewmodels/todo_groups.dart';
import '../widgets/todo_group_header.dart';
import '../widgets/todo_tile.dart';
import '../widgets/todo_tile_context_menu.dart';

/// 待办列表的回调（页面持有写库、导航与多选）。
class TodoListCallbacks {
  const TodoListCallbacks({
    required this.onToggle,
    required this.onSwipeToggle,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onMoveToToday,
    required this.onMoveToList,
    required this.onMoveOverdueToToday,
    required this.onReorder,
    required this.onReorderStart,
    required this.onReorderEnd,
  });

  /// 点方框勾选 / 取消（行内动效已播完）。
  final ValueChanged<TodoRow> onToggle;

  /// 右滑完成 / 恢复（行已滑出并收起，直接写库）。
  final ValueChanged<TodoRow> onSwipeToggle;
  final ValueChanged<TodoRow> onTap;
  final ValueChanged<TodoRow> onLongPress;
  final ValueChanged<TodoRow> onDelete;
  final ValueChanged<TodoRow> onMoveToToday;
  final ValueChanged<TodoRow> onMoveToList;
  final ValueChanged<List<TodoRow>> onMoveOverdueToToday;

  /// 一组里把第 [oldIndex] 条拖到 [newIndex]（已修正的插入位置）。
  final void Function(List<TodoRow> rows, int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onReorderStart;
  final ValueChanged<int> onReorderEnd;
}

/// 列表行的临时状态（页面持有）：多选、正在收起、刚出现、详情栏正在看的。
class TodoListRowState {
  const TodoListRowState({
    this.selectionMode = false,
    this.selected = const <String>{},
    this.leaving = const <String>{},
    this.appearing = const <String>{},
    this.highlightedId,
  });

  final bool selectionMode;
  final Set<String> selected;

  /// 勾选后正在收起、还没写库的行。
  final Set<String> leaving;

  /// 页面打开之后才出现的行（新建、同步来的）：从 0 展开进场。
  final Set<String> appearing;

  /// 宽窗口详情栏正在看的那一条（高亮）。
  final String? highlightedId;
}

/// 把各组待办排成 sliver：每组一个标题（没有标题的组不画）+ 各行；
/// [inlineAdd] 插在最后一组未完成的之后、已完成的组之前。
///
/// - [reorderable] 为 true 时（收集箱或清单、手动排序，且不在多选），未完成
///   的那一组是可拖动排序的列表（手柄按住即拖，拿起时给一次触觉）；
/// - 已完成的组（清单底部 / 今天已完成）可折叠（[collapsed] 里是折叠的组键）；
/// - 每行套 [ListItemPresence]：勾选后先收起再由页面写库，新出现的行展开进场；
/// - 手机上右滑完成 / 恢复、左滑删除（[DiarySwipeActionItem]，松手越过阈值才
///   生效，多选时关闭）；桌面不提供滑动，改为右键菜单。
List<Widget> buildTodoListSlivers({
  required List<TodoGroup> groups,
  required Map<String, TodoListRow> listsById,
  required bool showListOnRows,
  required bool reorderable,
  required DateTime today,
  required Set<String> collapsed,
  required ValueChanged<String> onToggleCollapsed,
  required TodoListCallbacks callbacks,
  required TodoListRowState state,
  required double horizontalPadding,
  required ColorScheme scheme,
  Widget? inlineAdd,
}) {
  final slivers = <Widget>[];
  final desktop = AppPlatform.isDesktop;
  final padding = EdgeInsets.symmetric(horizontal: horizontalPadding);

  Widget tile(BuildContext context, TodoRow row, {Widget? trailing}) {
    final listId = row.listId;
    final done = row.completedAt != null;
    final selected = state.selectionMode
        ? state.selected.contains(row.todoId)
        : state.highlightedId == row.todoId;
    Widget child = TodoTile(
      row: row,
      today: today,
      list: showListOnRows && listId != null ? listsById[listId] : null,
      trailing: trailing,
      selectionMode: state.selectionMode,
      selected: selected,
      onToggle: () => callbacks.onToggle(row),
      onTap: () => callbacks.onTap(row),
      onLongPress: () => callbacks.onLongPress(row),
    );
    if (desktop) {
      if (state.selectionMode) return child;
      return TodoTileContextMenu(
        done: done,
        onToggle: () => callbacks.onSwipeToggle(row),
        onMoveToToday: () => callbacks.onMoveToToday(row),
        onMoveToList: () => callbacks.onMoveToList(row),
        onDelete: () => callbacks.onDelete(row),
        child: child,
      );
    }
    // 按 updated_at 换 key：滑出后组件一直保持收起，重复待办右滑完成后
    // 推到下一次、仍留在原位（清单 / 全部视图）时要换一个新的，不然这一行
    // 一直是 0 高。
    child = DiarySwipeActionItem(
      key: ValueKey<DateTime>(row.updatedAt),
      diaryId: row.todoId,
      enabled: !state.selectionMode,
      icon: FontAwesomeIcons.trashCan,
      actionColor: scheme.errorContainer,
      actionIconColor: scheme.onErrorContainer,
      borderRadius: AppRadii.input,
      onSwiped: () => callbacks.onDelete(row),
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
    return child;
  }

  Widget item(BuildContext context, TodoRow row, {Widget? trailing}) {
    final id = row.todoId;
    return ListItemPresence(
      key: ValueKey<String>('todo_$id'),
      visible: !state.leaving.contains(id),
      appearing: state.appearing.contains(id),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      glass: AppGlass.of(context).isGlass(AppGlassComponent.cards),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s),
        child: tile(context, row, trailing: trailing),
      ),
    );
  }

  final lastOpen = groups.lastIndexWhere((group) => !_isDoneGroup(group.kind));
  var inlineAdded = false;
  void addInline() {
    final add = inlineAdd;
    if (add == null || inlineAdded) return;
    inlineAdded = true;
    slivers.add(
      SliverPadding(
        padding: padding.copyWith(top: AppSpacing.xs),
        sliver: SliverToBoxAdapter(child: add),
      ),
    );
  }

  if (lastOpen < 0) addInline();
  for (var g = 0; g < groups.length; g++) {
    final group = groups[g];
    final collapsible =
        group.kind == TodoGroupKind.completed ||
        group.kind == TodoGroupKind.completedToday;
    final isCollapsed = collapsible && collapsed.contains(group.key);
    if (group.kind != TodoGroupKind.plain) {
      slivers.add(
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: TodoGroupHeader(
              key: ValueKey<String>('header_${group.key}'),
              group: group,
              today: today,
              list: group.kind == TodoGroupKind.list && group.listId != null
                  ? listsById[group.listId]
                  : null,
              collapsed: isCollapsed,
              onToggleCollapsed: collapsible
                  ? () => onToggleCollapsed(group.key)
                  : null,
              onMoveOverdueToToday:
                  group.kind == TodoGroupKind.overdue && !state.selectionMode
                  ? () => callbacks.onMoveOverdueToToday(group.rows)
                  : null,
            ),
          ),
        ),
      );
    } else {
      slivers.add(
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s)),
      );
    }
    if (!isCollapsed) {
      final rows = group.rows;
      if (reorderable &&
          !state.selectionMode &&
          group.kind == TodoGroupKind.plain) {
        slivers.add(
          SliverPadding(
            padding: padding,
            sliver: SliverReorderableList(
              itemCount: rows.length,
              proxyDecorator: cardRowReorderProxyDecorator,
              onReorderStart: (int index) {
                callbacks.onReorderStart(index);
                unawaited(HapticFeedback.mediumImpact());
              },
              onReorderEnd: callbacks.onReorderEnd,
              onReorderItem: (int oldIndex, int newIndex) =>
                  callbacks.onReorder(rows, oldIndex, newIndex),
              itemBuilder: (BuildContext context, int index) => item(
                context,
                rows[index],
                trailing: ReorderHandle(index: index),
              ),
            ),
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: padding,
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (BuildContext context, int index) =>
                  item(context, rows[index]),
            ),
          ),
        );
      }
    }
    if (g == lastOpen) addInline();
  }
  addInline();
  return slivers;
}

/// 已完成的组（可折叠、排在内联新建之后）。
bool _isDoneGroup(TodoGroupKind kind) =>
    kind == TodoGroupKind.completed ||
    kind == TodoGroupKind.completedToday ||
    kind == TodoGroupKind.completedDay;
