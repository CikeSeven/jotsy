part of 'todos_page.dart';

/// 待办页的视图与导航：当前视图、新建的预填、换视图（经 [TodoViewSwitch]
/// 先退场再换）、新建 / 管理清单与打开详情。
extension _TodosPageViews on _TodosPageState {
  List<TodoListRow> get _lists =>
      ref.read(todoListsProvider).value ?? const <TodoListRow>[];

  /// 当前视图；清单被删掉（本机或同步）时回到“今天”。
  TodoView _effectiveView(List<TodoListRow>? lists) {
    final view = _view ?? ref.read(todoSettingsProvider).defaultView;
    final listId = view.listId;
    if (listId != null &&
        lists != null &&
        !lists.any((list) => list.listId == listId)) {
      return TodoView.today;
    }
    return view;
  }

  TodoQuickAddPreset _presetFor(TodoView view) {
    final settings = ref.read(todoSettingsProvider);
    return TodoQuickAddPreset(
      listId: view.createListId(settings.defaultListId),
      dueDate: view.presetsToday ? ref.read(todoTodayProvider) : null,
      priority: view.presetsHighPriority
          ? TodoPriority.high
          : TodoPriority.none,
    );
  }

  Future<void> _create() => showTodoQuickAddSheet(
    context,
    preset: _presetFor(_effectiveView(ref.read(todoListsProvider).value)),
  );

  /// 选了视图 [next]：旧列表退场、换成新视图、新列表错峰入场（左栏与视图
  /// 面板立即标出新的选中）。
  void _select(TodoView next) {
    _selection.clear();
    final current = _effectiveView(_lists);
    if (next == current && _viewSwitch.target == null) return;
    unawaited(
      _viewSwitch.switchTo(
        context,
        next,
        direction: TodoViewSwitch.directionOf(current, next, _lists),
      ),
    );
    _update(() {});
  }

  /// 列表看不见的那一帧换成 [view]（[TodoViewSwitch] 回调）。
  void _applyView(TodoView view) {
    if (!mounted) return;
    final from = _effectiveView(_lists);
    _update(() {
      _titleDirection = TodoViewSwitch.directionOf(from, view, _lists);
      _view = view;
      _reorder.clear();
    });
  }

  Future<void> _createList() async {
    final id = await createTodoListFlow(context, ref);
    if (id != null && mounted) _select(TodoView.list(id));
  }

  Future<void> _openViewSheet(TodoView current) async {
    final result = await showTodoViewSheet(context, current: current);
    if (!mounted || result == null) return;
    switch (result) {
      case TodoViewPicked(:final view):
        _select(view);
      case TodoViewCreateList():
        await _createList();
      case TodoViewManageLists():
        await openTodoListsManage(context);
    }
  }

  void _openDetail(TodoRow row) {
    if (_threePane) {
      _update(() => _detailId = row.todoId);
    } else {
      unawaited(openTodoDetail(context, row.todoId));
    }
  }
}
