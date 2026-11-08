import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/editing_session_registry.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../home/widgets/home_bar/home_chrome_scope.dart';
import '../../home/widgets/home_bar/home_top_bar_surface.dart';
import '../../widgets/page_header.dart';
import '../../widgets/width_layout_builder.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_batch_actions.dart';
import '../controllers/todo_appearance_tracker.dart';
import '../controllers/todo_completion_queue.dart';
import '../controllers/todo_list_actions.dart';
import '../controllers/todo_navigation.dart';
import '../controllers/todo_page_selection.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../sections/todo_list_slivers.dart';
import '../sections/todo_selection_bar.dart';
import '../sections/todo_view_sheet.dart';
import '../sections/todos_page_list.dart';
import '../sections/todos_page_header.dart';
import '../sections/todos_page_menu.dart';
import '../sections/todos_wide_layout.dart';
import '../viewmodels/todo_groups.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_quick_add_sheet.dart';
import '../widgets/todo_view_switcher.dart';

/// 待办 Tab。
///
/// 页面职责（AGENTS §3：页面只装配）：
/// - 订阅未完成 / 已完成的待办、清单、清单进度与待办偏好；
/// - 持有页面临时状态：当前视图（初始取“打开时显示”）、折叠的分组、多选、
///   勾选后正在收起的行（[TodoCompletionQueue]）、刚出现的行、内联新建是否
///   在输入、宽窗口详情栏正在看的那一条；
/// - 窄窗口：页头标题“今天 ▾”点开视图面板（[showTodoViewSheet]），列表
///   顶部是概览卡；宽窗口（≥1024）：左栏视图与清单，可用宽度够时右侧再
///   加详情栏（点开待办放进去），不够时弹底部面板；
/// - 列表的分组与排序交给纯函数 [buildTodoGroups]，sliver 交给
///   [buildTodosPageList]；勾选、删除、批量操作的流程在 controllers。
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

class _TodosPageState extends ConsumerState<TodosPage> {
  TodoView? _view;
  final Set<String> _collapsed = <String>{};

  /// 拖动排序从拿起到写完是局域网同步的阻塞者：期间同步改了顺序，松手时按
  /// 旧下标算出的邻居就不对了。
  final ReorderEditingGuard _drag = ReorderEditingGuard('todos-reorder');

