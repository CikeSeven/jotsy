import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../home/widgets/home_bar/home_chrome_scope.dart';
import '../../home/widgets/home_bar/home_top_bar_surface.dart';
import '../../widgets/list_make_room.dart';
import '../../widgets/page_header.dart';
import '../../widgets/width_layout_builder.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_appearance_tracker.dart';
import '../controllers/todo_completion_queue.dart';
import '../controllers/todo_list_actions.dart';
import '../controllers/todo_navigation.dart';
import '../controllers/todo_page_rows.dart';
import '../controllers/todo_page_selection.dart';
import '../controllers/todo_reorder.dart';
import '../controllers/todo_view_switch.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../sections/todo_list_callbacks.dart';
import '../sections/todo_selection_bar.dart';
import '../sections/todo_view_sheet.dart';
import '../sections/todos_page_frame.dart';
import '../sections/todos_page_header.dart';
import '../sections/todos_page_list.dart';
import '../sections/todos_page_menu.dart';
import '../sections/todos_wide_layout.dart';
import '../viewmodels/todo_groups.dart';
import '../viewmodels/todo_list_model.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_quick_add_sheet.dart';
import '../widgets/todo_view_switcher.dart';

/// 待办 Tab。
///
/// 页面职责（AGENTS §3：页面只装配）：
/// - 订阅未完成 / 已完成的待办、清单、清单进度与待办偏好；
/// - 持有页面临时状态：当前视图（初始取“打开时显示”）、折叠的分组、多选、
///   勾选后正在收起的行（[TodoCompletionQueue]）、刚出现的行、内联新建是否
///   在输入、宽窗口详情栏正在看的那一条、拖动排序（[TodoReorder]）；
/// - 动效：列表数据变化时各项滑到新位置（[MakeRoomController]，按整个滚动
///   视图的坐标记位置，跨组也能滑），切换视图时旧列表退场、新列表错峰入场
///   （[TodoViewSwitch]），页头标题朝同一方向滑换；
/// - “今天”取 [todoTodayProvider]（跨零点自动换到新的一天），回到前台时
///   校正一次；
/// - 窄窗口：页头标题“今天 ▾”点开视图面板（[showTodoViewSheet]），列表
///   顶部是概览卡；宽窗口（≥1024）：左栏视图与清单，可用宽度够时右侧再
///   加详情栏（点开待办放进去），不够时弹底部面板；
/// - 分组与列表项交给 [TodoListModelCache]（同一份数据不重算），sliver 交给
///   [buildTodosPageList]；行的交互在 [buildTodoPageCallbacks]，勾选、删除、
///   批量操作的流程在 controllers。
///
/// 新建入口在首页的 FAB（只在待办 Tab 出现，经 [onCreateActionChanged] 注册
/// 本页的新建动作：按当前视图预先带上清单 / 今天 / 高优先级），列表末尾另有
/// 内联新建。多选时经 [onSelectionModeChanged] 告诉首页：隐藏新建入口，
/// 返回键交给本页退出多选。
class TodosPage extends ConsumerStatefulWidget {
  const TodosPage({
    super.key,
    this.onCreateActionChanged,
    this.onSelectionModeChanged,
  });

  final ValueChanged<Future<void> Function()?>? onCreateActionChanged;
  final ValueChanged<bool>? onSelectionModeChanged;

