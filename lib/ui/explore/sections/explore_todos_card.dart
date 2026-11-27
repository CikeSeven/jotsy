import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_glass_field.dart';
import '../../todos/providers/todo_providers.dart';
import '../../todos/viewmodels/todo_groups.dart';
import '../../todos/viewmodels/todo_review_stats.dart';
import '../../todos/widgets/todo_review_summary.dart';
import '../controllers/explore_module_actions.dart';
import '../widgets/explore_shared_widgets.dart';

/// 探索页的“待办”卡（只在待办功能开启时出现）：今天还有几件，下面是与
/// 已完成视图同一份回顾（本周完成、连续天数、最近 7 天的迷你柱），“打开
/// 待办”切到待办 Tab（[ExploreModuleActions.openTodos]）。只在这张卡显示时
/// 订阅待办数据。
class ExploreTodosCard extends ConsumerWidget {
  const ExploreTodosCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final actions = ExploreActionsScope.of(context);
    final today = ref.watch(todoTodayProvider);
    final open = ref.watch(openTodosProvider).value;
    final completed = ref.watch(completedTodosProvider).value;
    final summary = open == null || completed == null
        ? null
        : todoTodaySummary(open, completed, today);
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreCardHeader(
            icon: FontAwesomeIcons.solidSquareCheck,
            title: l10n.exploreModuleTodos,
          ),
          if (summary != null)
            Text(
              summary.remaining > 0
                  ? l10n.todoHeroRemaining(summary.remaining)
                  : summary.doneToday > 0
                  ? l10n.todoHeroAllDone
                  : l10n.todoHeroNothing,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          if (completed != null) ...<Widget>[
            const SizedBox(height: 12),
            TodoReviewSummary(
              stats: TodoReviewStats.build(completed, today),
              today: today,
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            style: AppGlassField.tonalButtonStyle(context),
            onPressed: actions.openTodos,
            icon: const FaIcon(FontAwesomeIcons.listCheck, size: 14),
            label: Text(l10n.exploreTodosOpen),
          ),
        ],
      ),
    );
  }
}
