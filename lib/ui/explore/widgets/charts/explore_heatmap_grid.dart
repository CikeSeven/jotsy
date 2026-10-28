import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../widgets/desktop_horizontal_scroll.dart';
import '../../models/explore_module_data.dart';
import '../../viewmodels/explore_entry.dart';
import 'explore_reveal.dart';

/// 写作热力图的格子：每列一周、每行星期几，GitHub 式排布。
///
/// 输入：聚合好的 [data] 与每格颜色 [colorOf]；输出：一块 CustomPaint 网格，
/// 上方月份、左侧星期（[showWeekdays]），下方一行说明文字。点按有日记的
/// 格子经 [onDayTap] 交给页面（打开当天的日记）；鼠标悬停或点按时说明行改
/// 写那一天（[describe]），否则写 [summary]。
///
/// 尺寸：格子按可用宽度均分，最大 20（再宽时网格居中）；放不下（小于 7）时
/// 改为固定 10 的格子
/// 横向滚动，初始停在最右（最近一周），经 [DesktopHorizontalScroll] 支持
/// 鼠标拖动与 Shift + 滚轮。364 个格子只画一层 CustomPaint，不建 364 个
/// widget；首次出现时按列错峰着色（[reveal]）。
class ExploreHeatmapGrid extends StatefulWidget {
  const ExploreHeatmapGrid({
    super.key,
    required this.data,
    required this.colorOf,
    required this.emptyColor,
    required this.todayColor,
    required this.reveal,
    required this.showWeekdays,
    required this.summary,
    required this.describe,
    required this.onDayTap,
  });

  final ExploreHeatmapData data;
  final Color Function(ExploreHeatDay? day) colorOf;
  final Color emptyColor;

  /// 今天那格的描边色。
  final Color todayColor;
  final double reveal;
  final bool showWeekdays;
  final String summary;
  final String Function(DateTime date, ExploreHeatDay? day) describe;
  final ValueChanged<ExploreHeatDay> onDayTap;

  @override
  State<ExploreHeatmapGrid> createState() => _ExploreHeatmapGridState();
}

class _ExploreHeatmapGridState extends State<ExploreHeatmapGrid> {
  static const double _gap = 3;
  static const double _maxCell = 20;
  static const double _minCell = 7;
  static const double _scrollCell = 10;
  static const double _monthRow = 16;

  DateTime? _focused;

  DateTime _dateAt(int column, int row) {
    final start = widget.data.start;
    return DateTime(start.year, start.month, start.day + column * 7 + row);
  }

  /// [local] 落在哪一格；不在格子上或在今天之后时为 null。
  DateTime? _hit(Offset local, double cell) {
    final y = local.dy - _monthRow;
    if (local.dx < 0 || y < 0) return null;
    final column = (local.dx / (cell + _gap)).floor();
    final row = (y / (cell + _gap)).floor();
    if (column < 0 || column >= widget.data.weeks || row < 0 || row > 6) {
      return null;
    }
    final date = _dateAt(column, row);
    return date.isAfter(widget.data.today) ? null : date;
  }

  ExploreHeatDay? _dayOf(DateTime date) =>
      widget.data.days[exploreDayKey(date)];

