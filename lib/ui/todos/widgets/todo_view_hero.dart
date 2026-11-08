import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../models/todo_view.dart';
import '../viewmodels/todo_groups.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_labels.dart';
import 'todo_progress_ring.dart';

/// 待办列表顶部的概览卡（卡片表面、24 圆角、无投影），按视图换内容：
///
/// - 今天：眉线“周六 · 11月8日”（`labelLarge` w600 `primary`）、主句“还有
///   3 件”（`headlineSmall` w800；做完了 / 没有安排各有说法）、副句逾期与
///   已完成的胶囊，右侧 56dp 进度环（今天完成 / 今天全部）；
/// - 清单与收集箱：44dp 强调色图标块 + 名称 + “已完成 4 / 9”，下方 6dp 进度
///   条；清单行尾有编辑按钮（[onEditList]）；
/// - 其他智能视图：图标块 + 名称 + 未完成数（已完成视图为最近完成的条数）。
///
/// 只展示，数字由页面算好传入（[summary]、[progress]、[count]）。
class TodoViewHero extends StatelessWidget {
  const TodoViewHero({
    super.key,
    required this.view,
    required this.today,
    required this.summary,
    required this.count,
    this.list,
    this.progress,
    this.onEditList,
  });

  final TodoView view;
  final DateTime today;

  /// “今天”的数字（只在今天视图用）。
  final TodoTodaySummary summary;

  /// 其他智能视图的条数。
  final int count;

  /// 清单视图的清单（收集箱为 null）。
  final TodoListRow? list;

  /// 清单 / 收集箱的完成进度。
  final TodoListProgress? progress;
  final VoidCallback? onEditList;

  @override
  Widget build(BuildContext context) {
    final smart = view.smart;
    final Widget child;
    if (smart == TodoSmartView.today) {
      child = _TodayHero(today: today, summary: summary);
    } else if (view.isSingleList) {
      child = _ListHero(
        list: list,
        progress: progress ?? TodoListProgress.empty,
        onEdit: onEditList,
      );
    } else {
      child = _SmartHero(view: smart!, count: count);
    }
    return AppCardSurface(
      shadow: false,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
      ),
      child: child,
    );
  }
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.today, required this.summary});

  final DateTime today;
  final TodoTodaySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final headline = summary.remaining > 0
        ? l10n.todoHeroRemaining(summary.remaining)
        : summary.doneToday > 0
        ? l10n.todoHeroAllDone
        : l10n.todoHeroNothing;
    final chips = <Widget>[
      if (summary.overdue > 0)
        _HeroChip(
          text: l10n.todoHeroOverdue(summary.overdue),
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
        ),
      if (summary.doneToday > 0)
        _HeroChip(
          text: l10n.todoHeroDone(summary.doneToday),
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
        ),
    ];
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.todoHeroDate(
                  TodoLabels.weekdayName(l10n, today.weekday, short: false),
                  l10n.formatMonthDay(today),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (chips.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.s),
                Wrap(spacing: 6, runSpacing: 4, children: chips),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        TodoProgressRing(
          fraction: summary.fraction,
          color: scheme.primary,
          track: scheme.surfaceContainerHighest,
          center: Text(
            '${summary.doneToday}/${summary.total}',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _ListHero extends StatelessWidget {
  const _ListHero({
    required this.list,
    required this.progress,
    required this.onEdit,
  });

  final TodoListRow? list;
  final TodoListProgress progress;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final list = this.list;
    final (Color container, Color onContainer) = list == null
        ? TodoLabels.smartViewColors(scheme, TodoSmartView.inbox)
        : () {
            final accent = TodoListStyle.accentOf(list.colorKey, scheme);
            return (accent.container, accent.onContainer);
          }();
    final edit = onEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            TodoIconBlock(
              icon: list == null
                  ? TodoLabels.smartViewIcon(TodoSmartView.inbox)
                  : TodoListStyle.iconOfRow(list),
              background: container,
              foreground: onContainer,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    list?.name ?? l10n.todoViewInbox,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    l10n.todoHeroListProgress(progress.done, progress.total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (edit != null)
              IconButton(
                tooltip: l10n.todoListEdit,
                onPressed: edit,
                icon: const FaIcon(FontAwesomeIcons.pen, size: 15),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        TodoProgressBar(
          fraction: progress.fraction,
          color: list == null ? scheme.primary : onContainer,
          track: list == null ? scheme.surfaceContainerHigh : container,
        ),
      ],
    );
  }
}

class _SmartHero extends StatelessWidget {
  const _SmartHero({required this.view, required this.count});

  final TodoSmartView view;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color container, Color onContainer) = TodoLabels.smartViewColors(
      scheme,
      view,
    );
    return Row(
      children: <Widget>[
        TodoIconBlock(
          icon: TodoLabels.smartViewIcon(view),
          background: container,
          foreground: onContainer,
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                TodoLabels.smartView(l10n, view),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                view == TodoSmartView.completed
                    ? l10n.todoHeroCompletedCount(count)
                    : l10n.todoHeroOpenCount(count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 圆角方块里的图标（概览卡 44dp、视图面板与侧栏的小尺寸共用）。
class TodoIconBlock extends StatelessWidget {
  const TodoIconBlock({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 44,
  });

  final FaIconData icon;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: FaIcon(icon, size: size * 0.4, color: foreground),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
