import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_reveal.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import 'home_bar_style_common.dart';

/// “悬浮栏”标签页：悬浮底栏的尺寸与新建按钮位置。
///
/// 悬浮栏只存在于玻璃材质：实色时整页换成一段说明和“切换到玻璃”按钮，
/// 而不是一排禁用的滑块（调了也看不到效果）。两种内容按材质整体切换并带
/// 过渡，切到玻璃时尺寸分组从说明处展开。
class HomeBarStyleFloatingTab extends StatelessWidget {
  const HomeBarStyleFloatingTab({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final isGlass = controller.style.material == HomeBarMaterial.glass;
    return StyleEditorTabList(
      children: <Widget>[
        SettingsReveal.swap(
          child: isGlass
              ? _GlassOptions(
                  key: const ValueKey<HomeBarMaterial>(HomeBarMaterial.glass),
                  controller: controller,
                )
              : _SolidHint(
                  key: const ValueKey<HomeBarMaterial>(HomeBarMaterial.solid),
                  controller: controller,
                ),
        ),
      ],
    );
  }
}

class _SolidHint extends StatelessWidget {
  const _SolidHint({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SettingsCardGroup(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.homeBarStyleFloatingSolidHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => controller.commitWith(
                  (s) => s.copyWith(material: HomeBarMaterial.glass),
                ),
                child: Text(l10n.homeBarStyleSwitchToGlass),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassOptions extends StatelessWidget {
  const _GlassOptions({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    String dp(double v) => l10n.diaryCardStyleValueDp('${v.round()}');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.homeBarStyleSizeGroup,
          children: <Widget>[
            homeBarSlider(
              controller: controller,
              title: l10n.homeBarStyleHeight,
              range: HomeBarStyleLimits.barHeight,
              value: style.barHeight,
              valueLabel: dp,
              apply: (s, v) => s.copyWith(barHeight: v),
            ),
            homeBarSlider(
              controller: controller,
              title: l10n.homeBarStyleCornerRadius,
              range: HomeBarStyleLimits.cornerRadius,
              value: style.cornerRadius,
              valueLabel: dp,
              apply: (s, v) => s.copyWith(cornerRadius: v),
            ),
            homeBarSlider(
              controller: controller,
              title: l10n.homeBarStyleSideMargin,
              range: HomeBarStyleLimits.sideMargin,
              value: style.sideMargin,
              valueLabel: dp,
              apply: (s, v) => s.copyWith(sideMargin: v),
            ),
            homeBarSlider(
              controller: controller,
              title: l10n.homeBarStyleBottomGap,
              range: HomeBarStyleLimits.bottomGap,
              value: style.bottomGap,
              valueLabel: dp,
              apply: (s, v) => s.copyWith(bottomGap: v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.homeBarStyleFabGroup,
          footer: l10n.homeBarStyleFabFooter,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
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
                onSelectionChanged: (Set<HomeBarFabPlacement> v) => controller
                    .commitWith((s) => s.copyWith(fabPlacement: v.single)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
