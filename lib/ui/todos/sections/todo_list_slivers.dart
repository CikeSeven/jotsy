import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../diaries/widgets/diary_swipe_action_item.dart';
import '../../widgets/expressive_reorder_proxy.dart';
import '../../widgets/reorder_handle.dart';
import '../viewmodels/todo_groups.dart';
import '../widgets/todo_group_header.dart';
import '../widgets/todo_tile.dart';

/// 待办列表的回调（页面持有写库与导航）。
class TodoListCallbacks {
  const TodoListCallbacks({
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
    required this.onReorder,
    required this.onReorderStart,
    required this.onReorderEnd,
  });

  final ValueChanged<TodoRow> onToggle;
  final ValueChanged<TodoRow> onOpen;
  final ValueChanged<TodoRow> onDelete;

  /// 一组里把第 [oldIndex] 条拖到 [newIndex]（已修正的插入位置）。
  final void Function(List<TodoRow> rows, int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onReorderStart;
  final ValueChanged<int> onReorderEnd;
}

/// 把各组待办排成 sliver：每组一个标题（没有标题的组不画）+ 各行。
///
/// - [reorderable] 为 true 时（收集箱或清单、手动排序），未完成的那一组是
///   可拖动排序的列表（手柄按住即拖，拿起时给一次触觉），其余组照常；
/// - 清单底部的“已完成”可折叠（[collapsed] 里是折叠的组键）；
/// - 手机上左滑删除（[DiarySwipeActionItem]，松手越过阈值才生效），桌面不
///   提供滑动，删除在详情页里。
List<Widget> buildTodoListSlivers({
  required List<TodoGroup> groups,
  required Map<String, TodoListRow> listsById,
  required bool showListOnRows,
  required bool reorderable,
  required DateTime today,
  required Set<String> collapsed,
  required ValueChanged<String> onToggleCollapsed,
  required TodoListCallbacks callbacks,
  required double horizontalPadding,
  required ColorScheme scheme,
}) {
  final slivers = <Widget>[];
  final swipe = !AppPlatform.isDesktop;

  Widget tile(TodoRow row, {Widget? trailing}) {
    final listId = row.listId;
    final child = TodoTile(
      row: row,
      today: today,
      list: showListOnRows && listId != null ? listsById[listId] : null,
      trailing: trailing,
      onToggle: () => callbacks.onToggle(row),
      onTap: () => callbacks.onOpen(row),
    );
    if (!swipe) return child;
    return DiarySwipeActionItem(
      diaryId: row.todoId,
      enabled: true,
      icon: FontAwesomeIcons.trashCan,
      actionColor: scheme.errorContainer,
      actionIconColor: scheme.onErrorContainer,
      borderRadius: AppRadii.input,
      onSwiped: () => callbacks.onDelete(row),
      child: child,
    );
  }

  for (final group in groups) {
    final padding = EdgeInsets.symmetric(horizontal: horizontalPadding);
    final collapsible = group.kind == TodoGroupKind.completed;
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
            ),
          ),
        ),
      );
    } else {
      slivers.add(
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s)),
      );
    }
    if (isCollapsed) continue;
    final rows = group.rows;
    if (reorderable && group.kind == TodoGroupKind.plain) {
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
            itemBuilder: (BuildContext context, int index) => Padding(
              key: ValueKey<String>('todo_${rows[index].todoId}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: tile(rows[index], trailing: ReorderHandle(index: index)),
            ),
          ),
        ),
      );
      continue;
    }
    slivers.add(
      SliverPadding(
        padding: padding,
        sliver: SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int index) => Padding(
            key: ValueKey<String>('todo_${rows[index].todoId}'),
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: tile(rows[index]),
          ),
        ),
      ),
    );
  }
  return slivers;
}
