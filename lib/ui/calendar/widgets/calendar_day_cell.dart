import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../widgets/qweather_icon.dart';
import '../models/calendar_display_options.dart';
import '../viewmodels/calendar_day_summary.dart';
import 'calendar_day_cell_parts.dart';

/// 日历网格中的一个日期格。
///
/// 输入：日期状态（今天/选中/月外/周末）、当天汇总 [summary]、显示选项与
/// 照片样式的代表图；输出整格画面。无副作用，点按由 TableCalendar 处理。
///
/// 两种高亮形态：
/// - 填充（圆点/心情/标签色）：选中整格填 primary、今天填 tertiaryContainer，
///   与旧版日历一致；
/// - 描边（热力/照片）：格子底色本身承载数据（热力色阶、照片），整格填色会
///   盖掉它，改为外圈描边——选中 2dp primary、今天 tertiary。描边与内容之间
///   留 2dp 间隙，深色热力格外的 primary 描边依然可辨。
///
/// 三种状态间的颜色经 AnimatedContainer 以 `fast` 补间；形状始终是同一
/// 圆角矩形，补间中途不会换形（见 calendar_page 中的旧注释）。
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.day,
    required this.options,
    required this.isToday,
    required this.isSelected,
    required this.isOutside,
    required this.isWeekend,
    this.summary,
    this.image,
  });

  static const double _radius = 14;
  static const double _ringGap = 2;

  final DateTime day;
  final CalendarDisplayOptions options;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;
  final bool isWeekend;
  final CalendarDaySummary? summary;

  /// 照片样式的代表图（本地路径或 http(s) 地址）。
  final String? image;

  /// 当前格是否按“周末着色”铺灰底（相邻月份的日期不着色）。
  bool get _weekendShaded =>
      options.highlightWeekends && isWeekend && !isOutside;

  /// 周末底色：中性灰，与热力的 primary 色阶、今天的 tertiary、选中的
  /// primary 都不同色相。只换数字颜色时 tertiary 与正文黑字在亮色主题下
  /// 几乎分不出来，铺一层底色才能一眼看出周末那两列。
  static Color weekendColor(ColorScheme colorScheme) =>
      colorScheme.surfaceContainerHighest.withValues(
        alpha: colorScheme.brightness == Brightness.light ? 0.9 : 0.75,
      );

  bool get _ringMode =>
      options.cellStyle == CalendarCellStyle.heat ||
      options.cellStyle == CalendarCellStyle.photo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    final content = _ringMode
        ? _buildRingContent(context, colorScheme, duration)
        : _buildFillContent(context, colorScheme);

    final Color fill;
    final Color ring;
    if (_ringMode) {
      fill = Colors.transparent;
      ring = isSelected
          ? colorScheme.primary
          : isToday
          ? colorScheme.tertiary
          : colorScheme.primary.withValues(alpha: 0);
    } else {
      fill = isSelected
          ? colorScheme.primary
          : isToday
          ? colorScheme.tertiaryContainer
          : _weekendShaded
          ? weekendColor(colorScheme)
          : colorScheme.primary.withValues(alpha: 0);
      ring = Colors.transparent;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: AnimatedContainer(
        duration: duration,
        curve: ExpressiveMotion.effects,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(_radius),
          // 描边宽度恒定：宽度变化会让内容随选中/今天切换位移半个像素。
          border: Border.all(color: ring, width: 2),
        ),
        child: content,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 填充形态：圆点 / 心情 / 标签色
  // ---------------------------------------------------------------------------

  Widget _buildFillContent(BuildContext context, ColorScheme colorScheme) {
    final onFill = isSelected
        ? colorScheme.onPrimary
        : isToday
        ? colorScheme.onTertiaryContainer
        : null;
    final indicator = CalendarCellIndicator.resolve(
      colorScheme,
      summary: summary,
      options: options,
      onFill: onFill,
    );
    return CalendarCellLayout(
      number: _buildNumber(context, colorScheme, onFill: onFill),
      indicator: indicator,
      leadingBadge: _buildLeadingBadge(colorScheme, onFill: onFill),
      trailingBadge: CalendarCellCountMark.resolve(
        summary: summary,
        options: options,
        color: onFill ?? colorScheme.primary,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 描边形态：热力 / 照片
  // ---------------------------------------------------------------------------

  Widget _buildRingContent(
    BuildContext context,
    ColorScheme colorScheme,
    Duration duration,
  ) {
    final summary = this.summary;
    final innerRadius = BorderRadius.circular(_radius - 2 - _ringGap);
    if (options.cellStyle == CalendarCellStyle.photo) {
      final image = this.image;
      if (image != null) {
        // 排版层放在裁切之外，挂在日期小底块外侧的锁/天气不被裁掉；篇数
        // 直接写进日期小底块，照片上的裸字看不清。
        return Padding(
          padding: const EdgeInsets.all(_ringGap),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: <Widget>[
              ClipRRect(
                borderRadius: innerRadius,
                child: ColoredBox(
                  color: colorScheme.surfaceContainerHighest,
                  child: CalendarCellImage(source: image),
                ),
              ),
              CalendarCellLayout(
                number: _buildPhotoNumber(
                  context,
                  colorScheme,
                  count: CalendarCellCountMark.countFor(
                    summary: summary,
                    options: options,
                  ),
                ),
                leadingBadge: _buildLeadingBadge(colorScheme, onPhoto: true),
              ),
            ],
          ),
        );
      }
      // 当天有日记但没有图片：退回圆点，仍能看出这天写过。
      return Padding(
        padding: const EdgeInsets.all(_ringGap),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _weekendShaded ? weekendColor(colorScheme) : null,
            borderRadius: innerRadius,
          ),
          child: CalendarCellLayout(
            number: _buildNumber(context, colorScheme),
            indicator: CalendarCellIndicator.resolve(
              colorScheme,
              summary: summary,
              options: options,
            ),
            leadingBadge: _buildLeadingBadge(colorScheme),
            trailingBadge: CalendarCellCountMark.resolve(
              summary: summary,
              options: options,
              color: colorScheme.primary,
              dotsShown: true,
            ),
          ),
        ),
      );
    }

    final level = summary?.heatLevel(options.heatBasis) ?? 0;
    final heatColor = heatColorFor(colorScheme, level);
    final cardColor = ExpressiveSurfaces.cardColor(colorScheme);
    final foreground = level == 0
        ? null
        : _contrastingForeground(
            colorScheme,
            Color.alphaBlend(heatColor, cardColor),
          );
    return Padding(
      padding: const EdgeInsets.all(_ringGap),
      child: AnimatedContainer(
        duration: duration,
        curve: ExpressiveMotion.effects,
        // 有数据时以热力色为准；没写的周末铺周末底色。
        decoration: BoxDecoration(
          color: level == 0 && _weekendShaded
              ? weekendColor(colorScheme)
              : heatColor,
          borderRadius: innerRadius,
        ),
        child: CalendarCellLayout(
          number: _buildNumber(context, colorScheme, onFill: foreground),
          leadingBadge: _buildLeadingBadge(colorScheme, onFill: foreground),
          trailingBadge: CalendarCellCountMark.resolve(
            summary: summary,
            options: options,
            color: foreground ?? colorScheme.primary,
          ),
        ),
      ),
    );
  }

  /// 热力色阶：primary 的四档不透明度。按透明度分档而非渐变，符合 DESIGN.md
  /// 禁用渐变的约束；0 档为全透明（与无记录同色）。
  static Color heatColorFor(ColorScheme colorScheme, int level) {
    const alphas = <double>[0, 0.16, 0.32, 0.56, 0.82];
    return colorScheme.primary.withValues(alpha: alphas[level.clamp(0, 4)]);
  }

  /// 在 onPrimary 与 onSurface 中取与实际底色对比度更高的一个：明暗主题下
  /// primary 的深浅相反，固定用某一个总有一档看不清。
  static Color _contrastingForeground(
    ColorScheme colorScheme,
    Color background,
  ) {
    final bg = background.computeLuminance();
    double contrast(Color color) {
      final fg = color.computeLuminance();
      final hi = fg > bg ? fg : bg;
      final lo = fg > bg ? bg : fg;
      return (hi + 0.05) / (lo + 0.05);
    }

    return contrast(colorScheme.onPrimary) >= contrast(colorScheme.onSurface)
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
  }

  // ---------------------------------------------------------------------------
  // 公共元素
  // ---------------------------------------------------------------------------

  Widget _buildNumber(
    BuildContext context,
    ColorScheme colorScheme, {
    Color? onFill,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final Color color;
    if (onFill != null) {
      color = onFill;
    } else if (isOutside) {
      color = colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    } else {
      color = colorScheme.onSurface;
    }
    return Text(
      '${day.day}',
      style: textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
        height: 1.1,
      ),
    );
  }

  /// 照片上的日期数字放在半透明小底块上，任何照片上都读得清；有篇数时
  /// 以上标写在同一个底块里。
  Widget _buildPhotoNumber(
    BuildContext context,
    ColorScheme colorScheme, {
    int? count,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final selected = isSelected;
    final foreground = selected ? colorScheme.onPrimary : colorScheme.onSurface;
    // 窄屏加周数列、或大字号时格子放不下“日期 + 上标”，整体等比缩小而不是
    // 溢出。
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${day.day}',
                style: textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              if (count != null) ...<Widget>[
                const SizedBox(width: 1.5),
                CalendarCellCountMark(
                  count: count,
                  color: selected ? colorScheme.onPrimary : colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 左上角：未解封胶囊的锁优先；否则在开启时显示天气图标。
  Widget? _buildLeadingBadge(
    ColorScheme colorScheme, {
    Color? onFill,
    bool onPhoto = false,
  }) {
    final summary = this.summary;
    if (summary == null) {
      return null;
    }
    if (options.showCapsuleBadge && summary.hasLockedCapsule) {
      return CalendarCellBadgeBackdrop(
        enabled: onPhoto,
        child: FaIcon(
          FontAwesomeIcons.lock,
          size: 7.5,
          color: onFill ?? colorScheme.tertiary,
        ),
      );
    }
    final weather = summary.weather;
    if (options.showWeatherBadge && weather != null) {
      return CalendarCellBadgeBackdrop(
        enabled: onPhoto,
        child: QWeatherIcon(
          iconCode: summary.weatherIconCode,
          weatherText: weather,
          size: 9,
          fallbackColor: onFill ?? colorScheme.onSurfaceVariant,
          semanticLabel: weather,
        ),
      );
    }
    return null;
  }
}
