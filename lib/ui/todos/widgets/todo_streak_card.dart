import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/animated_rolling_text.dart';
import '../providers/todo_providers.dart';
import '../sections/todo_detail_parts.dart';
import '../viewmodels/todo_streak.dart';
import 'todo_streak_grid.dart';

/// 重复待办详情里的“坚持记录”卡：一句“累计 N 次 · 准时连续 M 次”（数字
/// 逐位滚动）与满宽自适应完成热力图（[TodoStreakGrid]）。原待办与已完成副
/// 本的详情共用这一张卡，数据来自这串的完成记录（[todoOccurrencesProvider]），
/// 有限次数 / 截止日重复的最后一次直接完成在原待办上时由 [masterRow] 一并
/// 纳入统计。
class TodoStreakCard extends ConsumerWidget {
  const TodoStreakCard({
    super.key,
    required this.todoId,
    required this.today,
    this.masterRow,
  });

  /// 整串重复待办的原待办业务 id。
  final String todoId;
  final DateTime today;

  /// 原待办行（可选）；若其本身已完成（有限重复的最后一次），一并计入统计。
  final TodoRow? masterRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final occurrences = ref.watch(todoOccurrencesProvider(todoId)).value;
    if (occurrences == null) return const SizedBox.shrink();
    final summaryStreak = TodoStreak.build(
      occurrences,
      today,
      masterRow: masterRow,
    );
    return TodoDetailSectionCard(
      title: l10n.todoStreakTitle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.m,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AnimatedRollingText(
              l10n.todoStreakSummary(summaryStreak.total, summaryStreak.streak),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const gap = TodoStreakGrid.defaultGap;
                const labelWidth = TodoStreakGrid.defaultLabelWidth;
                final maxWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 300.0;
                final available = math.max(120.0, maxWidth - labelWidth);
                final weeks = TodoStreak.weeksForWidth(available, gap: gap);
                final fitted = (available - gap * (weeks - 1)) / weeks;
                final cell = fitted.clamp(
                  TodoStreakGrid.minCell,
                  TodoStreakGrid.maxCell,
                );
                final streak = weeks == summaryStreak.weeks
                    ? summaryStreak
                    : TodoStreak.build(
                        occurrences,
                        today,
                        weeks: weeks,
                        masterRow: masterRow,
                      );
                return TodoStreakGrid(
                  streak: streak,
                  cell: cell,
                  gap: gap,
                  labelWidth: labelWidth,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
