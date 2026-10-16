import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_button_group.dart';
import '../models/calendar_display_options.dart';
import 'calendar_cell_style_picker.dart';
import 'calendar_options_almanac_section.dart';
import 'calendar_options_controls.dart';

/// 打开日历显示选项面板。
///
/// 与日记列表的视图选项面板同一套交互：选项即点即生效、面板保持打开，由
/// 页面经 [onChanged] 保存；下拉或点遮罩关闭。遮罩比默认浅、面板高度不
/// 放开（默认上限 9/16 屏高，内部滚动）：日历网格在页面上方，调整时能透过
/// 遮罩直接看到格子样式的变化。
Future<void> showCalendarDisplayOptionsSheet(
  BuildContext context, {
  required CalendarDisplayOptions options,
  required ValueChanged<CalendarDisplayOptions> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.16),
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => CalendarDisplayOptionsSheet(
      initialOptions: options,
      onChanged: onChanged,
    ),
  );
}

/// 日历显示选项面板内容。
///
/// 选中态由面板自己维护（初值取打开时的选项）：面板是独立路由，不随页面
/// 重建；打开期间选项只能经由面板修改，本地状态不会与页面分叉。
class CalendarDisplayOptionsSheet extends StatefulWidget {
  const CalendarDisplayOptionsSheet({
    super.key,
    required this.initialOptions,
    required this.onChanged,
  });

  final CalendarDisplayOptions initialOptions;
  final ValueChanged<CalendarDisplayOptions> onChanged;

  @override
  State<CalendarDisplayOptionsSheet> createState() =>
      _CalendarDisplayOptionsSheetState();
}

