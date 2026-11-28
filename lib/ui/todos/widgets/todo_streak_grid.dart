import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../viewmodels/todo_streak.dart';

/// 坚持记录的满宽自适应完成热力图：
/// - 左侧紧凑星期轴（一 / 三 / 五 / 日），上方月份刻度，右侧网格按可用宽
///   度均分并铺满整张卡片（超宽时限大并居中），告别固定 177dp 偏左留白；
/// - 未完成为 `surfaceContainerHighest`，已完成为饱满的 `primary`，今日带
///   清晰描边环；
/// - 首次出现时按列错峰从中心长出（`long`，减少动画时直接画满）；
/// - 支持点按或鼠标悬停查看具体日期的完成情况，平时底部展示统计周数与图例。
class TodoStreakGrid extends StatefulWidget {
  const TodoStreakGrid({
    super.key,
    required this.streak,
    required this.cell,
    required this.gap,
    required this.labelWidth,
  });

  final TodoStreak streak;
  final double cell;
  final double gap;
  final double labelWidth;

  static const double defaultGap = 3.5;
  static const double maxCell = 18;
  static const double minCell = 8;
  static const double defaultLabelWidth = 22;
  static const double monthRowHeight = 16;

  @override
  State<TodoStreakGrid> createState() => _TodoStreakGridState();
}

class _TodoStreakGridState extends State<TodoStreakGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(vsync: this);
  DateTime? _focused;

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

  DateTime? _hit(Offset local) {
    final y = local.dy - TodoStreakGrid.monthRowHeight;
    if (local.dx < 0 || y < 0) return null;
    final step = widget.cell + widget.gap;
    final column = (local.dx / step).floor();
    final row = (y / step).floor();
    if (column < 0 || column >= widget.streak.weeks || row < 0 || row > 6) {
      return null;
    }
    if (widget.streak.countAt(column, row) < 0) return null;
    return widget.streak.dateAt(column, row);
  }

  int? _countOf(DateTime date) {
    final diff = date.difference(widget.streak.start).inDays;
    if (diff < 0 || diff >= widget.streak.days.length) return null;
    final count = widget.streak.days[diff];
    return count < 0 ? null : count;
  }

  void _setFocused(DateTime? day) {
    if (day == _focused) return;
    setState(() => _focused = day);
  }

  Map<int, String> _monthLabels(String localeName) {
    final format = DateFormat.MMM(localeName);
    final labels = <int, String>{};
    var lastColumn = -10;
    for (var column = 0; column < widget.streak.weeks; column++) {
      final first = widget.streak.dateAt(column, 0);
      final last = widget.streak.dateAt(column, 6);
      final DateTime? monthStart = column == 0
          ? first
          : (last.month != first.month || first.day == 1)
          ? DateTime(last.year, last.month)
          : null;
      if (monthStart == null || column - lastColumn < 4) continue;
      labels[column] = format.format(monthStart);
      lastColumn = column;
    }
    return labels;
  }

  String _describeDay(AppLocalizations l10n, DateTime date, int count) {
    final dateText = date.year == widget.streak.today.year
        ? l10n.formatMonthDay(date)
        : l10n.formatFullDate(date);
    if (count <= 0) return l10n.todoStreakDayMissed(dateText);
    if (count == 1) return l10n.todoStreakDayCompleted(dateText);
    return l10n.todoStreakDayCompletedTimes(dateText, count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final streak = widget.streak;
    final cell = widget.cell;
    final gap = widget.gap;
    final gridWidth = streak.weeks * cell + (streak.weeks - 1) * gap;
    final gridHeight = TodoStreakGrid.monthRowHeight + 7 * cell + 6 * gap;
    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      color: scheme.onSurfaceVariant,
    );
    final focused = _focused;
    final focusedCount = focused == null ? null : _countOf(focused);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          label: l10n.todoStreakGridLabel(streak.weeks),
          excludeSemantics: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: widget.labelWidth,
                height: gridHeight,
                child: _WeekdayAxis(
                  cell: cell,
                  gap: gap,
                  top: TodoStreakGrid.monthRowHeight,
                  style: axisStyle,
                  localeName: l10n.localeName,
                ),
              ),
              SizedBox(
                width: gridWidth,
                height: gridHeight,
                child: MouseRegion(
                  onHover: (event) => _setFocused(_hit(event.localPosition)),
                  onExit: (_) => _setFocused(null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final day = _hit(details.localPosition);
                      _setFocused(day == _focused ? null : day);
                    },
                    child: CustomPaint(
                      painter: _StreakGridPainter(
                        streak: streak,
                        cell: cell,
                        gap: gap,
                        top: TodoStreakGrid.monthRowHeight,
                        grow: _grow,
                        empty: scheme.surfaceContainerHighest,
                        done: scheme.primary,
                        todayRing: scheme.primary,
                        todayDoneRing: scheme.onPrimary.withValues(alpha: 0.78),
                        focused: focused,
                        focusRing: scheme.onSurface,
                        monthLabels: _monthLabels(l10n.localeName),
                        labelStyle: axisStyle ?? const TextStyle(fontSize: 10),
                        textDirection: Directionality.of(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        _StreakFooter(
          focusedText: focused != null && focusedCount != null
              ? _describeDay(l10n, focused, focusedCount)
              : null,
          rangeText: l10n.todoStreakRangeWeeks(streak.weeks),
          notDoneText: l10n.todoStreakLegendNotDone,
          doneText: l10n.todoStreakLegendDone,
        ),
      ],
    );
  }
}

class _WeekdayAxis extends StatelessWidget {
  const _WeekdayAxis({
    required this.cell,
    required this.gap,
    required this.top,
    required this.style,
    required this.localeName,
  });

  final double cell;
  final double gap;
  final double top;
  final TextStyle? style;
  final String localeName;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('EEEEE', localeName);
    // 2026-06-01 是周一。
    String labelOf(int row) => format.format(DateTime(2026, 6, 1 + row));
    return Stack(
      children: <Widget>[
        for (final row in const <int>[0, 2, 4, 6])
          Positioned(
            top: top + row * (cell + gap),
            left: 0,
            right: 4,
            height: cell,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(labelOf(row), maxLines: 1, style: style),
            ),
          ),
      ],
    );
  }
}

