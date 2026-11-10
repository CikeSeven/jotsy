import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_list_actions.dart';
import '../controllers/todo_navigation.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_labels.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';

/// 视图 [view] 里已完成的条数（“清除已完成”用）：已完成视图为全部，清单与
/// 收集箱为其中已完成的，其余视图没有已完成的可清。
int countCompletedInView(TodoView view, List<TodoRow> completed) {
  if (view.smart == TodoSmartView.completed) return completed.length;
  if (!view.isSingleList) return 0;
  return completed.where((row) => row.listId == view.listId).length;
}

/// 待办页头的“更多”（⋮）：弹出菜单（用户要求由底部面板改来，与日记页的
/// “更多”一致），按分隔线分三组：
/// - 排序方式 ›（“已完成”视图没有，那里按完成日期排）、显示 / 隐藏已完成
///   （清单视图）、清除已完成（当前视图有已完成的才出现）；
/// - 编辑清单、删除清单（清单视图）；
/// - 管理清单。
///
/// 排序在二级菜单里：点了即生效、菜单保持打开、对勾随之移动（选中态由二级
/// 菜单页自己维护，初值取展开时的设置，二级菜单的内容在展开时取定）。其余
/// 都是动作，点按先关菜单再执行。
class TodosPageMenu extends ConsumerWidget {
  const TodosPageMenu({
    super.key,
    required this.view,
    required this.settings,
    required this.completedInView,
    this.list,
  });

  final TodoView view;
  final TodoSettings settings;
  final int completedInView;

  /// 当前是清单视图时的清单。
  final TodoListRow? list;

  Future<void> _save(WidgetRef ref, TodoSettings next) async {
    final service = ref.read(settingsServiceProvider).asData?.value;
    if (service != null) await saveTodoSettings(service, next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final list = this.list;
    final first = <Widget>[
      if (view.smart != TodoSmartView.completed)
        ExpressiveSubmenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.arrowDownWideShort),
          menuChildren: <Widget>[
            _TodoSortMenuPage(
              initial: settings.sort,
              // 设置可能在二级菜单打开期间被别处改过：以最新读到的为准，
              // 只换排序这一项。
              onChanged: (TodoSortMode mode) {
                final latest = ref.read(todoSettingsProvider);
                unawaited(_save(ref, latest.copyWith(sort: mode)));
              },
            ),
          ],
          child: Text(l10n.todoSortTitle),
        ),
      if (view.isSingleList)
        ExpressiveMenuItem(
          leadingIcon: FaIcon(
            settings.showCompleted
                ? FontAwesomeIcons.eyeSlash
                : FontAwesomeIcons.eye,
          ),
          onPressed: () => unawaited(
            _save(
              ref,
              settings.copyWith(showCompleted: !settings.showCompleted),
            ),
          ),
          child: Text(
            settings.showCompleted
                ? l10n.todoHideCompleted
                : l10n.todoShowCompleted,
          ),
        ),
      if (completedInView > 0)
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.broom),
          destructive: true,
          onPressed: () => unawaited(
            clearCompletedTodos(
              context,
              ref.read(appDatabaseProvider),
              count: completedInView,
              listId: view.listId,
              allLists: view.smart == TodoSmartView.completed,
            ),
          ),
          child: Text(l10n.todoClearCompleted),
        ),
    ];
    final listItems = <Widget>[
      if (list != null) ...<Widget>[
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.pen),
          onPressed: () => unawaited(editTodoListFlow(context, ref, list)),
          child: Text(l10n.todoListEdit),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
          destructive: true,
          onPressed: () => unawaited(deleteTodoListFlow(context, ref, list)),
          child: Text(l10n.todoListDelete),
        ),
      ],
    ];
    final manage = ExpressiveMenuItem(
      leadingIcon: const FaIcon(FontAwesomeIcons.sliders),
      onPressed: () => unawaited(openTodoListsManage(context)),
      child: Text(l10n.todoListManage),
    );
    final groups = <List<Widget>>[
      first,
      listItems,
      <Widget>[manage],
    ].where((List<Widget> group) => group.isNotEmpty).toList();
    return ExpressiveMenuButton(
      tooltip: l10n.todoMore,
      icon: const FaIcon(FontAwesomeIcons.ellipsis, size: 18),
      items: <Widget>[
        for (final (index, group) in groups.indexed) ...<Widget>[
          if (index > 0) const ExpressiveMenuDivider(),
          ...group,
        ],
      ],
    );
  }
}

/// “排序方式”二级菜单：四种排序，点了即生效、菜单保持打开。
class _TodoSortMenuPage extends StatefulWidget {
  const _TodoSortMenuPage({required this.initial, required this.onChanged});

  final TodoSortMode initial;
  final ValueChanged<TodoSortMode> onChanged;

  @override
  State<_TodoSortMenuPage> createState() => _TodoSortMenuPageState();
}

class _TodoSortMenuPageState extends State<_TodoSortMenuPage> {
  late TodoSortMode _mode = widget.initial;

  void _select(TodoSortMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    widget.onChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListBody(
      children: <Widget>[
        for (final mode in TodoSortMode.values)
          ExpressiveMenuItem(
            closeOnActivate: false,
            selected: mode == _mode,
            onPressed: () => _select(mode),
            child: Text(TodoLabels.sortMode(l10n, mode)),
          ),
      ],
    );
  }
}
