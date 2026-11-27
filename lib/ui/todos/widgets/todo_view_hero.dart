import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../widgets/animated_rolling_text.dart';
import '../models/todo_view.dart';
import '../viewmodels/todo_groups.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_labels.dart';
import 'todo_progress_ring.dart';
import 'todo_today_hero.dart';

/// 待办列表顶部的概览卡（卡片表面、24 圆角、无投影），按视图换内容：
///
/// - 今天：眉线“周六 · 11月8日”（`labelLarge` w600 `primary`）、主句“还有
///   3 件”（`headlineSmall` w800；做完了 / 没有安排各有说法）、副句逾期与
///   已完成的胶囊，右侧 56dp 进度环（今天完成 / 今天全部）；
/// - 清单与收集箱：44dp 强调色图标块 + 名称 + “已完成 4 / 9”，下方 6dp 进度
///   条；清单行尾有编辑按钮（[onEditList]）；
/// - 其他智能视图：图标块 + 名称 + 未完成数（已完成视图为最近完成的条数）。
///
/// 只展示，数字由页面算好传入（[summary]、[progress]、[count]）。数字变化
/// 时逐位滚动（[AnimatedRollingText]），逾期 / 已完成胶囊出现或消失时卡片
/// 高度按弹簧过渡，下面的列表跟着平滑让开。
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
    this.onPlanToday,
    this.footer,
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

  /// 今天视图：有可规划的待办时“规划今天”按钮（null 时不显示）。
  final VoidCallback? onPlanToday;

  /// 智能视图卡片的下半部：计划视图为一周日期条，已完成视图为回顾。
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final smart = view.smart;
    final Widget child;
    if (smart == TodoSmartView.today) {
      child = TodoTodayHero(
        today: today,
        summary: summary,
        onPlan: onPlanToday,
      );
    } else if (view.isSingleList) {
      child = _ListHero(
        list: list,
        progress: progress ?? TodoListProgress.empty,
        onEdit: onEditList,
      );
    } else {
      final strip = footer;
      child = strip == null
          ? _SmartHero(view: smart, tag: view.tag, count: count)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SmartHero(view: smart, tag: view.tag, count: count),
                const SizedBox(height: AppSpacing.m),
                strip,
              ],
            );
    }
    return AppCardSurface(
      shadow: false,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
      ),
      child: AnimatedSize(
        // AnimatedSize 不接受 0 时长（见 durationNonZero）。
        duration: ExpressiveMotion.durationNonZero(
          context,
          ExpressiveMotion.medium,
        ),
        curve: ExpressiveMotion.spatial,
        alignment: AlignmentDirectional.topStart,
        child: child,
      ),
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
                  AnimatedRollingText.sentence(
                    l10n.todoHeroListProgress(progress.done, progress.total),
                    number: progress.done,
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

/// 智能视图与标签视图的概览：图标方块 + 名称 + 一句条数（数字逐位滚动）。
/// [view] 为 null 时是标签视图（`tag` 图标、`tertiaryContainer`，名称为
/// [tag]）。
class _SmartHero extends StatelessWidget {
  const _SmartHero({required this.view, required this.count, this.tag});

  final TodoSmartView? view;
  final String? tag;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = this.view;
    final (Color container, Color onContainer) = view == null
        ? (scheme.tertiaryContainer, scheme.onTertiaryContainer)
        : TodoLabels.smartViewColors(scheme, view);
    return Row(
      children: <Widget>[
        TodoIconBlock(
          icon: view == null
              ? FontAwesomeIcons.tag
              : TodoLabels.smartViewIcon(view),
          background: container,
          foreground: onContainer,
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                view == null ? tag ?? '' : TodoLabels.smartView(l10n, view),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              AnimatedRollingText.sentence(
                view == TodoSmartView.completed
                    ? l10n.todoHeroCompletedCount(count)
                    : l10n.todoHeroOpenCount(count),
                number: count,
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
