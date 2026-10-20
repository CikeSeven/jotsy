import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/settings_reveal.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// “行为”标签页：下滑收起底栏与指示器跟随滑动（栏的行为，不随预设与
/// 样式码改变，经 `setBehavior` 写入）。
///
/// 下滑收起只作用于悬浮的玻璃底栏，实色时收起这一行、在附注里说明原因
/// （显示一个调了也没有效果的开关只会让人困惑）；存下的值不改写，切回
/// 玻璃即恢复。它与下面的“指示器跟随”合成分组里的同一项，显隐时
/// 不会让后者错位复用、补播开关动画。
class HomeBarStyleBehaviorTab extends StatelessWidget {
  const HomeBarStyleBehaviorTab({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final behavior = controller.behavior;
    final isGlass = controller.style.material == HomeBarMaterial.glass;
    final footer = <String>[
      if (!isGlass) l10n.homeBarStyleHideOnScrollSolidHint,
      l10n.homeBarStyleBehaviorFooter,
    ].join('\n');

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          footer: footer,
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SettingsReveal(
                  visible: isGlass,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SettingsSwitchTile(
                        title: l10n.homeBarStyleHideOnScroll,
                        subtitle: l10n.homeBarStyleHideOnScrollSubtitle,
                        value: behavior.hideOnScroll,
                        onChanged: (bool v) => controller.setBehavior(
                          controller.behavior.copyWith(hideOnScroll: v),
                        ),
                      ),
                      const SettingsCardGroupDivider(),
                    ],
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
        ),
      ],
    );
  }
}
