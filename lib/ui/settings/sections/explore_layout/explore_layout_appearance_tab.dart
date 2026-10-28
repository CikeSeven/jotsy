import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../explore/models/explore_appearance.dart';
import '../../../explore/widgets/explore_appearance_scope.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/explore_layout_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// “外观”标签页：卡片（密度、圆角、表面、强调色）、标题与数字（标题样式、
/// 大数字缩写、图表动画）与宽窗口（列数、排布）。选中即写入；圆角滑块拖动
/// 中只改预览，松手才写入。
class ExploreLayoutAppearanceTab extends StatelessWidget {
  const ExploreLayoutAppearanceTab({super.key, required this.controller});

  final ExploreLayoutEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final look = controller.style.appearance;
    void set(ExploreAppearance next) => controller.setAppearance(next);
    Widget choices<T>(
      List<T> values,
      T selected,
      String Function(T value) label,
      ValueChanged<T> onSelected, {
      Widget? Function(T value)? icon,
    }) {
      return ExpressiveButtonGroup<T>(
        minSegmentWidth: 72,
        segments: <ButtonSegment<T>>[
          for (final value in values)
            ButtonSegment<T>(
              value: value,
              icon: icon?.call(value),
              label: Text(label(value)),
            ),
        ],
        selected: <T>{selected},
        onSelectionChanged: (Set<T> next) => onSelected(next.single),
      );
    }

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.exploreLookCards,
          footer: l10n.exploreLookSurfaceGlassNote,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.exploreLookDensity,
              child: choices<ExploreDensity>(
                ExploreDensity.values,
                look.density,
                (value) => switch (value) {
                  ExploreDensity.compact => l10n.exploreLookCompact,
                  ExploreDensity.standard => l10n.exploreLookStandard,
                  ExploreDensity.relaxed => l10n.exploreLookRelaxed,
                },
                (value) => set(look.copyWith(density: value)),
              ),
            ),
            SettingsSliderTile(
              title: l10n.exploreLookRadius,
              value: look.radius,
              min: ExploreAppearance.radiusRange.min,
              max: ExploreAppearance.radiusRange.max,
              divisions: ExploreAppearance.radiusRange.divisions,
              valueLabel: (double value) => '${value.round()}',
              onChanged: (double value) =>
                  controller.previewAppearance(look.copyWith(radius: value)),
              onChangeEnd: (double value) =>
                  set(controller.style.appearance.copyWith(radius: value)),
            ),
            SettingsChoiceTile(
              title: l10n.exploreLookSurface,
              child: choices<ExploreCardSurface>(
                ExploreCardSurface.values,
                look.surface,
                (value) => switch (value) {
                  ExploreCardSurface.filled => l10n.exploreLookFilled,
                  ExploreCardSurface.tonal => l10n.exploreLookTonal,
                  ExploreCardSurface.outlined => l10n.exploreLookOutlined,
                },
                (value) => set(look.copyWith(surface: value)),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.exploreLookAccent,
              child: choices<ExploreAccent>(
                ExploreAccent.values,
                look.accent,
                (value) => switch (value) {
                  ExploreAccent.primary => l10n.exploreLookPrimary,
                  ExploreAccent.secondary => l10n.exploreLookSecondary,
                  ExploreAccent.tertiary => l10n.exploreLookTertiary,
                },
                (value) => set(look.copyWith(accent: value)),
                icon: (value) => Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: look.copyWith(accent: value).accentOf(scheme),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.exploreLookText,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.exploreLookHeading,
              child: choices<ExploreHeadingStyle>(
                ExploreHeadingStyle.values,
                look.heading,
                (value) => switch (value) {
                  ExploreHeadingStyle.badge => l10n.exploreLookBadge,
                  ExploreHeadingStyle.icon => l10n.exploreLookIcon,
                  ExploreHeadingStyle.text => l10n.exploreLookTextOnly,
                  ExploreHeadingStyle.hidden => l10n.exploreLookHidden,
                },
                (value) => set(look.copyWith(heading: value)),
              ),
            ),
            SettingsSwitchTile(
              title: l10n.exploreLookCompactNumbers,
              subtitle: l10n.exploreLookCompactNumbersSubtitle,
              value: look.compactNumbers,
              onChanged: (bool value) =>
                  set(look.copyWith(compactNumbers: value)),
            ),
            SettingsSwitchTile(
              title: l10n.exploreLookAnimations,
              subtitle: l10n.exploreLookAnimationsSubtitle,
              value: look.animations,
              onChanged: (bool value) => set(look.copyWith(animations: value)),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.exploreLookWide,
          footer: l10n.exploreLookWideFooter,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.exploreLookColumns,
              child: choices<ExploreWideColumns>(
                ExploreWideColumns.values,
                look.columns,
                (value) => switch (value) {
                  ExploreWideColumns.auto => l10n.exploreValAuto,
                  ExploreWideColumns.one => l10n.exploreValColumns(1),
                  ExploreWideColumns.two => l10n.exploreValColumns(2),
                  ExploreWideColumns.three => l10n.exploreValColumns(3),
                },
                (value) => set(look.copyWith(columns: value)),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.exploreLookFlow,
              child: choices<ExploreWideFlow>(
                ExploreWideFlow.values,
                look.flow,
                (value) => switch (value) {
                  ExploreWideFlow.rows => l10n.exploreLookRows,
                  ExploreWideFlow.staggered => l10n.exploreLookStaggered,
                },
                (value) => set(look.copyWith(flow: value)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
