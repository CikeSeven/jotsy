import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/expressive_icon_choice_row.dart';
import '../models/calendar_display_options.dart';

// 日历显示选项面板中的“日期格”分组：样式图标选择器、样式说明文案与只属于
// 某种样式的子选项。输入当前选项，输出用户选择；不保存状态。

String _cellStyleLabel(AppLocalizations l10n, CalendarCellStyle style) {
  return switch (style) {
    CalendarCellStyle.dot => l10n.calendarCellStyleDot,
    CalendarCellStyle.mood => l10n.calendarCellStyleMood,
    CalendarCellStyle.heat => l10n.calendarCellStyleHeat,
    CalendarCellStyle.photo => l10n.calendarCellStylePhoto,
    CalendarCellStyle.tags => l10n.calendarCellStyleTags,
  };
}

String calendarCellStyleDescription(
  AppLocalizations l10n,
  CalendarCellStyle style,
) {
  return switch (style) {
    CalendarCellStyle.dot => l10n.calendarCellStyleDotDescription,
    CalendarCellStyle.mood => l10n.calendarCellStyleMoodDescription,
    CalendarCellStyle.heat => l10n.calendarCellStyleHeatDescription,
    CalendarCellStyle.photo => l10n.calendarCellStylePhotoDescription,
    CalendarCellStyle.tags => l10n.calendarCellStyleTagsDescription,
  };
}

FaIconData _cellStyleIcon(CalendarCellStyle style) {
  return switch (style) {
    CalendarCellStyle.dot => FontAwesomeIcons.circleDot,
    CalendarCellStyle.mood => FontAwesomeIcons.faceSmile,
    CalendarCellStyle.heat => FontAwesomeIcons.fire,
    CalendarCellStyle.photo => FontAwesomeIcons.image,
    CalendarCellStyle.tags => FontAwesomeIcons.tags,
  };
}

/// 五种日期格样式并排的图标选择器：一行放下，比五个带说明的单选项省出
/// 大半屏高度，网格在面板上方仍看得见。
class CalendarCellStylePicker extends StatelessWidget {
  const CalendarCellStylePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CalendarCellStyle selected;
  final ValueChanged<CalendarCellStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpressiveIconChoiceRow<CalendarCellStyle>(
      choices: <ExpressiveIconChoice<CalendarCellStyle>>[
        for (final style in CalendarCellStyle.values)
          ExpressiveIconChoice<CalendarCellStyle>(
            value: style,
            icon: _cellStyleIcon(style),
            label: _cellStyleLabel(l10n, style),
          ),
      ],
      selected: selected,
      onSelected: onSelected,
    );
  }
}

/// 只属于某一种样式的子选项（心情的平均/逐篇、热力的篇数/字数）。切换
/// 样式时高度经 AnimatedSize 过渡，下方分组不在一帧内跳动。
class CalendarCellStyleSubOptions extends StatelessWidget {
  const CalendarCellStyleSubOptions({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final CalendarDisplayOptions options;
  final ValueChanged<CalendarDisplayOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget? group = switch (options.cellStyle) {
      CalendarCellStyle.mood => ExpressiveButtonGroup<CalendarMoodAggregation>(
        segments: <ButtonSegment<CalendarMoodAggregation>>[
          ButtonSegment<CalendarMoodAggregation>(
            value: CalendarMoodAggregation.average,
            label: Text(l10n.calendarMoodAverage),
          ),
          ButtonSegment<CalendarMoodAggregation>(
            value: CalendarMoodAggregation.each,
            label: Text(l10n.calendarMoodEach),
          ),
        ],
        selected: <CalendarMoodAggregation>{options.moodAggregation},
        onSelectionChanged: (Set<CalendarMoodAggregation> selection) =>
            onChanged(options.copyWith(moodAggregation: selection.single)),
      ),
      CalendarCellStyle.heat => ExpressiveButtonGroup<CalendarHeatBasis>(
        segments: <ButtonSegment<CalendarHeatBasis>>[
          ButtonSegment<CalendarHeatBasis>(
            value: CalendarHeatBasis.entries,
            label: Text(l10n.calendarHeatBasisEntries),
          ),
          ButtonSegment<CalendarHeatBasis>(
            value: CalendarHeatBasis.words,
            label: Text(l10n.calendarHeatBasisWords),
          ),
        ],
        selected: <CalendarHeatBasis>{options.heatBasis},
        onSelectionChanged: (Set<CalendarHeatBasis> selection) =>
            onChanged(options.copyWith(heatBasis: selection.single)),
      ),
      _ => null,
    };
    return AnimatedSize(
      duration: ExpressiveMotion.durationNonZero(
        context,
        ExpressiveMotion.medium,
      ),
      curve: ExpressiveMotion.effects,
      alignment: Alignment.topCenter,
      child: group == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.m),
              child: group,
            ),
    );
  }
}
