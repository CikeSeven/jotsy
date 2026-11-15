import 'package:flutter/material.dart';

import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import 'home_widget_almanac_mode_group.dart';

/// 心情月历的内容选项：按心情着色、写过的日子打点、法定节假日（三档与日历
/// 页一致）。一周从哪天开始跟随日历设置，不在这里另设。
class HomeWidgetMoodCalendarOptions extends StatelessWidget {
  const HomeWidgetMoodCalendarOptions({
    super.key,
    required this.content,
    required this.onChanged,
  });

  final MoodCalendarContent content;
  final ValueChanged<MoodCalendarContent> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.homeWidgetMoodCalendarMoods,
              subtitle: l10n.homeWidgetMoodCalendarMoodsHint,
              value: content.showMoods,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showMoods: value)),
            ),
            SettingsSwitchTile(
              title: l10n.homeWidgetMoodCalendarWritten,
              value: content.showWritten,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showWritten: value)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeWidgetTodayHoliday,
              child: HomeWidgetAlmanacModeGroup(
                value: content.holiday,
                onChanged: (HomeWidgetAlmanacMode mode) =>
                    onChanged(content.copyWith(holiday: mode)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
