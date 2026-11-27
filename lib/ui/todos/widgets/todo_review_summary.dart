import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/animated_rolling_text.dart';
import '../viewmodels/todo_review_stats.dart';

/// 待办回顾：左侧两行数字（“本周完成 N 件”“连续 N 天”，第一次出现时从 0
/// 逐位滚上去），右侧最近 7 天的迷你柱（按当天件数比例，今天的为 `primary`、
/// 其余半透明，0 件留一道底线），柱子第一次出现时从底部错峰长起来。
/// 已完成视图的概览卡与探索页的待办卡共用。减少动画时直接到位。
class TodoReviewSummary extends StatefulWidget {
  const TodoReviewSummary({
    super.key,
    required this.stats,
    required this.today,
  });

  final TodoReviewStats stats;
  final DateTime today;

  @override
  State<TodoReviewSummary> createState() => _TodoReviewSummaryState();
}

class _TodoReviewSummaryState extends State<TodoReviewSummary>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(vsync: this);

  /// 第一帧先写 0，下一帧换成真实数字，数字从 0 滚上去。
  bool _counted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_grow.isAnimating || _grow.value > 0) return;
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.long);
    if (duration == Duration.zero) {
      _grow.value = 1;
      _counted = true;
      return;
    }
    _grow
      ..duration = duration
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _counted = true);
    });
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = widget.stats;
    final week = _counted ? stats.weekDone : 0;
    final streak = _counted ? stats.streak : 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AnimatedRollingText.sentence(
                l10n.todoReviewWeekDone(week),
                number: week,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedRollingText.sentence(
                l10n.todoReviewStreak(streak),
                number: streak,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        Semantics(
          label: l10n.todoReviewChartLabel,
          value: stats.days.join(', '),
          excludeSemantics: true,
          child: _Bars(days: stats.days, today: widget.today, grow: _grow),
        ),
      ],
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.days, required this.today, required this.grow});

  final List<int> days;
  final DateTime today;
  final Animation<double> grow;

  static const double _height = 40;
  static const double _width = 10;
  static const double _gap = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = days.fold<int>(0, (int a, int b) => a > b ? a : b);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (var i = 0; i < days.length; i++)
          Padding(
            padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : _gap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: _width,
                  height: _height,
                  child: AnimatedBuilder(
                    animation: grow,
                    builder: (BuildContext context, Widget? _) {
                      // 每根晚一点开始，最后一根在 grow = 1 时长满。
                      final start = i / days.length * 0.5;
                      final t = ExpressiveMotion.spatial.transform(
                        ((grow.value - start) / 0.5).clamp(0.0, 1.0),
                      );
                      final share = top == 0 ? 0.0 : days[i] / top;
                      final height = days[i] == 0
                          ? 2.0
                          : (4 + (_height - 4) * share) * t;
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: _width,
                          height: height.clamp(0.0, _height),
                          decoration: BoxDecoration(
                            color: days[i] == 0
                                ? scheme.surfaceContainerHighest
                                : i == days.length - 1
                                ? scheme.primary
                                : scheme.primary.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 3),
                // 最窄的星期写法（一 / M / 月 / П）。
                Text(
                  DateFormat('EEEEE', l10n.localeName).format(
                    DateTime(
                      today.year,
                      today.month,
                      today.day - (days.length - 1 - i),
                    ),
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
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