  late final TodoCompletionQueue _queue = TodoCompletionQueue(
    onChanged: () {
      if (mounted) setState(() {});
    },
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

  /// 宽窗口详情栏正在看的那一条；[_threePane] 为当前布局能否放详情栏。
  String? _detailId;
  bool _threePane = false;

  @override
  void initState() {
    super.initState();
    widget.onCreateActionChanged?.call(_create);
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
    _drag.end();
    _queue.dispose();
    super.dispose();
  }

  AppDatabase get _db => ref.read(appDatabaseProvider);

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

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  TodoQuickAddPreset _presetFor(TodoView view) {
    final settings = ref.read(todoSettingsProvider);
    return TodoQuickAddPreset(
      listId: view.createListId(settings.defaultListId),
      dueDate: view.presetsToday ? _today : null,
      priority: view.presetsHighPriority
          ? TodoPriority.high
          : TodoPriority.none,
    );
  }

  Future<void> _create() => showTodoQuickAddSheet(
    context,
    preset: _presetFor(_effectiveView(ref.read(todoListsProvider).value)),
  );

  void _select(TodoView next) {
    _selection.clear();
    setState(() => _view = next);
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

  void _reorder(List<TodoRow> rows, int oldIndex, int newIndex) {
    final moved = rows[oldIndex];
    final order = List<TodoRow>.of(rows)..removeAt(oldIndex);
    order.insert(newIndex, moved);
    final above = newIndex > 0 ? order[newIndex - 1].todoId : null;
    final below = newIndex < order.length - 1
        ? order[newIndex + 1].todoId
        : null;
    unawaited(
      _drag.holdUntil(
        _db.moveTodo(moved.todoId, aboveId: above, belowId: below),
      ),
    );
  }

  void _openDetail(TodoRow row) {
    if (_threePane) {
      setState(() => _detailId = row.todoId);
    } else {
      unawaited(openTodoDetail(context, row.todoId));
    }
  }

  void _onRowTap(TodoRow row) {
    if (_selection.active) {
      _selection.toggle(row.todoId);
      return;
    }
    final keys = HardwareKeyboard.instance;
    if (AppPlatform.isDesktop &&
        (keys.isControlPressed || keys.isMetaPressed)) {
      _selection.enter(row.todoId);
      return;
    }
    _openDetail(row);
  }

  void _onRowLongPress(TodoRow row) {
    if (_selection.active) {
      _selection.toggle(row.todoId);
      return;
    }
    // Android 由 InkWell 的长按反馈负责，避免震两次。
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      unawaited(HapticFeedback.mediumImpact());
    }
    _selection.enter(row.todoId);
  }

  TodoListCallbacks _callbacks() => TodoListCallbacks(
    onToggle: (TodoRow row) => row.completedAt != null
        ? unawaited(toggleTodoDone(context, _db, row))
        : _queue.start(context, _db, row),
    onSwipeToggle: (TodoRow row) =>
        unawaited(toggleTodoDone(context, _db, row)),
    onTap: _onRowTap,
    onLongPress: _onRowLongPress,
    onDelete: (TodoRow row) =>
        unawaited(deleteTodoWithUndo(context, _db, row.todoId)),
    onMoveToToday: (TodoRow row) =>
        unawaited(todoMoveRowsToDay(context, ref, <TodoRow>[row], _today)),
    onMoveToList: (TodoRow row) =>
        unawaited(todoMoveRowsToList(context, ref, <TodoRow>[row])),
    onMoveOverdueToToday: (List<TodoRow> rows) =>
        unawaited(todoMoveRowsToDay(context, ref, rows, _today)),
    onReorder: _reorder,
    onReorderStart: _drag.start,
    onReorderEnd: _drag.dropped,
  );

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
    final today = _today;
    if (open != null) _queue.prune(open);
    _appearance.track(open, completed);

    final headerHeight =
        MediaQuery.paddingOf(context).top + PageHeader.contentHeight;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final listsById = <String, TodoListRow>{
      for (final list in lists) list.listId: list,
    };
    final counts = open == null
        ? const <TodoSmartView, int>{}
        : todoSmartViewCounts(open, today);
    final groups = open == null || completed == null
        ? null
        : buildTodoGroups(
            view: view,
            open: open,
            completed: completed,
            listOrder: <String>[for (final list in lists) list.listId],
            sort: settings.sort,
            today: today,
            showCompleted: settings.showCompleted,
          );
    final visibleRows = <TodoRow>[
      for (final group in groups ?? const <TodoGroup>[]) ...group.rows,
    ];
    _selection.retain(visibleRows);

    Widget list(double width, {required bool wide}) => buildTodosPageList(
      context: context,
      view: view,
      today: today,
      groups: groups,
      open: open,
      completed: completed,
      counts: counts,
      listsById: listsById,
      progress: progress,
      settings: settings,
      wide: wide,
      width: width,
      topInset: wide ? 0 : headerHeight + kHomeTopContentGap,
      bottomInset: bottomInset,
      inlineEditing: _inlineEditing,
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
      callbacks: _callbacks(),
      inlinePreset: view.smart == TodoSmartView.completed
          ? null
          : _presetFor(view),
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
          view: view,
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
        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (bool didPop, Object? _) {
            if (!didPop && _selection.active) _selection.clear();
          },
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              if (selecting)
                const SingleActivator(LogicalKeyboardKey.escape):
                    _selection.clear,
            },
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ColoredBox(
                    color: AppPageBackdrop.pageColorOf(context),
                  ),
                ),
                SafeArea(top: false, bottom: false, child: layout(width)),
                if (selecting)
                  TodoSelectionHeader(
                    count: _selection.ids.length,
                    allSelected: _selection.containsAll(visibleRows),
                    onToggleAll: () => _selection.toggleAll(visibleRows),
                    onClose: _selection.clear,
                  )
                else
                  TodosPageHeader(
                    view: view,
                    title: listId != null
                        ? listsById[listId]?.name ?? l10n.navTodos
                        : TodoLabels.smartView(l10n, view.smart!),
                    narrow: width < AppBreakpoints.expanded,
                    wideShell: HomeChromeScope.wideShellOf(context),
                    settings: settings,
                    completedInView: completed == null
                        ? 0
                        : countCompletedInView(view, completed),
                    list: listId == null ? null : listsById[listId],
                    onOpenViews: () => unawaited(_openViewSheet(view)),
                    onCreate: () => unawaited(_create()),
                  ),
                if (selecting)
                  Positioned(
                    left: AppSpacing.l,
                    right: AppSpacing.l,
                    bottom: bottomInset + AppSpacing.l,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: buildTodoSelectionActionBar(
                          context,
                          ref,
                          selection: _selection,
                          rows: visibleRows,
                          today: today,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
