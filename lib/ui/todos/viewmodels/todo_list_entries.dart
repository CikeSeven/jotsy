import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import 'todo_groups.dart';

/// 待办列表拍平成的一项（纯数据，无 IO）：分组标题、无标题分组前的间隙或
/// 一行待办。
///
/// 列表的数据变化动效（`ListChangeHost`）按 [key] 对应同一项：同一条待办
/// 换了分组（今天 → 明天、已完成 → 未完成）键不变，所以是“滑过去”而不是
/// “这里消失、那里出现”。
@immutable
sealed class TodoListEntry {
  const TodoListEntry(this.group);

  /// 所在的组（退场项为它原来的组）。
  final TodoGroup group;

  String get key;

  /// 是否属于可折叠的已完成组（由已完成区块自己画标题、整块折叠）。
  bool get inDoneSection => isCollapsibleTodoGroup(group.kind);
}

/// 一组的标题（无标题的组与已完成组不出这一项）。
final class TodoHeaderEntry extends TodoListEntry {
  const TodoHeaderEntry(super.group);

  @override
  String get key => 'h:${group.key}';
}

/// 无标题的一组（重要、清单与收集箱里未完成的）前面的间隙。
final class TodoGapEntry extends TodoListEntry {
  const TodoGapEntry(super.group);

  @override
  String get key => 'g:${group.key}';
}

/// 一行待办。
final class TodoRowEntry extends TodoListEntry {
  const TodoRowEntry(super.group, this.row);

  final TodoRow row;

  @override
  String get key => rowKey(row.todoId);

  /// 待办 [todoId] 那一行的键。
  static String rowKey(String todoId) => 'r:$todoId';
}

/// 可折叠的已完成组：清单底部的已完成、“今天”底部的今天已完成。
bool isCollapsibleTodoGroup(TodoGroupKind kind) =>
    kind == TodoGroupKind.completed || kind == TodoGroupKind.completedToday;

/// 把各组拍平成列表项：有标题的组先出标题，无标题的组先出一段间隙，再出
/// 各行；可折叠的已完成组只出行（标题由已完成区块画，折叠时行仍在列表里，
/// 只是不挂载）。折起来的分区（[collapsed] 里有它的键）只出标题：行从
/// 列表里拿掉，列表的数据变化动效让它们原地收起、展开时原地长出来。
List<TodoListEntry> buildTodoListEntries(
  List<TodoGroup> groups, {
  Set<String> collapsed = const <String>{},
}) {
  final entries = <TodoListEntry>[];
  for (final group in groups) {
    if (group.kind == TodoGroupKind.plain) {
      entries.add(TodoGapEntry(group));
    } else if (!isCollapsibleTodoGroup(group.kind)) {
      entries.add(TodoHeaderEntry(group));
    }
    if (group.kind == TodoGroupKind.section && collapsed.contains(group.key)) {
      continue;
    }
    for (final row in group.rows) {
      entries.add(TodoRowEntry(group, row));
    }
  }
  return entries;
}
