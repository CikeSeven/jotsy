import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/style_library/style_json.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/settings_reveal.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import '../diary_card_style/diary_card_style_labels.dart';

/// “外观”标签页：导航栏全部的外观选项，分四组：
/// - 玻璃：色调、通透程度（模糊强度随它变化）、顶栏分隔线——顶栏恒为
///   玻璃，没有开关；
/// - 形状：圆角程度、导航项宽度、指示器到胶囊边的缝；
/// - 图标与文字：图标大小、文字怎么显示，显示文字时再展开字号与间距；
/// - 布局：新建按钮放哪。
///
/// 栏高与指示器圆角不单独开放：它们由上面几项推导（见 `HomeBarMetrics`），
/// 任何组合都保持内容居中、指示器与胶囊同心。滑块拖动中只改草稿（预览
/// 即时重绘、不写盘），松手才写入；数值规整到滑块的步进，消除
/// 0.65000001 这类浮点尾数，样式才能与预设按 `==` 相等。
class HomeBarStyleAppearanceTab extends StatelessWidget {
  const HomeBarStyleAppearanceTab({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final highContrast = MediaQuery.highContrastOf(context);
    void commit(HomeBarStyle Function(HomeBarStyle s) update) =>
        controller.commitWith(update);
    String dp(double v) => diaryCardDpLabel(l10n, v);
    String percent(double v) => diaryCardPercentLabel(l10n, v);

    Widget slider({
      required String title,
      required double value,
      required StyleRange range,
      required String Function(double v) label,
      required HomeBarStyle Function(HomeBarStyle s, double v) apply,
      bool nested = false,
    }) {
      return SettingsSliderTile(
        title: title,
        nested: nested,
        value: range.clamp(value),
        min: range.min,
        max: range.max,
        divisions: range.divisions,
        valueLabel: label,
        onChanged: (double v) =>
            controller.previewWith((s) => apply(s, _snap(range, v))),
        onChangeEnd: (double v) => commit((s) => apply(s, _snap(range, v))),
      );
    }

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.homeBarStyleGlassGroup,
          footer: highContrast ? l10n.homeBarStyleHighContrastNote : null,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeBarStyleTint,
              child: ExpressiveButtonGroup<HomeBarTint>(
                minSegmentWidth: 96,
                segments: <ButtonSegment<HomeBarTint>>[
                  ButtonSegment<HomeBarTint>(
                    value: HomeBarTint.neutral,
                    label: Text(l10n.homeBarStyleTintNeutral),
                  ),
                  ButtonSegment<HomeBarTint>(
                    value: HomeBarTint.theme,
                    label: Text(l10n.homeBarStyleTintTheme),
                  ),
                ],
                selected: <HomeBarTint>{style.tint},
                onSelectionChanged: (Set<HomeBarTint> v) =>
                    commit((s) => s.copyWith(tint: v.single)),
              ),
            ),
            slider(
              title: l10n.homeBarStyleOpacity,
              value: style.tintOpacity,
              range: HomeBarStyleLimits.tintOpacity,
              label: percent,
              apply: (s, v) => s.copyWith(tintOpacity: v),
            ),
            SettingsSwitchTile(
              title: l10n.homeBarStyleTopBarHairline,
              subtitle: l10n.homeBarStyleTopBarHairlineSubtitle,
              value: style.topBarHairline,
              onChanged: (bool v) =>
                  commit((s) => s.copyWith(topBarHairline: v)),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.homeBarStyleShapeGroup,
          footer: l10n.homeBarStyleShapeFooter,
          children: <Widget>[
            slider(
              title: l10n.homeBarStyleRoundness,
              value: style.roundness,
              range: HomeBarStyleLimits.roundness,
              label: percent,
              apply: (s, v) => s.copyWith(roundness: v),
            ),
            slider(
              title: l10n.homeBarStyleItemWidth,
              value: style.itemWidth,
              range: HomeBarStyleLimits.itemWidth,
              label: dp,
              apply: (s, v) => s.copyWith(itemWidth: v),
            ),
            slider(
              title: l10n.homeBarStyleItemInset,
              value: style.itemInset,
              range: HomeBarStyleLimits.itemInset,
              label: dp,
              apply: (s, v) => s.copyWith(itemInset: v),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.homeBarStyleItemsGroup,
          children: <Widget>[
            slider(
              title: l10n.homeBarStyleIconSize,
              value: style.itemIconSize,
              range: HomeBarStyleLimits.itemIconSize,
              label: dp,
              apply: (s, v) => s.copyWith(itemIconSize: v),
            ),
            // 文字模式与只在显示文字时才有意义的字号、间距合成一个子项：
            // 收起 / 展开时兄弟行的 State 不错位，也不会让分割线落单。
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
                    onSelectionChanged: (Set<HomeBarLabelMode> v) =>
                        commit((s) => s.copyWith(labelMode: v.single)),
                  ),
                ),
                SettingsReveal(
                  visible: style.labelMode != HomeBarLabelMode.never,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      settingsNestedDivider,
                      slider(
                        title: l10n.homeBarStyleLabelSize,
                        nested: true,
                        value: style.itemLabelSize,
                        range: HomeBarStyleLimits.itemLabelSize,
                        label: dp,
                        apply: (s, v) => s.copyWith(itemLabelSize: v),
                      ),
                      settingsNestedDivider,
                      slider(
                        title: l10n.homeBarStyleLabelGap,
                        nested: true,
                        value: style.itemLabelGap,
                        range: HomeBarStyleLimits.itemLabelGap,
                        label: dp,
                        apply: (s, v) => s.copyWith(itemLabelGap: v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.homeBarStyleLayoutGroup,
          footer: l10n.homeBarStyleFabFooter,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeBarStyleFabGroup,
              child: ExpressiveButtonGroup<HomeBarFabPlacement>(
                minSegmentWidth: 96,
                segments: <ButtonSegment<HomeBarFabPlacement>>[
                  ButtonSegment<HomeBarFabPlacement>(
                    value: HomeBarFabPlacement.above,
                    label: Text(l10n.homeBarStyleFabAbove),
                  ),
                  ButtonSegment<HomeBarFabPlacement>(
                    value: HomeBarFabPlacement.inline,
                    label: Text(l10n.homeBarStyleFabInline),
                  ),
                ],
                selected: <HomeBarFabPlacement>{style.fabPlacement},
                onSelectionChanged: (Set<HomeBarFabPlacement> v) =>
                    commit((s) => s.copyWith(fabPlacement: v.single)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 规整到滑块的步进（再夹到范围内）：只按步进取整，乘回去后再按百分位
  /// 四舍五入，去掉 0.1 × 3 这类浮点尾数。
  static double _snap(StyleRange range, double value) {
    final steps = ((value - range.min) / range.step).round();
    final snapped = range.min + steps * range.step;
    return range.clamp((snapped * 100).round() / 100);
  }
}
