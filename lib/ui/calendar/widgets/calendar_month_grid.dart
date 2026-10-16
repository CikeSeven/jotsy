import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../models/calendar_display_options.dart';
import '../viewmodels/calendar_day_summary.dart';
import 'calendar_day_cell.dart';

/// 日历网格（月/周）：TableCalendar 的配置与日期格装配。
///
/// 输入：焦点日期、选中日期、网格格式、显示选项、逐日汇总与照片样式的
/// 正文首图；输出网格，交互经回调交给页面控制器。无副作用。
///
/// 每个日期格整格由 `prioritizedBuilder` 绘制（[CalendarDayCell]），不使用
/// table_calendar 自带的 eventLoader/markers：热力、照片等样式要画满格子
/// 底色，默认“文字 + 底部圆点”的结构容纳不下。泛型参数沿用
/// [DiaryCalendarMarker] 仅为保持组件类型稳定，网格本身不读事件。
class CalendarMonthGrid extends StatefulWidget {
  const CalendarMonthGrid({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.format,
    required this.options,
    required this.summaries,
    required this.inlineImages,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onFormatChanged,
    this.onDayLongPressed,
  });

  static final DateTime firstDay = DateTime(2010, 1, 1);
  static final DateTime lastDay = DateTime(2100, 12, 31);

  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat format;
  final CalendarDisplayOptions options;
  final Map<DateTime, CalendarDaySummary> summaries;
  final Map<String, String> inlineImages;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;
  final ValueChanged<CalendarFormat> onFormatChanged;

  /// 长按日期（快捷操作面板）；table_calendar 的手势不经过 InkWell，没有
  /// 系统长按反馈，由回调方负责。
  final ValueChanged<DateTime>? onDayLongPressed;

  @override
  State<CalendarMonthGrid> createState() => _CalendarMonthGridState();

  Widget _buildCalendar(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final photoStyle = options.cellStyle == CalendarCellStyle.photo;

    return TableCalendar<DiaryCalendarMarker>(
      locale: l10n.localeName,
      firstDay: firstDay,
      lastDay: lastDay,
      focusedDay: focusedDay,
      currentDay: today,
      calendarFormat: format,
      startingDayOfWeek: resolveStartingDayOfWeek(
        options.weekStart,
        MaterialLocalizations.of(context),
      ),
      sixWeekMonthsEnforced: options.fixedSixWeeks,
      weekNumbersVisible: options.showWeekNumbers,
      selectedDayPredicate: (DateTime day) => isSameDay(day, selectedDay),
      headerVisible: false,
      availableGestures: AvailableGestures.all,
      availableCalendarFormats: <CalendarFormat, String>{
        CalendarFormat.month: l10n.autoT0178,
        CalendarFormat.week: l10n.autoT0179,
      },
      onFormatChanged: onFormatChanged,
      onDaySelected: onDaySelected,
      onPageChanged: onPageChanged,
      onDayLongPressed: onDayLongPressed == null
          ? null
          : (DateTime day, DateTime focusedDay) => onDayLongPressed!(day),
      // 翻页与月/周切换动画统一走 Expressive token；减少动画时直接跳转。
      pageAnimationEnabled: !ExpressiveMotion.reduceMotion(context),
      pageAnimationDuration: ExpressiveMotion.medium,
      pageAnimationCurve: ExpressiveMotion.effects,
      // table_calendar 用 AnimatedSize 过渡月/周高度，减少动画时不能传 0。
      formatAnimationDuration: ExpressiveMotion.durationNonZero(
        context,
        ExpressiveMotion.medium,
      ),
      formatAnimationCurve: ExpressiveMotion.effects,
      calendarStyle: CalendarStyle(
        weekNumberTextStyle: textTheme.labelSmall!.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      calendarBuilders: CalendarBuilders<DiaryCalendarMarker>(
        prioritizedBuilder:
            (BuildContext context, DateTime day, DateTime focusedDay) {
              final dayKey = DateUtils.dateOnly(day);
              final summary = summaries[dayKey];
              return CalendarDayCell(
                day: day,
                options: options,
                isToday: dayKey == today,
                isSelected: isSameDay(day, selectedDay),
                isOutside: day.month != focusedDay.month,
                isWeekend:
                    day.weekday == DateTime.saturday ||
                    day.weekday == DateTime.sunday,
                summary: summary,
                image: photoStyle
                    ? summary?.representativeImage(inlineImages)
                    : null,
              );
            },
        dowBuilder: (BuildContext context, DateTime day) {
          // 独立窄星期（ccccc）：中文“一…日”、英文“M…S”，
          // 由 intl 语言数据提供，新增语言无需改代码。
          final label = DateFormat('ccccc', l10n.localeName).format(day);
          final shaded =
              options.highlightWeekends &&
              (day.weekday == DateTime.saturday ||
                  day.weekday == DateTime.sunday);
          // 周末着色时星期栏的“六、日”也铺同样的灰底，与下方日期格连成
          // 一条竖向色带。
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: shaded
                    ? CalendarDayCell.weekendColor(colorScheme)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: shaded
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 每周第一天对应的 [DateTime.weekday]（年视图与月视图保持同一起始日）。
  static int firstWeekdayOf(
    CalendarWeekStart weekStart,
    MaterialLocalizations localizations,
  ) {
    return switch (resolveStartingDayOfWeek(weekStart, localizations)) {
      StartingDayOfWeek.monday => DateTime.monday,
      StartingDayOfWeek.tuesday => DateTime.tuesday,
      StartingDayOfWeek.wednesday => DateTime.wednesday,
      StartingDayOfWeek.thursday => DateTime.thursday,
      StartingDayOfWeek.friday => DateTime.friday,
      StartingDayOfWeek.saturday => DateTime.saturday,
      StartingDayOfWeek.sunday => DateTime.sunday,
    };
  }

  /// 一周起始日：跟随语言时取 MaterialLocalizations 的语言区域数据（中文
  /// 周一、英文周日），旧版日历未设置该参数，所有语言都从周日开始。
  static StartingDayOfWeek resolveStartingDayOfWeek(
    CalendarWeekStart weekStart,
    MaterialLocalizations localizations,
  ) {
    return switch (weekStart) {
      CalendarWeekStart.monday => StartingDayOfWeek.monday,
      CalendarWeekStart.sunday => StartingDayOfWeek.sunday,
      CalendarWeekStart.locale => switch (localizations.firstDayOfWeekIndex) {
        0 => StartingDayOfWeek.sunday,
        1 => StartingDayOfWeek.monday,
        2 => StartingDayOfWeek.tuesday,
        3 => StartingDayOfWeek.wednesday,
        4 => StartingDayOfWeek.thursday,
        5 => StartingDayOfWeek.friday,
        _ => StartingDayOfWeek.saturday,
      },
    };
  }
}

class _CalendarMonthGridState extends State<CalendarMonthGrid> {
  /// Home 的 tab_calendar 是 PageStorageKey；若沿用路由的 bucket，
  /// TableCalendar 的页码会与外层列表的像素偏移共用同一个存储位置。
  /// 从年视图回到月视图时，0 会被当作第一页（2010 年），旧页码则会覆盖
  /// 新选的月份。这里截断祖先 key 的查找，让每次挂载都以 focusedDay 定位。
  final _pageStorageBucket = PageStorageBucket();

  @override
  Widget build(BuildContext context) => PageStorage(
    bucket: _pageStorageBucket,
    child: widget._buildCalendar(context),
  );
}