  @override
  ConsumerState<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends ConsumerState<TodosPage>
    with TickerProviderStateMixin {
  TodoView? _view;
  final Set<String> _collapsed = <String>{};

  late final TodoReorder _reorder = TodoReorder(onChanged: _rebuild);
  late final TodoCompletionQueue _queue = TodoCompletionQueue(
    onChanged: _rebuild,
  );
  late final TodoPageSelection _selection = TodoPageSelection(
    onChanged: (bool selecting) {
      if (!mounted) return;
      setState(() {});
      widget.onSelectionModeChanged?.call(selecting);
    },
  );

  /// 页面打开时已有的待办；之后才出现的（新建、同步来的）展开进场。
  final TodoAppearanceTracker _appearance = TodoAppearanceTracker();
  bool _inlineEditing = false;

  /// 内联新建按视图各用一把 GlobalKey：组的增减会让它在 sliver 列表里换位置
  /// （空列表时在空状态之上，有组后在最后一组未完成之后，上面多出一组也会
  /// 挪），普通 key 只在同级之间对应，换了位置就重建——输入框失焦、键盘收起、
  /// 打到一半的字丢掉，在空视图里记第一条时尤其明显。换视图时换一把，预填与
  /// 输入框跟着视图走。
  final Map<String, GlobalKey> _inlineAddKeys = <String, GlobalKey>{};

  /// 宽窗口详情栏正在看的那一条；[_threePane] 为当前布局能否放详情栏。
  String? _detailId;
  bool _threePane = false;

  late final MakeRoomController _makeRoom = MakeRoomController(
    vsync: this,
    acrossSlivers: true,
  );
  late final TodoViewSwitch _viewSwitch = TodoViewSwitch(
    vsync: this,
    onSwap: _applyView,
  );

  /// 上一次换视图的方向：页头标题朝这边滑换。
  int _titleDirection = 0;
  final TodoListModelCache _model = TodoListModelCache();

  /// 回到前台时校正“今天”：零点的计时器在后台可能被系统推迟或冻结。
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.onCreateActionChanged?.call(_create);
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(todoTodayProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    widget.onCreateActionChanged?.call(null);
    // 卸载时树已锁定，首页的 setState 放到帧后（功能关闭时本页带着多选被
    // 卸掉，首页不能一直以为还在多选、藏着新建入口）。
    final onSelectionModeChanged = widget.onSelectionModeChanged;
    if (_selection.active && onSelectionModeChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onSelectionModeChanged(false),
      );
    }
    _reorder.dispose();
    _queue.dispose();
    _lifecycle.dispose();
    _viewSwitch.dispose();
    _makeRoom.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  AppDatabase get _db => ref.read(appDatabaseProvider);

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
    setState(() {});
  }

