import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import 'home_bar_style_common.dart';

/// “导航项”标签页：文字显示方式、图标大小与选中指示器。实色与玻璃两种
/// 材质共用这些选项，因此不随材质显隐。
class HomeBarStyleItemsTab extends StatelessWidget {
  const HomeBarStyleItemsTab({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeBarStyleLabels,
              child: ExpressiveButtonGroup<HomeBarLabelMode>(
                minSegmentWidth: 88,
                segments: <ButtonSegment<HomeBarLabelMode>>[
                  ButtonSegment<HomeBarLabelMode>(
                    value: HomeBarLabelMode.always,
                    label: Text(l10n.homeBarStyleLabelsAlways),
                  ),
                  ButtonSegment<HomeBarLabelMode>(
                    value: HomeBarLabelMode.selected,
                    label: Text(l10n.homeBarStyleLabelsSelected),
                  ),
                  ButtonSegment<HomeBarLabelMode>(
                    value: HomeBarLabelMode.never,
                    label: Text(l10n.homeBarStyleLabelsNever),
                  ),
                ],
                selected: <HomeBarLabelMode>{style.labelMode},
                onSelectionChanged: (Set<HomeBarLabelMode> v) => controller
                    .commitWith((s) => s.copyWith(labelMode: v.single)),
              ),
            ),
            homeBarSlider(
              controller: controller,
              title: l10n.homeBarStyleIconSize,
              range: HomeBarStyleLimits.iconSize,
              value: style.iconSize,
              valueLabel: (double v) =>
                  l10n.diaryCardStyleValueDp('${v.round()}'),
              apply: (s, v) => s.copyWith(iconSize: v),
            ),
            SettingsChoiceTile(
              title: l10n.homeBarStyleIndicator,
              child: ExpressiveButtonGroup<HomeBarIndicator>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<HomeBarIndicator>>[
                  ButtonSegment<HomeBarIndicator>(
                    value: HomeBarIndicator.capsule,
                    label: Text(l10n.homeBarStyleIndicatorCapsule),
                  ),
                  ButtonSegment<HomeBarIndicator>(
                    value: HomeBarIndicator.block,
                    label: Text(l10n.homeBarStyleIndicatorBlock),
                  ),
                  ButtonSegment<HomeBarIndicator>(
                    value: HomeBarIndicator.none,
                    label: Text(l10n.homeBarStyleIndicatorNone),
                  ),
                ],
                selected: <HomeBarIndicator>{style.indicator},
                onSelectionChanged: (Set<HomeBarIndicator> v) => controller
                    .commitWith((s) => s.copyWith(indicator: v.single)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
