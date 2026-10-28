import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../explore/sections/explore_period_bar.dart';
import '../../controllers/explore_layout_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// “范围”标签页：是否在探索页顶部显示统计范围条，以及当前的统计范围（范围
/// 条关掉时在这里改）。统计范围属于行为，不随预设、我的布局与布局码改变。
class ExploreLayoutRangeTab extends StatelessWidget {
  const ExploreLayoutRangeTab({super.key, required this.controller});

  final ExploreLayoutEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          footer: l10n.exploreRangeFooter,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.exploreRangeBar,
              subtitle: l10n.exploreRangeBarSubtitle,
              value: controller.style.showPeriodBar,
              onChanged: controller.setShowPeriodBar,
            ),
            SettingsChoiceTile(
              title: l10n.exploreRangeCurrent,
              child: ExplorePeriodBar(
                period: controller.period,
                onChanged: controller.setPeriod,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
