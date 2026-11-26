import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../diaries/controllers/diary_list_switch_motion.dart';
import '../../diaries/widgets/diary_list_switch_reveal.dart';
import '../../diaries/widgets/diary_swipe_action_item.dart';
import '../../widgets/list_change_host.dart';
import '../../widgets/list_item_presence.dart';
import '../../widgets/list_make_room.dart';
import '../viewmodels/todo_groups.dart';
import '../viewmodels/todo_list_entries.dart';
import '../widgets/todo_group_header.dart';
import '../widgets/todo_tile.dart';
import '../widgets/todo_tile_context_menu.dart';
import 'todo_list_callbacks.dart';

/// 列表里各项的外壳与内容（标题、间隙、待办行），开放区、已完成区块共用。
///
/// 每一项的结构恒定，动效开始、结束都不改树（行不会因此重新挂载）：
/// KeyedSubtree（按 [TodoListEntry.key]）→ [MakeRoomItem]（数据变化时滑到
/// 新位置）→ [DiaryListSwitchReveal]（切换视图时的退场 / 错峰入场）→
/// [ListItemPresence]（收起 / 展开）→ 内容。
///
/// 让位的标签平时就是键；两种情况换成别的标签、不参与让位：
/// - 勾选后正在收起的行：写库后它出现在已完成组（或推到下一次）时，从收起
///   处展开，而不是从原位置滑过去——用户已经看着它收起了；
/// - 已完成组消失时留下来收起的画面（[ghost]）：同一条可能正滑去未完成里。
class TodoListItems {
  TodoListItems({
    required this.frame,
    required this.callbacks,
    required this.state,
    required this.today,
    required this.listsById,
    required this.showListOnRows,
    required this.switchMotion,
    required this.presenceDuration,
    required this.glassCards,
    required this.scheme,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  final ListChangeFrame<TodoListEntry> frame;
  final TodoListCallbacks callbacks;
  final TodoListRowState state;
  final DateTime today;
  final Map<String, TodoListRow> listsById;

  /// 是否在行上写出所在清单（跨清单的视图）。
  final bool showListOnRows;
  final DiaryListSwitchMotion switchMotion;

  /// 收起 / 展开的时长（已按减少动画解析）。
  final Duration presenceDuration;

  /// 行是否为玻璃卡片（淡入淡出须经玻璃自己显现）。
  final bool glassCards;
  final ColorScheme scheme;

  /// 折叠了的组键。
  final Set<String> collapsed;
  final ValueChanged<String> onToggleCollapsed;

  MakeRoomController get _makeRoom => frame.makeRoom!;

  /// 视图切换的退场 / 入场（[index] 决定错峰槽位）。
  Widget reveal(int index, Widget child, {bool glass = false}) =>
      DiaryListSwitchReveal(
        motion: switchMotion,
        index: index,
        glass: glass,
        child: child,
      );

  Widget _shell({
    required String key,
    required Object tag,
    required int revealIndex,
    required bool glass,
    required bool visible,
    required bool appearing,
    required Widget child,
  }) {
    return KeyedSubtree(
      key: ValueKey<String>(key),
      child: MakeRoomItem(
        tag: tag,
        controller: _makeRoom,
        child: reveal(
          revealIndex,
          glass: glass,
          ListItemPresence(
            visible: visible,
            appearing: appearing,
            duration: presenceDuration,
            glass: glass,
            child: child,
          ),
        ),
      ),
    );
  }

  bool _entering(TodoListEntry entry) => frame.entering.contains(entry.key);
  bool _exiting(TodoListEntry entry) => frame.exiting.contains(entry.key);

  /// 一组的标题（开放区里的组；已完成组见 [doneHeader]）。
  Widget header(TodoHeaderEntry entry, int revealIndex) {
    final exiting = _exiting(entry);
    return _shell(
      key: entry.key,
      tag: entry.key,
      revealIndex: revealIndex,
      glass: false,
      visible: !exiting,
      appearing: !exiting && _entering(entry),
      child: IgnorePointer(
        ignoring: exiting,
        child: _groupHeader(entry.group, interactive: !exiting),
      ),
    );
  }

  /// 已完成组的标题：可点按折叠；[interactive] 为 false 时（这一组正在
  /// 消失）不可点。不参与进出场（整块由已完成区块展开 / 收起）。
  Widget doneHeader(
    TodoGroup group,
    int revealIndex, {
    required bool interactive,
  }) {
    final key = 'h:${group.key}';
    return _shell(
      key: key,
      tag: interactive ? key : 'ghost:$key',
      revealIndex: revealIndex,
      glass: false,
      visible: true,
      appearing: false,
      child: IgnorePointer(
        ignoring: !interactive,
        child: _groupHeader(group, interactive: interactive),
      ),
    );
  }

  Widget _groupHeader(TodoGroup group, {required bool interactive}) {
    final collapsible = isCollapsibleTodoGroup(group.kind);
    return TodoGroupHeader(
      group: group,
      today: today,
      list: group.kind == TodoGroupKind.list && group.listId != null
          ? listsById[group.listId]
          : null,
      collapsed: collapsible && collapsed.contains(group.key),
      onToggleCollapsed: collapsible && interactive
          ? () => onToggleCollapsed(group.key)
          : null,
      onMoveOverdueToToday:
          group.kind == TodoGroupKind.overdue &&
              !state.selectionMode &&
              interactive
          ? () => callbacks.onMoveOverdueToToday(group.rows)
          : null,
    );
  }

  /// 无标题的一组前面的间隙。
  Widget gap(TodoGapEntry entry, int revealIndex) {
    final exiting = _exiting(entry);
    return _shell(
      key: entry.key,
      tag: entry.key,
      revealIndex: revealIndex,
      glass: false,
      visible: !exiting,
      appearing: !exiting && _entering(entry),
      child: const SizedBox(height: AppSpacing.s),
    );
  }

  /// 一行待办。[trailing] 为拖动手柄（可手动排序时）；[ghost] 为已完成组
  /// 消失时留下来收起的画面（不可点、不参与让位）；[allowEntering] 为
  /// false 时不演入场（所在的已完成区块正整块展开）。
  Widget row(
    TodoRowEntry entry,
    int revealIndex, {
    Widget? trailing,
    bool ghost = false,
    bool allowEntering = true,
  }) {
    final row = entry.row;
    final id = row.todoId;
    final exiting = _exiting(entry);
    final leaving = state.leaving.contains(id);
    final visible = !leaving && !exiting;
    final Object tag = ghost
        ? 'ghost:${entry.key}'
        : leaving
        ? 'leaving:${entry.key}'
        : entry.key;
    return _shell(
      key: entry.key,
      tag: tag,
      revealIndex: revealIndex,
      glass: glassCards,
      visible: visible,
      appearing:
          visible &&
          allowEntering &&
          (state.appearing.contains(id) || _entering(entry)),
      child: IgnorePointer(
        ignoring: exiting || ghost,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s),
          child: _tile(row, trailing: trailing),
        ),
      ),
    );
  }

  Widget _tile(TodoRow row, {Widget? trailing}) {
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
    if (AppPlatform.isDesktop) {
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
}
