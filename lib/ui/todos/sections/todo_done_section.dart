import 'package:flutter/widgets.dart';

import '../../widgets/list_make_room.dart';
import '../../widgets/sliver_collapse.dart';
import '../viewmodels/todo_groups.dart';
import '../viewmodels/todo_list_entries.dart';
import 'todo_list_items.dart';

/// 可折叠的已完成组（清单底部的“已完成”、今天视图底部的“今天已完成”）：
/// 标题 + 各行。
///
/// 这一组出现 / 消失、点标题折叠 / 展开，都是整块按高度弹簧展开或收起
/// （[AnimatedSliverCollapse]），不逐行演：一组可能有上百条，逐行收成 0 高
/// 会让懒加载列表一口气构建出全部行。
///
/// 这一组从数据里消失时（隐藏已完成、清除已完成、最后一条恢复成未完成）
/// 留着最后一份画面收起；其中已经挪到别处的行（恢复成未完成的那条）不留，
/// 免得一边滑走、一边在这里还剩一份。留下的画面不可点按、不参与让位。
class TodoDoneSection extends StatefulWidget {
  const TodoDoneSection({
    super.key,
    required this.group,
    required this.entries,
    required this.liveKeys,
    required this.collapsed,
    required this.items,
    required this.revealIndex,
  });

  /// 此刻的这一组；数据里没有时为 null。
  final TodoGroup? group;

  /// 这一组此刻要排版的行（含正在退场的）。
  final List<TodoRowEntry> entries;

  /// 此刻列表里所有项的键：留下的画面里不再画仍在列表里的行。
  final Set<String> liveKeys;
  final bool collapsed;
  final TodoListItems items;

  /// 标题的错峰槽位下标，各行依次往后。
  final int revealIndex;

  @override
  State<TodoDoneSection> createState() => _TodoDoneSectionState();
}

class _TodoDoneSectionState extends State<TodoDoneSection> {
  TodoGroup? _lastGroup;
  List<TodoRowEntry> _lastEntries = const <TodoRowEntry>[];

  /// 上一次构建时这一组是否在：刚出现的那一次，行不另演入场（整块正在
  /// 展开）。
  late bool _wasPresent = widget.group != null;

  @override
  Widget build(BuildContext context) {
    final current = widget.group;
    final present = current != null;
    if (present) {
      _lastGroup = current;
      _lastEntries = widget.entries;
    }
    final group = current ?? _lastGroup;
    final allowEntering = _wasPresent;
    _wasPresent = present;
    if (group == null) {
      return const AnimatedSliverCollapse(
        expanded: false,
        sliver: SliverToBoxAdapter(),
      );
    }
    final rows = present
        ? widget.entries
        : <TodoRowEntry>[
            for (final entry in _lastEntries)
              if (!widget.liveKeys.contains(entry.key)) entry,
          ];
    final items = widget.items;
    final indexOfKey = <String, int>{
      for (var i = 0; i < rows.length; i++) rows[i].key: i,
    };
    return AnimatedSliverCollapse(
      expanded: present,
      sliver: SliverMainAxisGroup(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: items.doneHeader(
              group,
              widget.revealIndex,
              interactive: present,
            ),
          ),
          AnimatedSliverCollapse(
            expanded: !widget.collapsed,
            sliver: MakeRoomSliverList(
              makeRoom: items.frame.makeRoom,
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => items.row(
                  rows[index],
                  widget.revealIndex + 1 + index,
                  ghost: !present,
                  allowEntering: allowEntering,
                ),
                childCount: rows.length,
                findChildIndexCallback: (Key key) =>
                    key is ValueKey<String> ? indexOfKey[key.value] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
