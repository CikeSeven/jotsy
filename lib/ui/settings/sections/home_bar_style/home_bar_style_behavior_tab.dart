import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// “行为”标签页：下滑收起底栏与指示器跟随滑动（栏的行为，不随预设与
/// 样式码改变，经 `setBehavior` 写入）。
class HomeBarStyleBehaviorTab extends StatelessWidget {
  const HomeBarStyleBehaviorTab({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final behavior = controller.behavior;

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          footer: l10n.homeBarStyleBehaviorFooter,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.homeBarStyleHideOnScroll,
              subtitle: l10n.homeBarStyleHideOnScrollSubtitle,
              value: behavior.hideOnScroll,
              onChanged: (bool v) => controller.setBehavior(
                controller.behavior.copyWith(hideOnScroll: v),
              ),
            ),
            SettingsSwitchTile(
              title: l10n.homeBarStyleIndicatorFollows,
              subtitle: l10n.homeBarStyleIndicatorFollowsSubtitle,
              value: behavior.indicatorFollowsSwipe,
              onChanged: (bool v) => controller.setBehavior(
                controller.behavior.copyWith(indicatorFollowsSwipe: v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
