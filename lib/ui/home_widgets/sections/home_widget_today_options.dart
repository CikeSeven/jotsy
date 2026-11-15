import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/expressive_button_group.dart';
import 'home_widget_almanac_mode_group.dart';

/// 今日小组件的内容选项：农历与节气、法定节假日（三档与日历页一致）、今天
/// 写了多少、到期待办（待办功能开启时）、今年进度、心情脸，以及点按打开哪里
/// （日历关闭时没有“日历”这一项）。
class HomeWidgetTodayOptions extends ConsumerWidget {
  const HomeWidgetTodayOptions({
    super.key,
    required this.content,
    required this.onChanged,
  });

  final TodayContent content;
  final ValueChanged<TodayContent> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final features = ref.watch(appFeaturesProvider);
    final taps = <TodayTapAction>[
      if (features.calendar) TodayTapAction.calendar,
      TodayTapAction.write,
      TodayTapAction.app,
    ];
    final tap = taps.contains(content.tapAction)
        ? content.tapAction
        : TodayTapAction.app;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeWidgetTodayLunar,
              child: HomeWidgetAlmanacModeGroup(
                value: content.lunar,
                onChanged: (HomeWidgetAlmanacMode mode) =>
                    onChanged(content.copyWith(lunar: mode)),
              ),
            ),
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
        const SizedBox(height: 16),
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.homeWidgetTodayWriting,
              value: content.showWriting,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showWriting: value)),
            ),
            if (features.todos)
              SettingsSwitchTile(
                title: l10n.homeWidgetTodayShowTodos,
                value: content.showTodos,
                onChanged: (bool value) =>
                    onChanged(content.copyWith(showTodos: value)),
              ),
            SettingsSwitchTile(
              title: l10n.homeWidgetTodayYearProgress,
              value: content.showYearProgress,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showYearProgress: value)),
            ),
            SettingsSwitchTile(
              title: l10n.homeWidgetTodayMood,
              subtitle: l10n.homeWidgetTodayMoodHint,
              value: content.showMood,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showMood: value)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeWidgetTapAction,
              child: ExpressiveButtonGroup<TodayTapAction>(
                minSegmentWidth: 88,
                segments: <ButtonSegment<TodayTapAction>>[
                  for (final action in taps)
                    ButtonSegment<TodayTapAction>(
                      value: action,
                      label: Text(switch (action) {
                        TodayTapAction.calendar => l10n.homeWidgetTapCalendar,
                        TodayTapAction.write => l10n.homeWidgetTapWrite,
                        TodayTapAction.app => l10n.homeWidgetTapApp,
                      }),
                    ),
                ],
                selected: <TodayTapAction>{tap},
                onSelectionChanged: (Set<TodayTapAction> value) =>
                    onChanged(content.copyWith(tapAction: value.first)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