class _StreakFooter extends StatelessWidget {
  const _StreakFooter({
    required this.focusedText,
    required this.rangeText,
    required this.notDoneText,
    required this.doneText,
  });

  final String? focusedText;
  final String rangeText;
  final String notDoneText;
  final String doneText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    if (focusedText case final text?) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: captionStyle,
      );
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            rangeText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: captionStyle,
          ),
        ),
        _LegendSwatch(
          color: scheme.surfaceContainerHighest,
          label: notDoneText,
          style: captionStyle,
        ),
        const SizedBox(width: AppSpacing.m),
        _LegendSwatch(
          color: scheme.primary,
          label: doneText,
          style: captionStyle,
        ),
      ],
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({
    required this.color,
    required this.label,
    required this.style,
  });

  final Color color;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }
}

class _StreakGridPainter extends CustomPainter {
  _StreakGridPainter({
    required this.streak,
    required this.cell,
    required this.gap,
    required this.top,
    required this.grow,
    required this.empty,
    required this.done,
    required this.todayRing,
    required this.todayDoneRing,
    required this.focused,
    required this.focusRing,
    required this.monthLabels,
    required this.labelStyle,
    required this.textDirection,
  }) : super(repaint: grow);

  final TodoStreak streak;
  final double cell;
  final double gap;
  final double top;
  final Animation<double> grow;
  final Color empty;
  final Color done;
  final Color todayRing;
  final Color todayDoneRing;
  final DateTime? focused;
  final Color focusRing;
  final Map<int, String> monthLabels;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final step = cell + gap;
    for (final MapEntry(key: column, value: label) in monthLabels.entries) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      final x = column * step;
      if (x + painter.width > size.width + 1) continue;
      painter.paint(canvas, Offset(x, 0));
    }

    final fillPaint = Paint();
    final radiusBase = math.max(2.5, cell * 0.25);
    final t = grow.value;
    final weeks = streak.weeks;
    for (var i = 0; i < streak.days.length; i++) {
      final count = streak.days[i];
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
      final center = Offset(
        week * step + cell / 2,
        top + day * step + cell / 2,
      );
      final rect = Rect.fromCenter(center: center, width: side, height: side);
      final radius = Radius.circular(radiusBase * progress);
      fillPaint.color = count == 0 ? empty : done;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fillPaint);

      final date = streak.dateAt(week, day);
      final isToday = date == streak.today;
      final isFocused = date == focused;
      if ((isToday || isFocused) && progress > 0.85) {
        final inset = isFocused
            ? 0.75
            : count > 0
            ? 2.0
            : 0.75;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(inset), radius),
          Paint()
            ..color = isFocused
                ? focusRing
                : count > 0
                ? todayDoneRing
                : todayRing
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StreakGridPainter old) =>
      old.streak.days != streak.days ||
      old.streak.weeks != streak.weeks ||
      old.streak.today != streak.today ||
      old.cell != cell ||
      old.gap != gap ||
      old.empty != empty ||
      old.done != done ||
      old.todayRing != todayRing ||
      old.todayDoneRing != todayDoneRing ||
      old.focused != focused ||
      old.focusRing != focusRing ||
      old.labelStyle != labelStyle;
}
