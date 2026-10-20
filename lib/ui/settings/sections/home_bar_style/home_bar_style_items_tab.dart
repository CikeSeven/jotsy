import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/settings_reveal.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import 'home_bar_style_common.dart';

/// “导航项”标签页：文字显示方式与图标文字间距、图标大小、选中指示器与
/// 色块内边距。实色与玻璃两种材质共用这些选项，因此不随材质显隐。
///
/// 间距只在显示文字时有意义、内边距只属于色块，它们作为从属行缩进一级，
/// 并与所从属的选择器合成分组里的同一项（经 SettingsReveal 显隐）：分组按
/// 位置复用子项并在子项之间插分割线，单独增删会多出分割线，后面的行也会
/// 接手前一行的状态。
class HomeBarStyleItemsTab extends StatelessWidget {
  const HomeBarStyleItemsTab({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    String dp(double v) => l10n.diaryCardStyleValueDp('${v.round()}');
    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          footer: l10n.homeBarStyleItemsFooter,
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                SettingsReveal(
                  visible: style.labelMode != HomeBarLabelMode.never,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      settingsNestedDivider,
                      homeBarSlider(
                        nested: true,
                        controller: controller,
                        title: l10n.homeBarStyleLabelGap,
                        range: HomeBarStyleLimits.labelGap,
                        value: style.labelGap,
                        valueLabel: dp,
                        apply: (s, v) => s.copyWith(labelGap: v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            homeBarSlider(
              controller: controller,
              title: l10n.homeBarStyleIconSize,
              range: HomeBarStyleLimits.iconSize,
              value: style.iconSize,
              valueLabel: dp,
              apply: (s, v) => s.copyWith(iconSize: v),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
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
                SettingsReveal(
                  visible: style.indicator == HomeBarIndicator.block,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      settingsNestedDivider,
                      homeBarSlider(
                        nested: true,
                        controller: controller,
                        title: l10n.homeBarStyleBlockPadding,
                        range: HomeBarStyleLimits.blockPadding,
                        value: style.blockPadding,
                        valueLabel: dp,
                        apply: (s, v) => s.copyWith(blockPadding: v),
                      ),
                    ],
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