class _CalendarDisplayOptionsSheetState
    extends State<CalendarDisplayOptionsSheet> {
  late CalendarDisplayOptions _options = widget.initialOptions;

  void _update(CalendarDisplayOptions next) {
    if (next == _options) {
      return;
    }
    setState(() => _options = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final options = _options;
    // “上次的视图”与年视图着色依据不是面板里的选择，不参与“是否已是默认”
    // 的判断。
    final isDefault =
        options.copyWith(
          rememberedFormat: CalendarGridFormat.month,
          yearBasis: CalendarYearBasis.mood,
        ) ==
        const CalendarDisplayOptions();
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.calendarOptionsTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  // 重置保留“上次的视图”记录与年视图着色依据，它们不是在
                  // 面板里选的。
                  onPressed: isDefault
                      ? null
                      : () => _update(
                          CalendarDisplayOptions(
                            rememberedFormat: options.rememberedFormat,
                            yearBasis: options.yearBasis,
                          ),
                        ),
                  child: Text(l10n.calendarOptionsReset),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            CalendarOptionsSectionHeader(
              icon: FontAwesomeIcons.tableCells,
              label: l10n.calendarOptionsCellStyle,
            ),
            const SizedBox(height: AppSpacing.s),
            CalendarCellStylePicker(
              selected: options.cellStyle,
              onSelected: (CalendarCellStyle style) =>
                  _update(options.copyWith(cellStyle: style)),
            ),
            const SizedBox(height: AppSpacing.s),
            CalendarOptionsFadingText(
              text: calendarCellStyleDescription(l10n, options.cellStyle),
            ),
            CalendarCellStyleSubOptions(options: options, onChanged: _update),
            const SizedBox(height: AppSpacing.l),
            CalendarOptionsSectionHeader(
              icon: FontAwesomeIcons.tag,
              label: l10n.calendarOptionsBadges,
            ),
            CalendarOptionSwitch(
              label: l10n.calendarBadgeCount,
              value: options.showCountBadge,
              onChanged: (bool value) =>
                  _update(options.copyWith(showCountBadge: value)),
            ),
            CalendarOptionSwitch(
              label: l10n.calendarBadgeCapsule,
              value: options.showCapsuleBadge,
              onChanged: (bool value) =>
                  _update(options.copyWith(showCapsuleBadge: value)),
            ),
            CalendarOptionSwitch(
              label: l10n.calendarBadgeWeather,
              value: options.showWeatherBadge,
              onChanged: (bool value) =>
                  _update(options.copyWith(showWeatherBadge: value)),
            ),
            const SizedBox(height: AppSpacing.l),
            CalendarOptionsAlmanacSection(options: options, onChanged: _update),
            const SizedBox(height: AppSpacing.l),
            CalendarOptionsSectionHeader(
              icon: FontAwesomeIcons.calendarWeek,
              label: l10n.calendarOptionsLayout,
            ),
            const SizedBox(height: AppSpacing.s),
            CalendarOptionsFieldLabel(text: l10n.calendarOptionsWeekStart),
            ExpressiveButtonGroup<CalendarWeekStart>(
              segments: <ButtonSegment<CalendarWeekStart>>[
                ButtonSegment<CalendarWeekStart>(
                  value: CalendarWeekStart.locale,
                  label: Text(l10n.calendarWeekStartLocale),
                ),
                ButtonSegment<CalendarWeekStart>(
                  value: CalendarWeekStart.monday,
                  label: Text(l10n.calendarWeekStartMonday),
                ),
                ButtonSegment<CalendarWeekStart>(
                  value: CalendarWeekStart.sunday,
                  label: Text(l10n.calendarWeekStartSunday),
                ),
              ],
              selected: <CalendarWeekStart>{options.weekStart},
              onSelectionChanged: (Set<CalendarWeekStart> selection) =>
                  _update(options.copyWith(weekStart: selection.single)),
            ),
            const SizedBox(height: AppSpacing.m),
            CalendarOptionsFieldLabel(text: l10n.calendarOptionsDefaultFormat),
            ExpressiveButtonGroup<CalendarDefaultFormat>(
              segments: <ButtonSegment<CalendarDefaultFormat>>[
                ButtonSegment<CalendarDefaultFormat>(
                  value: CalendarDefaultFormat.month,
                  label: Text(l10n.calendarFormatMonth),
                ),
                ButtonSegment<CalendarDefaultFormat>(
                  value: CalendarDefaultFormat.week,
                  label: Text(l10n.calendarFormatWeek),
                ),
                ButtonSegment<CalendarDefaultFormat>(
                  value: CalendarDefaultFormat.remember,
                  label: Text(l10n.calendarFormatRemember),
                ),
              ],
              selected: <CalendarDefaultFormat>{options.defaultFormat},
              onSelectionChanged: (Set<CalendarDefaultFormat> selection) =>
                  _update(options.copyWith(defaultFormat: selection.single)),
            ),
            const SizedBox(height: AppSpacing.m),
            CalendarOptionsFieldLabel(text: l10n.calendarOptionsDayContent),
            ExpressiveButtonGroup<CalendarDayContentStyle>(
              segments: <ButtonSegment<CalendarDayContentStyle>>[
                ButtonSegment<CalendarDayContentStyle>(
                  value: CalendarDayContentStyle.timeline,
                  label: Text(l10n.calendarDayContentTimeline),
                ),
                ButtonSegment<CalendarDayContentStyle>(
                  value: CalendarDayContentStyle.cards,
                  label: Text(l10n.calendarDayContentCards),
                ),
              ],
              selected: <CalendarDayContentStyle>{options.dayContentStyle},
              onSelectionChanged: (Set<CalendarDayContentStyle> selection) =>
                  _update(options.copyWith(dayContentStyle: selection.single)),
            ),
            const SizedBox(height: AppSpacing.s),
            CalendarOptionSwitch(
              label: l10n.calendarHighlightWeekends,
              value: options.highlightWeekends,
              onChanged: (bool value) =>
                  _update(options.copyWith(highlightWeekends: value)),
            ),
            CalendarOptionSwitch(
              label: l10n.calendarShowWeekNumbers,
              value: options.showWeekNumbers,
              onChanged: (bool value) =>
                  _update(options.copyWith(showWeekNumbers: value)),
            ),
            CalendarOptionSwitch(
              label: l10n.calendarFixedSixWeeks,
              description: l10n.calendarFixedSixWeeksDescription,
              value: options.fixedSixWeeks,
              onChanged: (bool value) =>
                  _update(options.copyWith(fixedSixWeeks: value)),
            ),
            const SizedBox(height: AppSpacing.l),
            CalendarOptionsSectionHeader(
              icon: FontAwesomeIcons.chartSimple,
              label: l10n.calendarOptionsSections,
            ),
            CalendarOptionSwitch(
              label: l10n.calendarShowMonthSummary,
              description: l10n.calendarShowMonthSummaryDescription,
              value: options.showMonthSummary,
              onChanged: (bool value) =>
                  _update(options.copyWith(showMonthSummary: value)),
            ),
            CalendarOptionSwitch(
              label: l10n.calendarShowOnThisDay,
              description: l10n.calendarShowOnThisDayDescription,
              value: options.showOnThisDay,
              onChanged: (bool value) =>
                  _update(options.copyWith(showOnThisDay: value)),
            ),
          ],
        ),
      ),
    );
  }
}
