import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../widgets/expressive_state_blend.dart';
import '../models/todo_view.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_labels.dart';
import 'todo_progress_ring.dart';
import 'todo_view_hero.dart';

/// 待办页可切换的视图：智能视图（今天 / 计划 / 重要 / 全部 / 收集箱 /
/// 已完成）与各清单。
const List<TodoSmartView> kTodoSmartViews = <TodoSmartView>[
  TodoSmartView.today,
  TodoSmartView.planned,
  TodoSmartView.important,
  TodoSmartView.all,
  TodoSmartView.inbox,
  TodoSmartView.completed,
];

/// 智能视图的网格（视图面板 3 列、宽窗口侧栏 2 列）：每格 16 圆角，左上
/// 语义容器色的图标圆、右上未完成数（`titleLarge` w800 等宽数字，已完成与
/// 0 不显示），底部名称。当前视图的格子底色 `secondaryContainer`、描边
/// `secondary`，经 [ExpressiveStateBlend] 补间。
class TodoSmartViewGrid extends StatelessWidget {
  const TodoSmartViewGrid({
    super.key,
    required this.view,
    required this.counts,
    required this.columns,
    required this.onSelected,
  });

  final TodoView view;
  final Map<TodoSmartView, int> counts;
  final int columns;
  final ValueChanged<TodoView> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const gap = AppSpacing.s;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final smart in kTodoSmartViews)
              SizedBox(
                width: width.floorToDouble(),
                child: _SmartViewTile(
                  view: smart,
                  count: smart == TodoSmartView.completed
                      ? null
                      : counts[smart],
                  selected: view.smart == smart,
                  onTap: () => onSelected(TodoView.smart(smart)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SmartViewTile extends StatelessWidget {
  const _SmartViewTile({
    required this.view,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final TodoSmartView view;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color container, Color onContainer) = TodoLabels.smartViewColors(
      scheme,
      view,
    );
    final radius = BorderRadius.circular(AppRadii.input);
    final count = this.count;
    return Semantics(
      selected: selected,
      button: true,
      child: ExpressiveStateBlend(
        active: selected,
        builder: (BuildContext context, double t, Widget? child) => Material(
          color: Color.lerp(
            scheme.surfaceContainerLow,
            scheme.secondaryContainer,
            t,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: Color.lerp(
                ExpressiveSurfaces.cardBorderColor(scheme),
                scheme.secondary,
                t,
              )!,
              width: 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.s + 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: container,
                        shape: BoxShape.circle,
                      ),
                      child: FaIcon(
                        TodoLabels.smartViewIcon(view),
                        size: 14,
                        color: onContainer,
                      ),
                    ),
                    const Spacer(),
                    if (count != null && count > 0)
                      Text(
                        '$count',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  TodoLabels.smartView(l10n, view),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 一个清单的导航行：28dp 强调色图标块、名称（省略）、未完成数，下方 4dp
/// 进度条（已完成 / 全部）。选中时底色 `secondaryContainer`（补间）。
class TodoListNavRow extends StatelessWidget {
  const TodoListNavRow({
    super.key,
    required this.list,
    required this.progress,
    required this.selected,
    required this.onTap,
  });

  final TodoListRow list;
  final TodoListProgress? progress;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = TodoListStyle.accentOf(list.colorKey, scheme);
    final progress = this.progress;
    final open = progress?.open ?? 0;
    return Semantics(
      selected: selected,
      button: true,
      child: ExpressiveStateBlend(
        active: selected,
        builder: (BuildContext context, double t, Widget? child) => Material(
          color: scheme.secondaryContainer.withValues(alpha: t),
          borderRadius: BorderRadius.circular(AppRadii.input),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s + 2,
            ),
            child: Row(
              children: <Widget>[
                TodoIconBlock(
                  icon: TodoListStyle.iconOfRow(list),
                  background: accent.container,
                  foreground: accent.onContainer,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              list.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (open > 0)
                            Text(
                              '$open',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TodoProgressBar(
                        fraction: progress?.fraction ?? 0,
                        color: accent.onContainer,
                        track: accent.container,
                        height: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 视图面板与侧栏里“我的清单”的小标题：名称 + 右侧“管理”。
class TodoListsSectionHeader extends StatelessWidget {
  const TodoListsSectionHeader({super.key, required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.l,
        0,
        AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.todoListsSection,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: onManage,
            child: Text(l10n.todoListManageShort),
          ),
        ],
      ),
    );
  }
}

/// “新建清单”行（视图面板与侧栏末尾）。
class TodoNewListRow extends StatelessWidget {
  const TodoNewListRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.input),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 32,
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.plus,
                  size: 14,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Text(
              context.l10n.todoListNew,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 宽窗口（≥1024）左栏：2 列智能视图网格 + 清单（各带进度条）+ 新建清单。
class TodoSidebar extends StatelessWidget {
  const TodoSidebar({
    super.key,
    required this.view,
    required this.lists,
    required this.counts,
    required this.progress,
    required this.onSelected,
    required this.onCreateList,
    required this.onManageLists,
  });

  final TodoView view;
  final List<TodoListRow> lists;
  final Map<TodoSmartView, int> counts;
  final Map<String?, TodoListProgress> progress;
  final ValueChanged<TodoView> onSelected;
  final VoidCallback onCreateList;
  final VoidCallback onManageLists;

  @override
  Widget build(BuildContext context) {
    return AppCardSurface(
      shadow: false,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: <Widget>[
          TodoSmartViewGrid(
            view: view,
            counts: counts,
            columns: 2,
            onSelected: onSelected,
          ),
          TodoListsSectionHeader(onManage: onManageLists),
          for (final list in lists)
            TodoListNavRow(
              list: list,
              progress: progress[list.listId],
              selected: view.listId == list.listId,
              onTap: () => onSelected(TodoView.list(list.listId)),
            ),
          TodoNewListRow(onTap: onCreateList),
        ],
      ),
    );
  }
}
