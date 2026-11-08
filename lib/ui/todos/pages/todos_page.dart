import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/editing_session_registry.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../home/widgets/home_bar/home_chrome_scope.dart';
import '../../home/widgets/home_bar/home_top_bar_surface.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/page_header.dart';
import '../../widgets/width_layout_builder.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_list_actions.dart';
import '../controllers/todo_navigation.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../sections/todo_list_slivers.dart';
import '../sections/todos_page_menu.dart';
import '../viewmodels/todo_groups.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_quick_add_sheet.dart';
import '../widgets/todo_view_switcher.dart';

/// 待办 Tab。
///
/// 页面职责（AGENTS §3：页面只装配）：
/// - 订阅未完成 / 已完成的待办、清单与各清单计数、待办偏好；
/// - 持有当前视图（页面临时状态，初始取“打开时显示”）与折叠的分组；
/// - 窄窗口在页头下方排一行视图胶囊，宽窗口（≥1024）左栏是视图与清单；
/// - 列表的分组与排序交给纯函数 [buildTodoGroups]，sliver 交给
///   [buildTodoListSlivers]；勾选、删除、清除的流程在 `todo_actions.dart`。
///
/// 新建入口在首页的 FAB（只在待办 Tab 出现，经 [onCreateActionChanged] 注册
/// 本页的新建动作：按当前视图预先带上清单 / 今天 / 高优先级）。
class TodosPage extends ConsumerStatefulWidget {
  const TodosPage({super.key, this.onCreateActionChanged});

  final ValueChanged<Future<void> Function()?>? onCreateActionChanged;

