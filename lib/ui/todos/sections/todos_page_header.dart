import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/page_header.dart';
import '../controllers/todo_navigation.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import 'todos_page_menu.dart';

/// 待办页的页头（[PageHeader]，叠在列表之上）：标题为当前视图名。
///
/// 窄窗口（[narrow]，按页面实际可用宽度判断）标题后带 `angleDown`、整体可点
/// 弹出视图面板（[onOpenViews]）；宽窗口有左栏，标题不带箭头、不可点。
/// 右侧依次为：宽窗口外壳（没有全局 FAB）的“新待办”、搜索、“更多”。
class TodosPageHeader extends StatelessWidget {
  const TodosPageHeader({
    super.key,
    required this.view,
    required this.title,
    required this.narrow,
    required this.wideShell,
    required this.settings,
    required this.completedInView,
    required this.list,
    required this.onOpenViews,
    required this.onCreate,
  });

  final TodoView view;
  final String title;
  final bool narrow;
  final bool wideShell;
  final TodoSettings settings;
  final int completedInView;

  /// 当前是清单视图时的清单。
  final TodoListRow? list;
  final VoidCallback onOpenViews;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageHeader(
      title: title,
      titleTrailing: narrow
          ? FaIcon(
              FontAwesomeIcons.angleDown,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
      onTitleTap: narrow ? onOpenViews : null,
      titleTooltip: narrow ? l10n.todoViewSheetTitle : null,
      actions: <Widget>[
        if (wideShell)
          IconButton(
            tooltip: l10n.todoNew,
            onPressed: onCreate,
            icon: const FaIcon(FontAwesomeIcons.plus, size: 18),
          ),
        IconButton(
          tooltip: l10n.todoSearchHint,
          onPressed: () => unawaited(openTodoSearch(context)),
          icon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 18),
        ),
        TodosPageMenu(
          view: view,
          settings: settings,
          completedInView: completedInView,
          list: list,
        ),
      ],
    );
  }
}
