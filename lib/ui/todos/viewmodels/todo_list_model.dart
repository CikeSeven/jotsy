import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import 'todo_groups.dart';
import 'todo_list_entries.dart';

/// 一个视图此刻的分组与拍平后的列表项。
@immutable
class TodoListModel {
  const TodoListModel(this.groups, this.entries);

  final List<TodoGroup> groups;
  final List<TodoListEntry> entries;
}

/// 按输入缓存 [TodoListModel]（页面持有）：同一份数据、同样的设置不重算。
///
/// 为什么要缓存：列表的数据变化动效按列表项是否换了实例判断数据有没有变，
/// 页面每次重建（多选、内联新建获得焦点……）都给一份新的，会让它白白重量
/// 一遍各项的位置，还把屏外的项误记成“刚出现”。
class TodoListModelCache {
  Object? _inputs;
  TodoListModel? _model;

  /// 视图 [view] 此刻的分组与列表项；数据列表按实例比较，其余按值。
  ///
  /// [localOrder] 为拖动排序后还没推送回来的顺序（只在收集箱与清单手动排序
  /// 时给出），按它重排的未完成列表由 [applyLocalOrder] 给出。
  TodoListModel resolve({
    required TodoView view,
    required List<TodoRow> open,
    required List<TodoRow> completed,
    required List<TodoListRow> lists,
    required TodoSortMode sort,
    required bool showCompleted,
    required DateTime today,
    List<String>? localOrder,
    List<TodoRow> Function(List<TodoRow> open)? applyLocalOrder,
  }) {
    final inputs = (
      view,
      open,
      completed,
      lists,
      sort,
      showCompleted,
      today,
      localOrder,
    );
    final model = _model;
    if (model != null && inputs == _inputs) return model;
    final groups = buildTodoGroups(
      view: view,
      open: localOrder == null || applyLocalOrder == null
          ? open
          : applyLocalOrder(open),
      completed: completed,
      listOrder: <String>[for (final list in lists) list.listId],
      sort: sort,
      today: today,
      showCompleted: showCompleted,
    );
    _inputs = inputs;
    return _model = TodoListModel(groups, buildTodoListEntries(groups));
  }
}