  void _focus(DateTime? date) {
    if (date == _focused) return;
    setState(() => _focused = date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final localeName = Localizations.localeOf(context).toString();
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      color: scheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final labelWidth = widget.showWeekdays ? 30.0 : 0.0;
        final weeks = widget.data.weeks;
        final fitted =
            (constraints.maxWidth - labelWidth - _gap * (weeks - 1)) / weeks;
        final scrolls = fitted < _minCell;
        final cell = scrolls ? _scrollCell : math.min(fitted, _maxCell);
        final gridWidth = weeks * cell + (weeks - 1) * _gap;
        final gridHeight = _monthRow + 7 * cell + 6 * _gap;
        Widget grid = SizedBox(
          width: gridWidth,
          height: gridHeight,
          child: MouseRegion(
            onHover: (event) => _focus(_hit(event.localPosition, cell)),
            onExit: (_) => _focus(null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final date = _hit(details.localPosition, cell);
                _focus(date);
                final day = date == null ? null : _dayOf(date);
                if (day != null && day.diaryIds.isNotEmpty) {
                  widget.onDayTap(day);
                }
              },
              child: CustomPaint(
                painter: _HeatmapPainter(
                  data: widget.data,
                  cell: cell,
                  gap: _gap,
                  top: _monthRow,
                  colorOf: widget.colorOf,
                  emptyColor: widget.emptyColor,
                  todayColor: widget.todayColor,
                  focused: _focused,
                  focusColor: scheme.onSurface,
                  reveal: widget.reveal,
                  monthLabels: _monthLabels(localeName),
                  labelStyle: labelStyle ?? const TextStyle(fontSize: 10),
                  textDirection: Directionality.of(context),
                ),
              ),
            ),
          ),
        );
        if (scrolls) {
          grid = SizedBox(
            height: gridHeight,
            child: DesktopHorizontalScroll(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: grid,
              ),
            ),
          );
        }
        final focused = _focused;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              label: widget.summary,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (widget.showWeekdays)
                      SizedBox(
                        width: labelWidth,
                        height: gridHeight,
                        child: _WeekdayLabels(
                          firstWeekday: widget.data.firstWeekday,
                          cell: cell,
                          gap: _gap,
                          top: _monthRow,
                          style: labelStyle,
                          localeName: localeName,
                        ),
                      ),
                    if (scrolls) Expanded(child: grid) else grid,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              focused == null
                  ? widget.summary
                  : widget.describe(focused, _dayOf(focused)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 每列（周）开头若跨进新的月份，就在这一列上方写月份；相邻标签至少隔 4
  /// 列，避免挤在一起；画不下（超出网格右缘）的标签在绘制时略过。
  Map<int, String> _monthLabels(String localeName) {
    final format = DateFormat.MMM(localeName);
    final labels = <int, String>{};
    var lastColumn = -10;
    for (var column = 0; column < widget.data.weeks; column++) {
      final first = _dateAt(column, 0);
      final last = _dateAt(column, 6);
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
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels({
    required this.firstWeekday,
    required this.cell,
    required this.gap,
    required this.top,
    required this.style,
    required this.localeName,
  });

  final int firstWeekday;
  final double cell;
  final double gap;
  final double top;
  final TextStyle? style;
  final String localeName;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat.E(localeName);
    // 2026-06-01 是周一：加 (weekday - 1) 天得到任意星期几的一个日期。
    String nameOf(int weekday) =>
        format.format(DateTime(2026, 6, 1 + weekday - 1));
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
              child: Text(
                nameOf((firstWeekday - 1 + row) % 7 + 1),
                maxLines: 1,
                style: style,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.data,
    required this.cell,
    required this.gap,
    required this.top,
    required this.colorOf,
    required this.emptyColor,
    required this.todayColor,
    required this.focused,
    required this.focusColor,
    required this.reveal,
    required this.monthLabels,
    required this.labelStyle,
    required this.textDirection,
  });

  final ExploreHeatmapData data;
  final double cell;
  final double gap;
  final double top;
  final Color Function(ExploreHeatDay? day) colorOf;
  final Color emptyColor;
  final Color todayColor;
  final DateTime? focused;
  final Color focusColor;
  final double reveal;
  final Map<int, String> monthLabels;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    for (final MapEntry(key: column, value: label) in monthLabels.entries) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      final x = column * (cell + gap);
      if (x + painter.width > size.width) continue;
      painter.paint(canvas, Offset(x, 0));
    }
    final radius = Radius.circular(math.max(2, cell * 0.25));
    final start = data.start;
    for (var column = 0; column < data.weeks; column++) {
      final t = ExploreReveal.staggered(reveal, column, data.weeks);
      for (var row = 0; row < 7; row++) {
        final date = DateTime(
          start.year,
          start.month,
          start.day + column * 7 + row,
        );
        if (date.isAfter(data.today)) continue;
        final rect = Rect.fromLTWH(
          column * (cell + gap),
          top + row * (cell + gap),
          cell,
          cell,
        );
        final day = data.days[exploreDayKey(date)];
        final color = Color.lerp(emptyColor, colorOf(day), t)!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, radius),
          Paint()..color = color,
        );
        final isToday = date == data.today;
        final isFocused = date == focused;
        if (isToday || isFocused) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(0.75), radius),
            Paint()
              ..color = isFocused ? focusColor : todayColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate.cell != cell ||
      oldDelegate.reveal != reveal ||
      oldDelegate.focused != focused ||
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.todayColor != todayColor ||
      oldDelegate.focusColor != focusColor ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.colorOf != colorOf;
}
