import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/animated_rolling_text.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../viewmodels/todo_groups.dart';
import 'todo_labels.dart';
import 'todo_progress_ring.dart';

/// 今天视图的概览卡内容：眉线“周六 · 11月8日”（`labelLarge` w600 `primary`）、
/// 主句“还有 3 件”（`headlineSmall` w800；做完了 / 没有安排各有说法）、副句
/// 逾期与已完成的胶囊，右侧 56dp 进度环（今天完成 / 今天全部）。
///
/// “今天清零”：正看着的时候完成了今天的最后一件（还剩的从有变成 0、今天
/// 完成的变多），进度环先合拢（`medium`），再轻弹一下（[_pop]），环心的
/// “3/3”换成对勾，主句交叉淡入“今天的事都做完了”，配一次中等触觉。只在
/// 这次变化时演一次：打开页面时已经做完、或把最后一件改到明天，都不演。
/// 减少动画时直接到位（触觉照旧）。
class TodoTodayHero extends StatefulWidget {
  const TodoTodayHero({
    super.key,
    required this.today,
    required this.summary,
    this.onPlan,
  });

  final DateTime today;
  final TodoTodaySummary summary;

  /// “规划今天”（有可规划的待办时由页面给出）。
  final VoidCallback? onPlan;

  @override
  State<TodoTodayHero> createState() => _TodoTodayHeroState();
}

class _TodoTodayHeroState extends State<TodoTodayHero>
    with SingleTickerProviderStateMixin {
  /// 清零时的轻弹：0 → 1，前一段等环合拢，后一段放大到 1.08 再回落。
  late final AnimationController _pop = AnimationController(
    vsync: this,
    value: 1,
  );

  static final Animatable<double> _popScale =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(tween: ConstantTween<double>(1), weight: 40),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: 1.08,
          ).chain(CurveTween(curve: ExpressiveMotion.effects)),
          weight: 20,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1.08,
            end: 1,
          ).chain(CurveTween(curve: ExpressiveMotion.spatial)),
          weight: 40,
        ),
      ]);

  @override
  void didUpdateWidget(TodoTodayHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.summary;
    final now = widget.summary;
    final cleared =
        before.remaining > 0 &&
        now.remaining == 0 &&
        now.doneToday > before.doneToday;
    if (!cleared) return;
    unawaited(HapticFeedback.mediumImpact());
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium + ExpressiveMotion.standard,
    );
    if (duration == Duration.zero) return;
    _pop
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = widget.summary;
    final today = widget.today;
    final allDone = summary.remaining == 0 && summary.doneToday > 0;
    final headline = summary.remaining > 0
        ? l10n.todoHeroRemaining(summary.remaining)
        : allDone
        ? l10n.todoHeroAllDone
        : l10n.todoHeroNothing;
    final chips = <Widget>[
      if (summary.overdue > 0)
        _HeroChip(
          key: const ValueKey<String>('overdue'),
          text: l10n.todoHeroOverdue(summary.overdue),
          count: summary.overdue,
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
        ),
      if (summary.doneToday > 0)
        _HeroChip(
          key: const ValueKey<String>('done'),
          text: l10n.todoHeroDone(summary.doneToday),
          count: summary.doneToday,
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
        ),
    ];
    final headlineStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    );
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
              // 还剩几件之间逐位滚动；换成别的说法（做完了 / 没有安排）时
              // 交叉淡入。
              AnimatedSwitcher(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.medium,
                ),
                switchInCurve: ExpressiveMotion.effects,
                switchOutCurve: ExpressiveMotion.exit,
                layoutBuilder: _stackStart,
                child: AnimatedRollingText.sentence(
                  key: ValueKey<int>(
                    summary.remaining > 0
                        ? 0
                        : allDone
                        ? 1
                        : 2,
                  ),
                  headline,
                  number: summary.remaining > 0 ? summary.remaining : null,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: headlineStyle,
                ),
              ),
              if (chips.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.s),
                Wrap(spacing: 6, runSpacing: 4, children: chips),
              ],
              if (widget.onPlan case final onPlan?) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onPlan,
                  icon: const FaIcon(
                    FontAwesomeIcons.wandMagicSparkles,
                    size: 13,
                  ),
                  label: Text(l10n.todoPlanToday),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        ScaleTransition(
          scale: _pop.drive(_popScale),
          child: TodoProgressRing(
            fraction: summary.fraction,
            color: scheme.primary,
            track: scheme.surfaceContainerHighest,
            center: ExpressiveIconSwap(
              switchKey: allDone,
              child: allDone
                  ? FaIcon(
                      FontAwesomeIcons.check,
                      size: 20,
                      color: scheme.primary,
                      semanticLabel: l10n.todoHeroAllDone,
                    )
                  : AnimatedRollingText(
                      '${summary.doneToday}/${summary.total}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _stackStart(Widget? current, List<Widget> previous) => Stack(
    alignment: AlignmentDirectional.centerStart,
    children: <Widget>[...previous, ?current],
  );
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    super.key,
    required this.text,
    required this.count,
    required this.background,
    required this.foreground,
  });

  final String text;

  /// 胶囊里的数字（变化时逐位滚动）。
  final int count;
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
      child: AnimatedRollingText.sentence(
        text,
        number: count,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
