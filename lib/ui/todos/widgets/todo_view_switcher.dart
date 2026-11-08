import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../models/todo_view.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_labels.dart';

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

/// 窄窗口：页头下方一排可横向滚动的胶囊（智能视图在前，清单在后，末尾
/// “新建清单”）。桌面套 [DesktopHorizontalScroll]（鼠标拖动 / Shift+滚轮）。
class TodoViewStrip extends StatelessWidget {
  const TodoViewStrip({
    super.key,
    required this.view,
    required this.lists,
    required this.counts,
    required this.listCounts,
    required this.onSelected,
    required this.onCreateList,
  });

  final TodoView view;
  final List<TodoListRow> lists;
  final Map<TodoSmartView, int> counts;
  final Map<String?, int> listCounts;
  final ValueChanged<TodoView> onSelected;
  final VoidCallback onCreateList;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    String label(String name, int? count) =>
        count == null || count == 0 ? name : '$name $count';
    return SizedBox(
      height: 48,
      child: DesktopHorizontalScroll(
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          children: <Widget>[
            for (final smart in kTodoSmartViews)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
                child: Center(
                  child: ChoiceChip(
                    avatar: FaIcon(
                      TodoLabels.smartViewIcon(smart),
                      size: 13,
                      color: view.smart == smart
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    showCheckmark: false,
                    label: Text(
                      label(TodoLabels.smartView(l10n, smart), counts[smart]),
                    ),
                    selected: view.smart == smart,
                    onSelected: (_) => onSelected(TodoView.smart(smart)),
                  ),
                ),
              ),
            for (final list in lists)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
                child: Center(
                  child: ChoiceChip(
                    avatar: FaIcon(
                      TodoListStyle.iconOfRow(list),
                      size: 13,
                      color: TodoListStyle.accentOf(
                        list.colorKey,
                        scheme,
                      ).onContainer,
                    ),
                    showCheckmark: false,
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        label(list.name, listCounts[list.listId]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: view.listId == list.listId,
                    onSelected: (_) => onSelected(TodoView.list(list.listId)),
                  ),
                ),
              ),
            Center(
              child: ActionChip(
                avatar: FaIcon(
                  FontAwesomeIcons.plus,
                  size: 12,
                  color: scheme.primary,
                ),
                label: Text(l10n.todoListNew),
                onPressed: onCreateList,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 宽窗口（≥1024）：左栏的视图与清单，选中行以 `secondaryContainer` 高亮。
class TodoSidebar extends StatelessWidget {
  const TodoSidebar({
    super.key,
    required this.view,
    required this.lists,
    required this.counts,
    required this.listCounts,
    required this.onSelected,
    required this.onCreateList,
    required this.onManageLists,
  });

  final TodoView view;
  final List<TodoListRow> lists;
  final Map<TodoSmartView, int> counts;
  final Map<String?, int> listCounts;
  final ValueChanged<TodoView> onSelected;
  final VoidCallback onCreateList;
  final VoidCallback onManageLists;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget row({
      required FaIconData icon,
      required Color iconColor,
      required String title,
      required bool selected,
      required VoidCallback onTap,
      int? count,
    }) {
      return ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: scheme.secondaryContainer,
        selectedColor: scheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: FaIcon(icon, size: 16, color: iconColor),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: count == null || count == 0
            ? null
            : Text('$count', style: theme.textTheme.labelMedium),
        onTap: onTap,
      );
    }

    return AppCardSurface(
      shadow: false,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s),
        children: <Widget>[
          for (final smart in kTodoSmartViews)
            row(
              icon: TodoLabels.smartViewIcon(smart),
              iconColor: scheme.primary,
              title: TodoLabels.smartView(l10n, smart),
              selected: view.smart == smart,
              count: counts[smart],
              onTap: () => onSelected(TodoView.smart(smart)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.todoListsSection,
                    style: AppPageBackdrop.onBackgroundTextStyle(
                      context,
                      theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.todoListManage,
                  onPressed: onManageLists,
                  icon: const FaIcon(FontAwesomeIcons.sliders, size: 14),
                ),
              ],
            ),
          ),
          for (final list in lists)
            row(
              icon: TodoListStyle.iconOfRow(list),
              iconColor: TodoListStyle.accentOf(
                list.colorKey,
                scheme,
              ).onContainer,
              title: list.name,
              selected: view.listId == list.listId,
              count: listCounts[list.listId],
              onTap: () => onSelected(TodoView.list(list.listId)),
            ),
          row(
            icon: FontAwesomeIcons.plus,
            iconColor: scheme.primary,
            title: l10n.todoListNew,
            selected: false,
            onTap: onCreateList,
          ),
        ],
      ),
    );
  }
}
