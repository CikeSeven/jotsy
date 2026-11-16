import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../calendar/viewmodels/calendar_holiday_day.dart';
import '../../calendar/viewmodels/calendar_lunar_day.dart';
import '../../calendar/widgets/calendar_cell_layout.dart';
import '../../calendar/widgets/calendar_cell_marks.dart';
import '../models/gallery_time_selection.dart';

/// “时间选择”日历的格子与标题胶囊（只负责画，状态与规则在
/// [GalleryTimeSelection]）。

/// 日期格高度：显示农历时放得下数字 + 一行小字，不显示时收矮。
double galleryDayCellHeight({required bool lunar}) => lunar ? 40 : 34;

/// 标题行里的“月”“年”胶囊：文字 + 向右的箭头，展开对应的选月 / 选年层时
/// 箭头转成朝上。[active] 时为主色（层展开着，或月份为“全部”）。
class GalleryTimeHeaderChip extends StatelessWidget {
  const GalleryTimeHeaderChip({
    super.key,
    required this.label,
    required this.active,
    required this.open,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final bool active;
  final bool open;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Row(
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: active ? colors.primary : colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: open
                  ? (Directionality.of(context) == TextDirection.rtl
                        ? 0.25
                        : -0.25)
                  : 0,
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              child: FaIcon(
                Directionality.of(context) == TextDirection.rtl
                    ? FontAwesomeIcons.angleLeft
                    : FontAwesomeIcons.angleRight,
                size: 12,
                color: active ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一个日期格：数字（深色端点为主色实心圆、今天为主色描边）、右上的休/班、
/// 下方的农历 / 节日 / 节气小字；浅色（单选或范围中段）整格铺浅主色。
///
/// 小字在深色圆的下方、浅色底上，所以选中时仍按类别取色，不跟着圆变成
/// 主色上的前景色（否则在浅底上看不清）。
class GalleryDayCell extends StatelessWidget {
  const GalleryDayCell({
    super.key,
    required this.day,
    required this.mark,
    required this.isToday,
    required this.showLunar,
    required this.showHolidays,
    required this.onTap,
    required this.onLongPress,
  });

  static const double _circle = 26;

  final DateTime day;
  final GalleryDayMark mark;
  final bool isToday;
  final bool showLunar;
  final bool showHolidays;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = mark == GalleryDayMark.dark;
    final light = mark == GalleryDayMark.light;
    final holiday = showHolidays ? CalendarHolidayDay.of(day) : null;
    final lunar = showLunar ? CalendarLunarDay.of(day) : null;
    final numberColor = dark
        ? colors.onPrimary
        : (light || isToday)
        ? colors.primary
        : colors.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: galleryDayCellHeight(lunar: showLunar),
        color: light ? colors.primary.withValues(alpha: 0.14) : null,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: _circle,
                  height: _circle,
                  alignment: Alignment.center,
                  decoration: dark
                      ? BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        )
                      : isToday
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.primary),
                        )
                      : null,
                  child: Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: dark ? FontWeight.w600 : FontWeight.w400,
                      color: numberColor,
                    ),
                  ),
                ),
                if (holiday != null)
                  PositionedDirectional(
                    top: -3,
                    end: -5,
                    child: CalendarCellHolidayMark(
                      isWork: holiday.isWork,
                      color: CalendarCellHolidayMark.colorFor(
                        colors,
                        isWork: holiday.isWork,
                      ),
                    ),
                  ),
              ],
            ),
            if (lunar != null) ...<Widget>[
              const SizedBox(height: 1),
              CalendarCellLunarLabel(
                text: lunar.cellLabel,
                emphasized: CalendarCellLunarLabel.isEmphasized(lunar.kind),
                color: CalendarCellLunarLabel.colorFor(colors, lunar.kind),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 选月 / 选年网格里的一格：端点深色、中段浅色、当前所在描边。
class GalleryGridCell extends StatelessWidget {
  const GalleryGridCell({
    super.key,
    required this.label,
    required this.mark,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final GalleryGridMark mark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(8);
    final decoration = switch (mark) {
      GalleryGridMark.endpoint => BoxDecoration(
        color: colors.primary,
        borderRadius: radius,
      ),
      GalleryGridMark.middle => BoxDecoration(
        color: colors.primary.withValues(alpha: 0.14),
        borderRadius: radius,
      ),
      GalleryGridMark.current => BoxDecoration(
        color: colors.primary.withValues(alpha: 0.14),
        borderRadius: radius,
        border: Border.all(color: colors.primary),
      ),
      GalleryGridMark.none => null,
    };
    final emphasized =
        mark == GalleryGridMark.endpoint || mark == GalleryGridMark.current;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: 42,
        child: Center(
          child: Container(
            width: 64,
            height: 34,
            alignment: Alignment.center,
            decoration: decoration,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
                color: switch (mark) {
                  GalleryGridMark.endpoint => colors.onPrimary,
                  GalleryGridMark.current ||
                  GalleryGridMark.middle => colors.primary,
                  GalleryGridMark.none => colors.onSurface,
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 3 列 × 4 行的 12 格（选月、选年共用）。
class GalleryGridPage extends StatelessWidget {
  const GalleryGridPage({super.key, required this.cellAt});

  final Widget Function(int index) cellAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var row = 0; row < 4; row++)
          Row(
            children: <Widget>[
              for (var col = 0; col < 3; col++)
                Expanded(child: cellAt(row * 3 + col)),
            ],
          ),
      ],
    );
  }
}
