import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import 'todo_labels.dart';
import 'todo_row_drag.dart';

/// 计划视图概览卡里的一周日期条：周一到周日七格（星期、日子、当天件数的
/// 圆点：1–2 件一个、3–4 件两个、5 件起三个），今天的日子落在 `primary`
/// 圆里，过去的日子变淡。两侧箭头（或左右滑）翻周，从本周起只往后翻；
/// 换周时整条朝翻的方向滑过去。
///
/// 点某一天（今天及以后）经 [onPickDay] 交出那天（页面在那天新建待办）；
/// 桌面上可把待办行拖到某一天上改期（[onDrop]，null 时不接）。
class TodoWeekStrip extends StatefulWidget {
  const TodoWeekStrip({
    super.key,
    required this.today,
    required this.counts,
    required this.onPickDay,
    this.onDrop,
  });

  final DateTime today;

  /// 每天（`YYYY-MM-DD`）未完成的件数。
  final Map<String, int> counts;
  final ValueChanged<DateTime> onPickDay;
  final void Function(DateTime day, TodoDragPayload payload)? onDrop;

  /// 每天（`YYYY-MM-DD`）未完成的件数。
  static Map<String, int> countsOf(List<TodoRow> open) {
    final counts = <String, int>{};
    for (final row in open) {
      final due = row.dueDate;
      if (due != null) counts[due] = (counts[due] ?? 0) + 1;
    }
    return counts;
  }

  @override
  State<TodoWeekStrip> createState() => _TodoWeekStripState();
}

class _TodoWeekStripState extends State<TodoWeekStrip> {
  /// 从本周起往后第几周。
  int _week = 0;

  /// 上一次翻的方向（+1 往后、-1 往前），新的一周从这一侧滑进来。
  int _direction = 1;

  void _turn(int delta) {
    final next = (_week + delta).clamp(0, 520);
    if (next == _week) return;
    setState(() {
      _direction = delta.sign;
      _week = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = widget.today;
    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1) + _week * 7,
    );
    final week = ValueKey<int>(_week);
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: l10n.todoWeekPrev,
          onPressed: _week == 0 ? null : () => _turn(-1),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 14),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (DragEndDetails details) {
              final v = details.primaryVelocity ?? 0;
              if (v.abs() < 200) return;
              _turn(v < 0 ? 1 : -1);
            },
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.medium,
                ),
                switchInCurve: ExpressiveMotion.effects,
                switchOutCurve: ExpressiveMotion.exit,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final incoming = child.key == week;
                  final dx = 0.25 * (incoming ? _direction : -_direction);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(dx, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Row(
                  key: week,
                  children: <Widget>[
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: _DayCell(
                          day: DateTime(
                            monday.year,
                            monday.month,
                            monday.day + i,
                          ),
                          today: today,
                          counts: widget.counts,
                          onPick: widget.onPickDay,
                          onDrop: widget.onDrop,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.todoWeekNext,
          onPressed: () => _turn(1),
          icon: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.counts,
    required this.onPick,
    required this.onDrop,
  });

  final DateTime day;
  final DateTime today;
  final Map<String, int> counts;
  final ValueChanged<DateTime> onPick;
  final void Function(DateTime day, TodoDragPayload payload)? onDrop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = counts[formatAnniversaryDate(day)] ?? 0;
    final isToday = DateUtils.isSameDay(day, today);
    final past = day.isBefore(today);
    final ink = past ? scheme.onSurfaceVariant.withValues(alpha: 0.5) : null;
    final dots = count == 0 ? 0 : (count <= 2 ? 1 : (count <= 4 ? 2 : 3));
    final drop = onDrop;
    final cell = Semantics(
      button: !past,
      selected: isToday,
      label: l10n.todoWeekDaySummary(
        l10n.todoHeroDate(
          TodoLabels.weekdayName(l10n, day.weekday, short: false),
          l10n.formatMonthDay(day),
        ),
        count,
      ),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: past ? null : () => onPick(day),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                TodoLabels.weekdayName(l10n, day.weekday),
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ink ?? scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Text(
                  '${day.day}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isToday ? scheme.onPrimary : ink,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (var i = 0; i < dots; i++)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: ink ?? scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return TodoDropTarget(
      onDrop: drop == null || past
          ? null
          : (TodoDragPayload payload) => drop(day, payload),
      child: cell,
    );
  }
}
