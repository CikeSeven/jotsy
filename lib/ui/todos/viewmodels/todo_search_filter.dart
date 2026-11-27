import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 待办搜索的状态筛选。
enum TodoSearchStatus { all, open, done }

/// 待办搜索页的筛选（页面临时状态，不持久化）：状态、清单、标签、只看高
/// 优先级、只看有日期的。纯数据 + 纯函数。
@immutable
class TodoSearchFilter {
  const TodoSearchFilter({
    this.status = TodoSearchStatus.all,
    this.listChosen = false,
    this.listId,
    this.highOnly = false,
    this.datedOnly = false,
    this.tag,
  });

  final TodoSearchStatus status;

  /// 是否按清单筛（为 true 时 [listId] 为 null 即收集箱）。
  final bool listChosen;
  final String? listId;
  final bool highOnly;
  final bool datedOnly;

  /// 只看带这个待办标签的（不分大小写）；null 为不按标签筛。
  final String? tag;

  /// 什么都没筛。
  bool get isEmpty =>
      status == TodoSearchStatus.all &&
      !listChosen &&
      !highOnly &&
      !datedOnly &&
      tag == null;

  bool matches(TodoRow row) {
    final done = row.completedAt != null;
    if (status == TodoSearchStatus.open && done) return false;
    if (status == TodoSearchStatus.done && !done) return false;
    if (listChosen && row.listId != listId) return false;
    if (highOnly && row.priority != TodoPriority.high.index) return false;
    if (datedOnly && row.dueDate == null) return false;
    final tag = this.tag;
    if (tag != null &&
        !TodoTags.contains(TodoTags.ofMetadataText(row.metadata), tag)) {
      return false;
    }
    return true;
  }

  List<TodoRow> apply(List<TodoRow> rows) => isEmpty
      ? rows
      : <TodoRow>[
          for (final row in rows)
            if (matches(row)) row,
        ];

  TodoSearchFilter copyWith({
    TodoSearchStatus? status,
    bool? highOnly,
    bool? datedOnly,
  }) => TodoSearchFilter(
    status: status ?? this.status,
    listChosen: listChosen,
    listId: listId,
    highOnly: highOnly ?? this.highOnly,
    datedOnly: datedOnly ?? this.datedOnly,
    tag: tag,
  );

  /// 只看某个清单（null 即收集箱）。
  TodoSearchFilter withList(String? listId) => TodoSearchFilter(
    status: status,
    listChosen: true,
    listId: listId,
    highOnly: highOnly,
    datedOnly: datedOnly,
    tag: tag,
  );

  /// 不再按清单筛。
  TodoSearchFilter withoutList() => TodoSearchFilter(
    status: status,
    highOnly: highOnly,
    datedOnly: datedOnly,
    tag: tag,
  );

  /// 只看带标签 [tag] 的；null 为不再按标签筛。
  TodoSearchFilter withTag(String? tag) => TodoSearchFilter(
    status: status,
    listChosen: listChosen,
    listId: listId,
    highOnly: highOnly,
    datedOnly: datedOnly,
    tag: tag,
  );
}