  @override
  ConsumerState<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends ConsumerState<TodosPage> {
  TodoView? _view;
  final Set<String> _collapsed = <String>{};

  /// 拖动排序从拿起到写完是局域网同步的阻塞者：期间同步改了顺序，松手时按
  /// 旧下标算出的邻居就不对了。
  final ReorderEditingGuard _drag = ReorderEditingGuard('todos-reorder');

  @override
  void initState() {
    super.initState();
    widget.onCreateActionChanged?.call(_create);
  }

  @override
  void dispose() {
    widget.onCreateActionChanged?.call(null);
    _drag.end();
    super.dispose();
  }

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

  Future<void> _create() async {
    final view = _effectiveView(ref.read(todoListsProvider).value);
    final settings = ref.read(todoSettingsProvider);
    await showTodoQuickAddSheet(
      context,
      preset: TodoQuickAddPreset(
        listId: view.createListId(settings.defaultListId),
        dueDate: view.presetsToday ? _today : null,
        priority: view.presetsHighPriority
            ? TodoPriority.high
            : TodoPriority.none,
      ),
    );
  }

  Future<void> _createList() async {
    final id = await createTodoListFlow(context, ref);
    if (id != null && mounted) setState(() => _view = TodoView.list(id));
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
        ref
            .read(appDatabaseProvider)
            .moveTodo(moved.todoId, aboveId: above, belowId: below),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final open = ref.watch(openTodosProvider).value;
    final completed = ref.watch(completedTodosProvider).value;
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    final listCounts =
        ref.watch(todoOpenCountsByListProvider).value ?? const <String?, int>{};
    final settings = ref.watch(todoSettingsProvider);
    final view = _effectiveView(ref.watch(todoListsProvider).value);
    final today = _today;
    final headerHeight =
        MediaQuery.paddingOf(context).top + PageHeader.contentHeight;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final pageBgColor = AppPageBackdrop.pageColorOf(context);
    final listsById = <String, TodoListRow>{
      for (final list in lists) list.listId: list,
    };
    final counts = open == null
        ? const <TodoSmartView, int>{}
        : todoSmartViewCounts(open, today);

    String title() {
      final listId = view.listId;
      if (listId != null) return listsById[listId]?.name ?? l10n.navTodos;
      return TodoLabels.smartView(l10n, view.smart!);
    }

    void select(TodoView next) => setState(() => _view = next);

    Widget body(double width, {required bool wide}) {
      final scheme = Theme.of(context).colorScheme;
      final gutter = wide
          ? AppSpacing.l
          : AppContentWidth.gutter(width, AppContentWidth.reading);
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
      return CustomScrollView(
        slivers: <Widget>[
          // 窄窗口内容从页头下面滚过；宽窗口两栏整体已排在页头下方。
          if (!wide)
            SliverToBoxAdapter(
              child: SizedBox(height: headerHeight + kHomeTopContentGap),
            ),
          if (!wide)
            SliverToBoxAdapter(
              child: TodoViewStrip(
                view: view,
                lists: lists,
                counts: counts,
                listCounts: listCounts,
                onSelected: select,
                onCreateList: () => unawaited(_createList()),
              ),
            ),
          if (groups == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: DelayedLoadingIndicator(),
            )
          else if (groups.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyHint(
                icon: view.smart == null
                    ? FontAwesomeIcons.listCheck
                    : TodoLabels.smartViewIcon(view.smart!),
                message: switch (view.smart) {
                  TodoSmartView.today => l10n.todoEmptyToday,
                  TodoSmartView.completed => l10n.todoEmptyCompleted,
                  _ => l10n.todoEmptyList,
                },
              ),
            )
          else
            ...buildTodoListSlivers(
              groups: groups,
              listsById: listsById,
              showListOnRows: !view.isSingleList,
              reorderable:
                  view.isSingleList && settings.sort == TodoSortMode.manual,
              today: today,
              collapsed: _collapsed,
              onToggleCollapsed: (String key) => setState(
                () => _collapsed.contains(key)
                    ? _collapsed.remove(key)
                    : _collapsed.add(key),
              ),
              horizontalPadding: gutter,
              scheme: scheme,
              callbacks: TodoListCallbacks(
                onToggle: (TodoRow row) => unawaited(
                  toggleTodoDone(context, ref.read(appDatabaseProvider), row),
                ),
                onOpen: (TodoRow row) =>
                    unawaited(openTodoDetail(context, row.todoId)),
                onDelete: (TodoRow row) => unawaited(
                  deleteTodoWithUndo(
                    context,
                    ref.read(appDatabaseProvider),
                    row.todoId,
                  ),
                ),
                onReorder: _reorder,
                onReorderStart: _drag.start,
                onReorderEnd: _drag.dropped,
              ),
            ),
          // FAB 与玻璃底栏下方留出空间，最后一条能完整滚出来。
          SliverToBoxAdapter(child: SizedBox(height: 96 + bottomInset)),
        ],
      );
    }

    final menu = TodosPageMenu(
      view: view,
      settings: settings,
      completedInView: completed == null
          ? 0
          : countCompletedInView(view, completed),
      list: view.listId == null ? null : listsById[view.listId],
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(child: ColoredBox(color: pageBgColor)),
        SafeArea(
          top: false,
          bottom: false,
          child: WidthLayoutBuilder(
            builder: (BuildContext context, double width) {
              if (width < AppBreakpoints.expanded) {
                return body(width, wide: false);
              }
              return Padding(
                padding: EdgeInsets.only(
                  top: headerHeight + kHomeTopContentGap,
                  left: AppSpacing.l,
                  bottom: AppSpacing.l,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 280,
                      child: TodoSidebar(
                        view: view,
                        lists: lists,
                        counts: counts,
                        listCounts: listCounts,
                        onSelected: select,
                        onCreateList: () => unawaited(_createList()),
                        onManageLists: () =>
                            unawaited(openTodoListsManage(context)),
                      ),
                    ),
                    Expanded(child: body(width - 280, wide: true)),
                  ],
                ),
              );
            },
          ),
        ),
        PageHeader(
          title: title(),
          actions: <Widget>[
            // 宽窗口外壳没有全局 FAB（侧边栏的新建按钮写日记），新待办放在
            // 页头。
            if (HomeChromeScope.wideShellOf(context))
              IconButton(
                tooltip: l10n.todoNew,
                onPressed: () => unawaited(_create()),
                icon: const FaIcon(FontAwesomeIcons.plus, size: 18),
              ),
            IconButton(
              tooltip: l10n.todoSearchHint,
              onPressed: () => unawaited(openTodoSearch(context)),
              icon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 18),
            ),
            menu,
          ],
        ),
      ],
    );
  }
}
