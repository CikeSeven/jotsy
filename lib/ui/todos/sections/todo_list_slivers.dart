import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../diaries/controllers/diary_list_switch_motion.dart';
import '../../widgets/expressive_reorder_proxy.dart';
import '../../widgets/list_change_host.dart';
import '../../widgets/list_make_room.dart';
import '../../widgets/reorder_handle.dart';
import '../viewmodels/todo_groups.dart';
import '../viewmodels/todo_list_entries.dart';
import 'todo_done_section.dart';
import 'todo_list_callbacks.dart';
import 'todo_list_items.dart';

/// 待办列表的各组（一个 sliver）：开放区（各组标题与行）→ 内联新建 →
/// 可折叠的已完成区块（[TodoDoneSection]）。
///
/// 数据变化动效（[ListChangeHost]，按 [TodoListEntry.key] 对应同一项）：
/// - 换了排序、改了日期或优先级、撤销、同步推来的变化：仍在列表里的项以
///   弹簧从原位置滑到新位置，跨组也一样（让位控制器按整个滚动视图的坐标
///   记位置，见 [MakeRoomController.acrossSlivers]）；
/// - 移出视图的行、空了的组标题原地收起后再让位；回到视图的行（撤销）原地
///   展开；勾选后由页面先收起的行（[TodoListRowState.leaving]）直接拿掉；
/// - 切换视图途中（[switchMotion] 不在静止态）不演，交给视图切换的错峰
///   入场。
///
/// [reorderable] 为 true 时（收集箱或清单、手动排序，且不在多选），开放区
/// 是可拖动排序的列表（手柄按住即拖，拿起时给一次触觉）。手机上右滑完成 /
/// 恢复、左滑删除（松手越过阈值才生效，多选时关闭）；桌面不提供滑动，改为
/// 右键菜单。
class TodoListSlivers extends StatelessWidget {
  const TodoListSlivers({
    super.key,
    required this.groups,
    required this.entries,
    required this.doneKind,
    required this.reorderable,
    required this.listsById,
    required this.showListOnRows,
    required this.today,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.callbacks,
    required this.state,
    required this.makeRoom,
    required this.switchMotion,
    required this.horizontalPadding,
    required this.firstRevealIndex,
    this.inlineAdd,
  });

  final List<TodoGroup> groups;

  /// [groups] 拍平后的列表项（[buildTodoListEntries]，由页面按数据缓存：
  /// 同一份数据不重算，数据变化动效按它是否换了实例判断有没有变化）。
  final List<TodoListEntry> entries;

  /// 这个视图里可折叠的已完成组的种类（今天视图为今天已完成，清单与收集箱
  /// 为已完成）；没有时为 null。
  final TodoGroupKind? doneKind;
  final bool reorderable;
  final Map<String, TodoListRow> listsById;
  final bool showListOnRows;
  final DateTime today;
  final Set<String> collapsed;
  final ValueChanged<String> onToggleCollapsed;
  final TodoListCallbacks callbacks;
  final TodoListRowState state;
  final MakeRoomController makeRoom;
  final DiaryListSwitchMotion switchMotion;
  final double horizontalPadding;

  /// 第一项的错峰槽位下标（前面还有概览卡）。
  final int firstRevealIndex;
  final Widget? inlineAdd;

  @override
  Widget build(BuildContext context) {
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    return ListChangeHost<TodoListEntry>(
      items: entries,
      keyOf: (TodoListEntry entry) => entry.key,
      duration: duration,
      pendingHideKeys: <String>{
        for (final id in state.leaving) TodoRowEntry.rowKey(id),
      },
      appearingKeys: <String>{
        for (final id in state.appearing) TodoRowEntry.rowKey(id),
      },
      makeRoom: makeRoom,
      canAnimate: () => switchMotion.isIdle,
      builder: (BuildContext context, ListChangeFrame<TodoListEntry> frame) =>
          _build(context, frame, duration),
    );
  }

