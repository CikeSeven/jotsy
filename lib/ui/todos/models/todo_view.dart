import 'package:flutter/foundation.dart';

import '../../../core/database/todo_tags.dart';

/// 待办页左侧 / 顶部可切换的智能视图。枚举名即持久化值（“打开时显示”）。
enum TodoSmartView {
  /// 截止日不晚于今天的未完成待办（逾期的在最上面一组）。
  today,

  /// 有日期的未完成待办，按时间段分组。
  planned,

  /// 高优先级的未完成待办。
  important,

  /// 全部未完成的待办，按清单分组。
  all,

  /// 不在任何清单里的待办。
  inbox,

  /// 已完成的待办，按完成日期分组。
  completed,
}

/// 智能视图在视图面板、左栏与设置里的先后（今天 / 计划 / 重要 / 全部 /
/// 收集箱 / 已完成），清单排在它们之后。
const List<TodoSmartView> kTodoSmartViews = <TodoSmartView>[
  TodoSmartView.today,
  TodoSmartView.planned,
  TodoSmartView.important,
  TodoSmartView.all,
  TodoSmartView.inbox,
  TodoSmartView.completed,
];

/// 待办页当前显示的内容：一个智能视图、一个清单，或一个待办标签。
///
/// 页面临时状态（切换视图不写库）；“打开时显示”的选择以 [key] 存进
/// `TodoSettings`。
@immutable
class TodoView {
  const TodoView.smart(TodoSmartView this.smart) : listId = null, tag = null;

  const TodoView.list(String this.listId) : smart = null, tag = null;

  /// 一个待办标签下的全部未完成待办（与日记标签无关）。
  const TodoView.tag(String this.tag) : smart = null, listId = null;

  static const TodoView today = TodoView.smart(TodoSmartView.today);
  static const TodoView inbox = TodoView.smart(TodoSmartView.inbox);

  /// 智能视图；清单时为 null。
  final TodoSmartView? smart;

  /// 清单的业务 id；不是清单视图时为 null。
  final String? listId;

  /// 标签名；不是标签视图时为 null。同一标签不分大小写（见 [TodoTags]）。
  final String? tag;

  /// 持久化键：智能视图为枚举名，清单为 `list:<id>`，标签为 `tag:<名称>`。
  String get key => switch ((listId, tag)) {
    (final String id, _) => 'list:$id',
    (_, final String name) => 'tag:$name',
    _ => smart!.name,
  };

  /// 解析 [key]；认不出时为 null（调用方回到“今天”）。
  static TodoView? parse(String? key) {
    if (key == null || key.isEmpty) return null;
    if (key.startsWith('list:')) {
      final id = key.substring(5);
      return id.isEmpty ? null : TodoView.list(id);
    }
    if (key.startsWith('tag:')) {
      final name = TodoTags.normalize(key.substring(4));
      return name == null ? null : TodoView.tag(name);
    }
    final smart = TodoSmartView.values.asNameMap()[key];
    return smart == null ? null : TodoView.smart(smart);
  }

  /// 是否只有一个清单（收集箱或某个清单）：这时可以手动拖动排序，底部显示
  /// 这个清单的已完成。
  bool get isSingleList => listId != null || smart == TodoSmartView.inbox;

  /// 桌面上能否把待办行拖到左栏的这一格上：今天（改到今天）、收集箱与各个
  /// 清单（移进去）、各个标签（加上这个标签）。
  bool get acceptsDrop =>
      listId != null ||
      tag != null ||
      smart == TodoSmartView.today ||
      smart == TodoSmartView.inbox;

  /// 在这个视图里新建的待办放进哪个清单：清单视图为它自己，收集箱为 null，
  /// 其余智能视图取设置里的默认清单 [fallbackListId]。
  String? createListId(String? fallbackListId) {
    if (listId != null) return listId;
    if (smart == TodoSmartView.inbox) return null;
    return fallbackListId;
  }

  /// 在这个视图里新建的待办预先带上的截止日：“今天”与“计划”视图带今天，
  /// 其余不带。计划视图只列有日期的待办，不带日期的新待办回车后不会出现在
  /// 当前列表里，看起来像没建成。
  bool get presetsToday =>
      smart == TodoSmartView.today || smart == TodoSmartView.planned;

  /// 在这个视图里新建的待办预先带上的优先级：“重要”视图带高优先级。
  bool get presetsHighPriority => smart == TodoSmartView.important;

  /// 在这个视图里新建的待办预先带上的标签：标签视图带它自己（否则新建的
  /// 不在当前列表里，看起来像没建成）。
  List<String> get presetTags => <String>[?tag];

  String? get _tagKey => switch (tag) {
    final String name => TodoTags.keyOf(name),
    null => null,
  };

  @override
  bool operator ==(Object other) =>
      other is TodoView &&
      other.smart == smart &&
      other.listId == listId &&
      other._tagKey == _tagKey;

  @override
  int get hashCode => Object.hash(smart, listId, _tagKey);

  @override
  String toString() => 'TodoView($key)';
}
