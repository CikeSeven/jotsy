import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/animated_rolling_text.dart';
import '../providers/todo_providers.dart';
import '../sections/todo_detail_parts.dart';
import '../viewmodels/todo_streak.dart';

/// 重复待办详情里的“坚持记录”卡：一句“累计 N 次 · 准时连续 M 次”（数字
/// 逐位滚动）与最近 12 周的完成格（[TodoStreakGrid]）。数据来自这串的
/// 完成记录（[todoOccurrencesProvider]），算法见 [TodoStreak]。
class TodoStreakCard extends ConsumerWidget {
  const TodoStreakCard({super.key, required this.todoId, required this.today});

  final String todoId;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final occurrences = ref.watch(todoOccurrencesProvider(todoId)).value;
    if (occurrences == null) return const SizedBox.shrink();
    final streak = TodoStreak.build(occurrences, today);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AnimatedRollingText(
              l10n.todoStreakSummary(streak.total, streak.streak),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Semantics(
              label: l10n.todoStreakGridLabel(streak.weeks),
              excludeSemantics: true,
              child: TodoStreakGrid(streak: streak),
            ),
          ],
        ),
      ),
    );
  }
}

/// 完成格：一列一周（从早到晚）、一行一天（周一在上），12dp 圆角方格、
/// 间隔 3dp。没完成为 `surfaceContainerHighest`，完成一次为半透明
/// `primary`、两次及以上为实色，还没到的日子不画。第一次出现时按列错峰
/// 从中心长出来（`long`，减少动画时直接画满）。
class TodoStreakGrid extends StatefulWidget {
  const TodoStreakGrid({super.key, required this.streak});

  final TodoStreak streak;

  static const double cell = 12;
  static const double gap = 3;

  @override
  State<TodoStreakGrid> createState() => _TodoStreakGridState();
}

class _TodoStreakGridState extends State<TodoStreakGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_grow.isAnimating || _grow.value > 0) return;
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.long);
    if (duration == Duration.zero) {
      _grow.value = 1;
    } else {
      _grow
        ..duration = duration
        ..forward();
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weeks = widget.streak.weeks;
    const step = TodoStreakGrid.cell + TodoStreakGrid.gap;
    return SizedBox(
      width: weeks * step - TodoStreakGrid.gap,
      height: 7 * step - TodoStreakGrid.gap,
      child: CustomPaint(
        painter: _GridPainter(
          days: widget.streak.days,
          weeks: weeks,
          grow: _grow,
          empty: scheme.surfaceContainerHighest,
          done: scheme.primary,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.days,
    required this.weeks,
    required this.grow,
    required this.empty,
    required this.done,
  }) : super(repaint: grow);

  final List<int> days;
  final int weeks;
  final Animation<double> grow;
  final Color empty;
  final Color done;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = TodoStreakGrid.cell;
    const step = cell + TodoStreakGrid.gap;
    final paint = Paint();
    final t = grow.value;
    for (var i = 0; i < days.length; i++) {
      final count = days[i];
      if (count < 0) continue;
      final week = i ~/ 7;
      final day = i % 7;
      // 每列晚一点开始，最后一列在 t = 1 时长满。
      final start = weeks <= 1 ? 0.0 : week / (weeks - 1) * 0.6;
      final progress = ExpressiveMotion.spatial.transform(
        ((t - start) / 0.4).clamp(0.0, 1.0),
      );
      if (progress <= 0) continue;
      final side = cell * progress;
      final center = Offset(week * step + cell / 2, day * step + cell / 2);
      paint.color = count == 0
          ? empty
          : count == 1
          ? done.withValues(alpha: 0.55)
          : done;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: side, height: side),
          Radius.circular(3 * progress),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.days != days || old.empty != empty || old.done != done;
}
