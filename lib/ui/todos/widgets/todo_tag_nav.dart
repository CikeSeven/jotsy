import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/animated_rolling_text.dart';
import '../../widgets/expressive_state_blend.dart';
import '../models/todo_view.dart';
import 'todo_row_drag.dart';
import 'todo_view_hero.dart';

/// 视图面板与左栏里“标签”一组：组标题（带“管理”）+ 每个待办标签一行
/// （`tertiaryContainer` 方块里的 `tag` 图标 + 名称 + 未完成数，选中时
/// `secondaryContainer` 底，与清单行同一套）。没有标签时整组不出现。
///
/// 只列待办标签（与日记标签无关）；给了 [onDrop]（桌面）时每行接得住拖来
/// 的待办（加上这个标签）。
class TodoTagNavSection extends StatelessWidget {
  const TodoTagNavSection({
    super.key,
    required this.tags,
    required this.view,
    required this.onSelected,
    required this.onManage,
    this.onDrop,
    this.headerPadding = EdgeInsets.zero,
  });

  final List<TodoTagUsage> tags;
  final TodoView view;
  final ValueChanged<TodoView> onSelected;
  final VoidCallback onManage;
  final TodoViewDrop? onDrop;

  /// 组标题左右的留白（视图面板里与清单组标题对齐）。
  final EdgeInsets headerPadding;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: headerPadding,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.l,
              0,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.todoFieldTags,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onManage,
                  child: Text(l10n.todoListManageShort),
                ),
              ],
            ),
          ),
        ),
        for (final tag in tags)
          TodoDropTarget(
            onDrop: todoDropFor(onDrop, TodoView.tag(tag.name)),
            child: TodoTagNavRow(
              usage: tag,
              selected: view == TodoView.tag(tag.name),
              onTap: () => onSelected(TodoView.tag(tag.name)),
            ),
          ),
      ],
    );
  }
}

/// 一个待办标签的导航行。
class TodoTagNavRow extends StatelessWidget {
  const TodoTagNavRow({
    super.key,
    required this.usage,
    required this.selected,
    required this.onTap,
  });

  final TodoTagUsage usage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final open = usage.openCount;
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
              vertical: AppSpacing.s,
            ),
            child: Row(
              children: <Widget>[
                TodoIconBlock(
                  icon: FontAwesomeIcons.tag,
                  background: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Text(
                    usage.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (open > 0)
                  AnimatedRollingText(
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
          ),
        ),
      ),
    );
  }
}
