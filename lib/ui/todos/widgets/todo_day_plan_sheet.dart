import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_day_plan.dart';
import 'todo_due_sheet.dart';
import 'todo_labels.dart';
import 'todo_sheet.dart';

/// “规划今天”面板（今天视图概览卡上的按钮打开，不自动弹出）：按
/// [TodoDayPlan] 分组列出值得今天看一眼的待办——已逾期、快到期了、重要但
/// 没日期、最近添加——每行可“加到今天”（保留原来的时刻）、改期（改期面板）
/// 或完成，点了就写库。面板跟着数据走：安排过的行从面板里收走，都安排完时
/// 写“没有要安排的了”。推迟过 [TodoDayPlan.postponeHintAt] 次及以上的行
/// 多一句提示。
Future<void> showTodoDayPlanSheet(BuildContext context) {
  return showTodoSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => const _DayPlanBody(),
  );
}

class _DayPlanBody extends ConsumerWidget {
  const _DayPlanBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todoTodayProvider);
    final open = ref.watch(openTodosProvider).value ?? const <TodoRow>[];
    final plan = TodoDayPlan.build(open, today);
    final children = <Widget>[];
    if (plan.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(
            child: Text(
              l10n.todoPlanEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    for (final MapEntry(key: section, value: rows) in plan.sections.entries) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.xs,
          ),
          child: Text(
            switch (section) {
              TodoPlanSection.overdue => l10n.todoPlanOverdue,
              TodoPlanSection.soon => l10n.todoPlanSoon,
              TodoPlanSection.important => l10n.todoPlanImportant,
              TodoPlanSection.recent => l10n.todoPlanRecent,
            },
            style: theme.textTheme.labelLarge?.copyWith(
              color: section == TodoPlanSection.overdue
                  ? scheme.error
                  : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      for (final row in rows) {
        children.add(
          _PlanRow(key: ValueKey<String>(row.todoId), row: row, today: today),
        );
      }
    }
    return TodoSheetBody(
      title: l10n.todoPlanToday,
      children: <Widget>[
        AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.spatial,
          alignment: AlignmentDirectional.topStart,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _PlanRow extends ConsumerWidget {
  const _PlanRow({super.key, required this.row, required this.today});

  final TodoRow row;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final database = ref.read(appDatabaseProvider);
    final due = TodoLabels.dueOfRow(context, row, today);
    final postponed = todoPostponeCount(row);
    final subtitle =
        due ??
        l10n.todoPlanAddedOn(
          TodoLabels.relativeDay(
            l10n,
            DateTime(
              row.createdAt.year,
              row.createdAt.month,
              row.createdAt.day,
            ),
            today,
          ),
        );

    Future<void> reschedule() async {
      final text = row.dueDate;
      final choice = await showTodoDueSheet(
        context,
        date: text == null ? null : parseAnniversaryDate(text),
        minute: row.dueMinute,
        today: today,
      );
      if (choice == null) return;
      await database.setTodoDue(
        row.todoId,
        date: choice.date,
        minute: choice.minute,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    row.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (postponed >= TodoDayPlan.postponeHintAt)
                    Text(
                      l10n.todoPlanPostponedHint(postponed),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.tertiary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.todoPlanAddToToday,
            onPressed: () => unawaited(
              database.setTodoDue(
                row.todoId,
                date: today,
                minute: row.dueMinute,
              ),
            ),
            icon: FaIcon(
              FontAwesomeIcons.solidSun,
              size: 16,
              color: scheme.primary,
            ),
          ),
          IconButton(
            tooltip: l10n.todoReschedule,
            onPressed: () => unawaited(reschedule()),
            icon: const FaIcon(FontAwesomeIcons.calendarDay, size: 16),
          ),
          IconButton(
            tooltip: l10n.todoMarkDone,
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              unawaited(database.completeTodo(row.todoId));
            },
            icon: const FaIcon(FontAwesomeIcons.check, size: 16),
          ),
        ],
      ),
    );
  }
}
