import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/page_header.dart';
import '../controllers/todo_navigation.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import 'todos_page_menu.dart';

/// 待办页的页头（[PageHeader]，叠在列表之上）：标题为当前视图名，换视图
/// 时朝 [titleDirection] 滑换（与列表的退场 / 入场同一方向）。
///
/// 窄窗口（[narrow]，按页面实际可用宽度判断）标题后带 `angleDown`、整体可点
/// 弹出视图面板（[onOpenViews]）；宽窗口有左栏，标题不带箭头、不可点。
/// 右侧依次为：宽窗口外壳（没有全局 FAB）的“新待办”、搜索、“更多”。
class TodosPageHeader extends StatelessWidget {
  const TodosPageHeader({
    super.key,
    required this.view,
    required this.title,
    this.titleDirection = 0,
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

  /// 上一次换视图的方向：+1 新标题从右边进来，-1 从左边，0 只淡入淡出。
  final int titleDirection;
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
      titleChild: _SlidingTitle(title: title, direction: titleDirection),
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

/// 视图名：换视图时新旧标题朝 [direction] 交替滑过（新标题从那一侧进来、
/// 旧标题往另一侧出去），与列表退场 / 入场同时长、同方向；方向为 0 时只
/// 淡入淡出。新旧标题都贴着起始边叠放：长短不同时下拉箭头不会先居中再
/// 跳回。字样继承页头标题（DefaultTextStyle）。减少动画时直接换字。
class _SlidingTitle extends StatelessWidget {
  const _SlidingTitle({required this.title, required this.direction});

  final String title;
  final int direction;

  @override
  Widget build(BuildContext context) {
    final currentKey = ValueKey<String>(title);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) =>
            Stack(
              alignment: AlignmentDirectional.centerStart,
              children: <Widget>[...previousChildren, ?currentChild],
            ),
        transitionBuilder: (Widget child, Animation<double> animation) {
          // 离开的标题动画从 1 倒放到 0，起点取反方向即向另一侧滑出。
          final incoming = child.key == currentKey;
          final dx = 0.3 * (incoming ? direction : -direction);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(dx, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Text(title, key: currentKey),
      ),
    );
  }
}
