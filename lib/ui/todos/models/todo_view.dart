import 'package:flutter/foundation.dart';

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

/// 待办页当前显示的内容：一个智能视图，或一个清单。
///
/// 页面临时状态（切换视图不写库）；“打开时显示”的选择以 [key] 存进
/// `TodoSettings`。
@immutable
class TodoView {
  const TodoView.smart(TodoSmartView this.smart) : listId = null;

  const TodoView.list(String this.listId) : smart = null;

  static const TodoView today = TodoView.smart(TodoSmartView.today);
  static const TodoView inbox = TodoView.smart(TodoSmartView.inbox);

  /// 智能视图；清单时为 null。
  final TodoSmartView? smart;

  /// 清单的业务 id；智能视图时为 null。
  final String? listId;

  /// 持久化键：智能视图为枚举名，清单为 `list:<id>`。
  String get key => listId != null ? 'list:$listId' : smart!.name;

  /// 解析 [key]；认不出时为 null（调用方回到“今天”）。
  static TodoView? parse(String? key) {
    if (key == null || key.isEmpty) return null;
    if (key.startsWith('list:')) {
      final id = key.substring(5);
      return id.isEmpty ? null : TodoView.list(id);
    }
    final smart = TodoSmartView.values.asNameMap()[key];
    return smart == null ? null : TodoView.smart(smart);
  }

  /// 是否只有一个清单（收集箱或某个清单）：这时可以手动拖动排序，底部显示
  /// 这个清单的已完成。
  bool get isSingleList => listId != null || smart == TodoSmartView.inbox;

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

  @override
  bool operator ==(Object other) =>
      other is TodoView && other.smart == smart && other.listId == listId;

  @override
  int get hashCode => Object.hash(smart, listId);

  @override
  String toString() => 'TodoView($key)';
}