  Widget _build(
    BuildContext context,
    ListChangeFrame<TodoListEntry> frame,
    Duration duration,
  ) {
    final items = TodoListItems(
      frame: frame,
      callbacks: callbacks,
      state: state,
      today: today,
      listsById: listsById,
      showListOnRows: showListOnRows,
      switchMotion: switchMotion,
      presenceDuration: duration,
      glassCards: AppGlass.of(context).isGlass(AppGlassComponent.cards),
      collapsed: collapsed,
      onToggleCollapsed: onToggleCollapsed,
    );
    final open = <TodoListEntry>[];
    final done = <TodoRowEntry>[];
    for (final entry in frame.items) {
      if (!entry.inDoneSection) {
        open.add(entry);
      } else if (entry is TodoRowEntry) {
        done.add(entry);
      }
    }
    final doneKind = this.doneKind;
    TodoGroup? doneGroup;
    if (doneKind != null) {
      for (final group in groups) {
        if (group.kind == doneKind) doneGroup = group;
      }
    }
    final add = inlineAdd;
    var index = firstRevealIndex;
    final openSliver = reorderable
        ? _reorderableZone(items, open, index)
        : _openZone(items, open, index);
    index += open.length;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverMainAxisGroup(
        slivers: <Widget>[
          openSliver,
          if (add != null)
            SliverToBoxAdapter(
              child: MakeRoomItem(
                tag: 'inline_add',
                controller: makeRoom,
                child: items.reveal(
                  index++,
                  Padding(
                    padding: EdgeInsets.only(
                      top: open.isEmpty ? AppSpacing.m : AppSpacing.xs,
                    ),
                    child: add,
                  ),
                ),
              ),
            ),
          if (doneKind != null)
            TodoDoneSection(
              key: ValueKey<String>('done_${doneKind.name}'),
              group: doneGroup,
              entries: done,
              liveKeys: <String>{for (final entry in frame.items) entry.key},
              collapsed: doneGroup != null && collapsed.contains(doneGroup.key),
              items: items,
              revealIndex: index,
            ),
        ],
      ),
    );
  }

  /// 开放区：各组标题、间隙与行排在同一个让位列表里（跨组换位时按位移从
  /// 小到大绘制，换位最远的压在上面）。
  Widget _openZone(TodoListItems items, List<TodoListEntry> open, int first) {
    final indexOfKey = <String, int>{
      for (var i = 0; i < open.length; i++) open[i].key: i,
    };
    return MakeRoomSliverList(
      makeRoom: makeRoom,
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) => switch (open[index]) {
          final TodoHeaderEntry entry => items.header(entry, first + index),
          final TodoGapEntry entry => items.gap(entry, first + index),
          final TodoRowEntry entry => items.row(entry, first + index),
        },
        childCount: open.length,
        findChildIndexCallback: (Key key) =>
            key is ValueKey<String> ? indexOfKey[key.value] : null,
      ),
    );
  }

  /// 可手动排序时的开放区：只有一组无标题的行，间隙在列表之外（不参与
  /// 拖动），行带拖动手柄。
  Widget _reorderableZone(
    TodoListItems items,
    List<TodoListEntry> open,
    int first,
  ) {
    final gaps = <TodoGapEntry>[
      for (final entry in open)
        if (entry is TodoGapEntry) entry,
    ];
    final rows = <TodoRowEntry>[
      for (final entry in open)
        if (entry is TodoRowEntry) entry,
    ];
    final shown = <TodoRow>[for (final entry in rows) entry.row];
    return SliverMainAxisGroup(
      slivers: <Widget>[
        for (final gap in gaps)
          SliverToBoxAdapter(child: items.gap(gap, first)),
        SliverReorderableList(
          itemCount: rows.length,
          proxyDecorator: cardRowReorderProxyDecorator,
          onReorderStart: (int index) {
            callbacks.onReorderStart(index);
            unawaited(HapticFeedback.mediumImpact());
          },
          onReorderEnd: callbacks.onReorderEnd,
          onReorderItem: (int oldIndex, int newIndex) =>
              callbacks.onReorder(shown, oldIndex, newIndex),
          itemBuilder: (BuildContext context, int index) => items.row(
            rows[index],
            first + gaps.length + index,
            trailing: ReorderHandle(index: index),
          ),
        ),
      ],
    );
  }
}
