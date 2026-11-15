import 'package:flutter/material.dart';

import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_button_group.dart';

/// 农历 / 节假日的三档：跟随语言、显示、隐藏（文案与日历页的显示选项共用）。
class HomeWidgetAlmanacModeGroup extends StatelessWidget {
  const HomeWidgetAlmanacModeGroup({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final HomeWidgetAlmanacMode value;
  final ValueChanged<HomeWidgetAlmanacMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpressiveButtonGroup<HomeWidgetAlmanacMode>(
      minSegmentWidth: 88,
      segments: <ButtonSegment<HomeWidgetAlmanacMode>>[
        ButtonSegment(
          value: HomeWidgetAlmanacMode.locale,
          label: Text(l10n.calendarLunarLocale),
        ),
        ButtonSegment(
          value: HomeWidgetAlmanacMode.always,
          label: Text(l10n.calendarLunarAlways),
        ),
        ButtonSegment(
          value: HomeWidgetAlmanacMode.never,
          label: Text(l10n.calendarLunarNever),
        ),
      ],
      selected: <HomeWidgetAlmanacMode>{value},
      onSelectionChanged: (Set<HomeWidgetAlmanacMode> selected) =>
          onChanged(selected.first),
    );
  }
}
