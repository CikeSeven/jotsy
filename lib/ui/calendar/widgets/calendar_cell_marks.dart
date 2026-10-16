import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/qweather_icon.dart';
import '../models/calendar_display_options.dart';
import '../viewmodels/calendar_day_summary.dart';
import '../viewmodels/calendar_holiday_day.dart';
import '../viewmodels/calendar_lunar_day.dart';
import 'calendar_cell_layout.dart';
import 'calendar_day_cell_parts.dart';

/// 日期数字下方的小字：纪念日名称优先，其次是农历、节日与节气。
///
/// 纪念日是用户自己记下的日子，比历法上的节日更值得一眼看到；名称按节日
/// 配色（tertiary 加粗），过长时截断——320dp 窄屏的日期格只放得下四个字
/// 而不缩得过小，与“国庆节”“妈妈生日”同一字号；全名在选中那天的纪念日
/// 卡片里。不显示农历时没有小字行，纪念日改由数字左上的
/// 心形标出（见 [CalendarCellLeadingBadge]）。
abstract final class CalendarCellSubtitle {
  /// 名称最多占的宽度，以汉字宽为 1、拉丁字母等窄字符约 0.55 计。
  static const double maxTitleWidth = 4;

  static Widget? resolve(
    ColorScheme colorScheme, {
    required CalendarLunarDay? lunar,
    required String? anniversary,
    Color? onFill,
    bool isOutside = false,
  }) {
    if (lunar == null) {
      return null;
    }
    if (anniversary != null) {
      return CalendarCellLunarLabel(
        text: shortTitle(anniversary),
        emphasized: true,
        color: CalendarCellLunarLabel.colorFor(
          colorScheme,
          CalendarLunarKind.festival,
          onFill: onFill,
          isOutside: isOutside,
        ),
      );
    }
    return CalendarCellLunarLabel(
      text: lunar.cellLabel,
      emphasized: CalendarCellLunarLabel.isEmphasized(lunar.kind),
      color: CalendarCellLunarLabel.colorFor(
        colorScheme,
        lunar.kind,
        onFill: onFill,
        isOutside: isOutside,
      ),
    );
  }

  /// 放得下就写全名，否则截到最大宽度并以“…”结尾（“妈妈生日”写全，
  /// “结婚纪念日”写成“结婚纪…”）。
  static String shortTitle(String title) {
    final characters = title.trim().characters;
    double widthOf(String character) =>
        character.codeUnitAt(0) < 0x2E80 ? 0.55 : 1;
    final total = characters.fold<double>(0, (sum, c) => sum + widthOf(c));
    if (total <= maxTitleWidth) {
      return characters.toString();
    }
    final kept = StringBuffer();
    var width = 0.0;
    for (final character in characters) {
      width += widthOf(character);
      if (width > maxTitleWidth - 1) {
        break;
      }
      kept.write(character);
    }
    return '${kept.toString().trimRight()}…';
  }
}

/// 日期数字左上方的角标：一格只放一个，按重要程度取第一个。
///
/// 优先级：未解封胶囊的锁 > 休/班 > 纪念日心形 > 天气。锁关系到内容是否
/// 可看，最先；休/班是这一天本身的属性，比“当天第一篇的天气”更该一眼
/// 看到；心形只在不显示农历时出现（显示农历时纪念日名称写在小字行）。
/// 角标与数字之间的间隙、槽位宽度由 [CalendarCellLayout] 统一负责，这里
/// 只决定画什么和用什么颜色。
abstract final class CalendarCellLeadingBadge {
  /// [onFill] 为选中/今天/热力等有底色的格子的前景色：彩色角标放在
  /// primary/tertiary 底上会撞色，统一改用前景色；[onPhoto] 时垫圆底。
  static Widget? resolve(
    ColorScheme colorScheme, {
    required CalendarDisplayOptions options,
    required CalendarDaySummary? summary,
    required CalendarHolidayDay? holiday,
    required bool isOutside,
    bool anniversaryHeart = false,
    Color? onFill,
    bool onPhoto = false,
  }) {
    if (options.showCapsuleBadge && (summary?.hasLockedCapsule ?? false)) {
      return CalendarCellBadgeBackdrop(
        enabled: onPhoto,
        child: FaIcon(
          FontAwesomeIcons.lock,
          size: 7.5,
          color: onFill ?? colorScheme.tertiary,
        ),
      );
    }
    if (holiday != null) {
      return CalendarCellBadgeBackdrop(
        enabled: onPhoto,
        child: CalendarCellHolidayMark(
          isWork: holiday.isWork,
          color: CalendarCellHolidayMark.colorFor(
            colorScheme,
            isWork: holiday.isWork,
            onFill: onFill,
            isOutside: isOutside,
          ),
        ),
      );
    }
    if (anniversaryHeart) {
      final color = onFill ?? colorScheme.tertiary;
      return CalendarCellBadgeBackdrop(
        enabled: onPhoto,
        child: FaIcon(
          FontAwesomeIcons.solidHeart,
          size: 7.5,
          color: isOutside && onFill == null
              ? color.withValues(alpha: 0.45)
              : color,
        ),
      );
    }
    final weather = summary?.weather;
    if (summary != null && options.showWeatherBadge && weather != null) {
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

/// 法定节假日的“休”或调休上班的“班”。
///
/// 小号粗体单字，与锁、天气同挂在数字左上方（不放格子角上，见
/// [CalendarCellLayout]）。“休”用 tertiary，与节日小字同色系；“班”用
/// 弱化色——它提示的是“这天要上班”，不该比放假日更抢眼。字号不随系统
/// 字体缩放（与篇数上标一致），英文“Off/Work”放不下时在槽位内等比缩小。
class CalendarCellHolidayMark extends StatelessWidget {
  const CalendarCellHolidayMark({
    super.key,
    required this.isWork,
    required this.color,
  });

  final bool isWork;
  final Color color;

  static Color colorFor(
    ColorScheme colorScheme, {
    required bool isWork,
    Color? onFill,
    bool isOutside = false,
  }) {
    if (onFill != null) {
      return isWork ? onFill.withValues(alpha: 0.8) : onFill;
    }
    final base = isWork ? colorScheme.onSurfaceVariant : colorScheme.tertiary;
    return isOutside ? base.withValues(alpha: 0.45) : base;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        isWork ? l10n.calendarHolidayWorkMark : l10n.calendarHolidayRestMark,
        maxLines: 1,
        softWrap: false,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: 8,
          height: 1,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
