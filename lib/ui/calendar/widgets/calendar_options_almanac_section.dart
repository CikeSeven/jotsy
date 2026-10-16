import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../widgets/expressive_button_group.dart';
import '../models/calendar_display_options.dart';
import '../viewmodels/calendar_holiday_day.dart';
import 'calendar_options_controls.dart';

/// 显示选项面板的“农历与节假日”分组：农历小字与法定节假日两组三档选择
/// （跟随语言 / 显示 / 隐藏）。
///
/// 两项都是中国历法内容、取值语义相同，放在一组里对照着选；节假日说明
/// 写明数据收录到哪一年——放假安排每年由国务院公布、随依赖更新，用户
/// 看到明年没有“休/班”时能知道原因。只负责排版，保存交给面板。
class CalendarOptionsAlmanacSection extends StatelessWidget {
  const CalendarOptionsAlmanacSection({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final CalendarDisplayOptions options;
  final ValueChanged<CalendarDisplayOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final coveredYear = CalendarHolidayDay.lastCoveredYear();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CalendarOptionsSectionHeader(
          icon: FontAwesomeIcons.moon,
          label: l10n.calendarOptionsAlmanac,
        ),
        const SizedBox(height: AppSpacing.s),
        CalendarOptionsFieldLabel(text: l10n.calendarOptionsLunar),
        _ModeGroup(
          selected: options.lunarMode,
          onSelected: (CalendarLunarMode mode) =>
              onChanged(options.copyWith(lunarMode: mode)),
        ),
        const SizedBox(height: AppSpacing.s),
        CalendarOptionsFadingText(text: l10n.calendarOptionsLunarDescription),
        const SizedBox(height: AppSpacing.m),
        CalendarOptionsFieldLabel(text: l10n.calendarOptionsHolidays),
        _ModeGroup(
          selected: options.holidayMode,
          onSelected: (CalendarLunarMode mode) =>
              onChanged(options.copyWith(holidayMode: mode)),
        ),
        const SizedBox(height: AppSpacing.s),
        CalendarOptionsFadingText(
          text: coveredYear == null
              ? l10n.calendarOptionsHolidaysDescriptionOutdated
              : l10n.calendarOptionsHolidaysDescription(coveredYear),
        ),
      ],
    );
  }
}

class _ModeGroup extends StatelessWidget {
  const _ModeGroup({required this.selected, required this.onSelected});

  final CalendarLunarMode selected;
  final ValueChanged<CalendarLunarMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpressiveButtonGroup<CalendarLunarMode>(
      segments: <ButtonSegment<CalendarLunarMode>>[
        ButtonSegment<CalendarLunarMode>(
          value: CalendarLunarMode.locale,
          label: Text(l10n.calendarLunarLocale),
        ),
        ButtonSegment<CalendarLunarMode>(
          value: CalendarLunarMode.always,
          label: Text(l10n.calendarLunarAlways),
        ),
        ButtonSegment<CalendarLunarMode>(
          value: CalendarLunarMode.never,
          label: Text(l10n.calendarLunarNever),
        ),
      ],
      selected: <CalendarLunarMode>{selected},
      onSelectionChanged: (Set<CalendarLunarMode> selection) =>
          onSelected(selection.single),
    );
  }
}
