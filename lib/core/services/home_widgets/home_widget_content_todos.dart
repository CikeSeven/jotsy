part of 'home_widget_content.dart';

// 待办清单小组件的内容选项（见 home_widget_content.dart 文件头）。

/// 待办小组件显示哪些待办。视图名与待办 Tab 的智能视图一致。
enum TodoWidgetView {
  /// 今天（含逾期）。
  today,

  /// 有截止日的（计划）。
  planned,

  /// 全部未完成。
  all,

  /// 某个清单（[TodoListContent.listId]）。
  list,
}

class TodoListContent extends HomeWidgetContent {
  const TodoListContent({
    this.view = TodoWidgetView.today,
    this.listId,
    this.showCompleted = true,
    this.showDue = true,
  });

  static const TodoListContent defaults = TodoListContent();

  final TodoWidgetView view;

  /// [TodoWidgetView.list] 时显示哪个清单（业务 id）；清单被删除后按“全部”显示。
  final String? listId;

  /// 列表末尾显示今天已完成的（划掉）。
  final bool showCompleted;

  /// 每行显示截止日与时刻。
  final bool showDue;

  TodoListContent copyWith({
    TodoWidgetView? view,
    String? Function()? listId,
    bool? showCompleted,
    bool? showDue,
  }) => TodoListContent(
    view: view ?? this.view,
    listId: listId == null ? this.listId : listId(),
    showCompleted: showCompleted ?? this.showCompleted,
    showDue: showDue ?? this.showDue,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'view': view.name,
    'list': ?listId,
    'completed': showCompleted,
    'due': showDue,
  };

  static TodoListContent _fromJson(Map<Object?, Object?> json) {
    final list = json['list'];
    return TodoListContent(
      view: _pick(TodoWidgetView.values, json['view'], defaults.view),
      listId: list is String && list.isNotEmpty ? list : null,
      showCompleted: _bool(json['completed'], defaults.showCompleted),
      showDue: _bool(json['due'], defaults.showDue),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TodoListContent &&
      other.view == view &&
      other.listId == listId &&
      other.showCompleted == showCompleted &&
      other.showDue == showDue;

  @override
  int get hashCode => Object.hash(view, listId, showCompleted, showDue);
}