  /// 列表看不见的那一帧换成 [view]（[TodoViewSwitch] 回调）。
  void _applyView(TodoView view) {
    if (!mounted) return;
    final from = _effectiveView(_lists);
    setState(() {
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
      setState(() => _detailId = row.todoId);
    } else {
      unawaited(openTodoDetail(context, row.todoId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final open = ref.watch(openTodosProvider).value;
    final completed = ref.watch(completedTodosProvider).value;
    final listsValue = ref.watch(todoListsProvider).value;
    final lists = listsValue ?? const <TodoListRow>[];
    final progress =
        ref.watch(todoListProgressProvider).value ??
        const <String?, TodoListProgress>{};
    final settings = ref.watch(todoSettingsProvider);
    final view = _effectiveView(listsValue);
    final today = ref.watch(todoTodayProvider);
    if (open != null) {
      _queue.prune(open);
      _reorder.settle(open);
    }
    _appearance.track(open, completed);
    // 收集箱与清单按拖动顺序排时，拖动后先用本地顺序。
    final manualOrder =
        view.isSingleList && settings.sort == TodoSortMode.manual;

    final headerHeight =
        MediaQuery.paddingOf(context).top + PageHeader.contentHeight;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final listsById = <String, TodoListRow>{
      for (final list in lists) list.listId: list,
    };
    final counts = open == null
        ? const <TodoSmartView, int>{}
        : todoSmartViewCounts(open, today);
    final model = open == null || completed == null
        ? null
        : _model.resolve(
            view: view,
            open: open,
            completed: completed,
            lists: lists,
            sort: settings.sort,
            showCompleted: settings.showCompleted,
            today: today,
            localOrder: manualOrder ? _reorder.order : null,
            applyLocalOrder: _reorder.apply,
          );
    final groups = model?.groups;
    final visibleRows = <TodoRow>[
      for (final group in groups ?? const <TodoGroup>[]) ...group.rows,
    ];
    _selection.retain(visibleRows);

    Widget list(double width, {required bool wide}) => buildTodosPageList(
      context: context,
      view: view,
      today: today,
      groups: groups,
      entries: model?.entries,
      open: open,
      completed: completed,
      counts: counts,
      listsById: listsById,
      progress: progress,
      wide: wide,
      width: width,
      topInset: wide ? 0 : headerHeight + kHomeTopContentGap,
      bottomInset: bottomInset,
      inlineEditing: _inlineEditing,
      reorderable: manualOrder && !_selection.active,
      collapsed: _collapsed,
      onToggleCollapsed: (String key) => setState(
        () => _collapsed.contains(key)
            ? _collapsed.remove(key)
            : _collapsed.add(key),
      ),
      rowState: TodoListRowState(
        selectionMode: _selection.active,
        selected: _selection.ids,
        leaving: _queue.leaving.toSet(),
        appearing: _appearance.appearing,
        highlightedId: _threePane ? _detailId : null,
      ),
      callbacks: buildTodoPageCallbacks(
        context: context,
        ref: ref,
        selection: _selection,
        queue: _queue,
        reorder: _reorder,
        openDetail: _openDetail,
      ),
      inlinePreset: view.smart == TodoSmartView.completed
          ? null
          : _presetFor(view),
      inlineAddKey: _inlineAddKeys.putIfAbsent(
        view.key,
        () => GlobalKey(debugLabel: 'todo_inline_add_${view.key}'),
      ),
      onInlineEditingChanged: (bool editing) {
        if (mounted && editing != _inlineEditing) {
          setState(() => _inlineEditing = editing);
        }
      },
      onEditList: view.listId == null || listsById[view.listId] == null
          ? null
          : () => unawaited(
              editTodoListFlow(context, ref, listsById[view.listId]!),
            ),
      makeRoom: _makeRoom,
      switchMotion: _viewSwitch.motion,
    );

    // 按页面实际可用宽度（扣掉左右安全区）分档：窄窗口单栏，宽窗口左栏 +
    // 列表 (+ 详情栏)。
    Widget layout(double width) {
      if (width < AppBreakpoints.expanded) {
        _threePane = false;
        return list(width, wide: false);
      }
      _threePane = TodosWideLayout.canShowPane(width);
      return TodosWideLayout(
        width: width,
        topInset: headerHeight + kHomeTopContentGap,
        detailId: _detailId,
        sidebar: TodoSidebar(
          // 退场途中就标出新选的视图。
          view: _viewSwitch.target ?? view,
          lists: lists,
          counts: counts,
          progress: progress,
          onSelected: _select,
          onCreateList: () => unawaited(_createList()),
          onManageLists: () => unawaited(openTodoListsManage(context)),
        ),
        list: (double listWidth) => list(listWidth, wide: true),
        onCloseDetail: () => setState(() => _detailId = null),
        onDeleteDetail: (String id) {
          setState(() => _detailId = null);
          unawaited(deleteTodoWithUndo(context, _db, id));
        },
      );
    }

    final selecting = _selection.active;
    final listId = view.listId;
    return WidthLayoutBuilder(
      builder: (BuildContext context, double fullWidth) {
        final width = fullWidth - MediaQuery.paddingOf(context).horizontal;
        return TodosPageFrame(
          selecting: selecting,
          onExitSelection: _selection.clear,
          bottomInset: bottomInset,
          body: layout(width),
          header: selecting
              ? TodoSelectionHeader(
                  count: _selection.ids.length,
                  allSelected: _selection.containsAll(visibleRows),
                  onToggleAll: () => _selection.toggleAll(visibleRows),
                  onClose: _selection.clear,
                )
              : TodosPageHeader(
                  view: view,
                  title: listId != null
                      ? listsById[listId]?.name ?? l10n.navTodos
                      : TodoLabels.smartView(l10n, view.smart!),
                  titleDirection: _titleDirection,
                  narrow: width < AppBreakpoints.expanded,
                  wideShell: HomeChromeScope.wideShellOf(context),
                  settings: settings,
                  completedInView: completed == null
                      ? 0
                      : countCompletedInView(view, completed),
                  list: listId == null ? null : listsById[listId],
                  onOpenViews: () =>
                      unawaited(_openViewSheet(_viewSwitch.target ?? view)),
                  onCreate: () => unawaited(_create()),
                ),
          actionBar: selecting
              ? buildTodoSelectionActionBar(
                  context,
                  ref,
                  selection: _selection,
                  rows: visibleRows,
                  today: today,
                )
              : null,
        );
      },
    );
  }
}
