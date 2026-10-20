import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_code_block/diary_code_block_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/diary_code_block_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import 'diary_code_theme_card.dart';

/// “配色”标签页：代码块明暗（跟随主题 / 浅色 / 深色）与配色主题网格。点按
/// 即写入。
class DiaryCodeBlockStyleThemeTab extends StatelessWidget {
  const DiaryCodeBlockStyleThemeTab({super.key, required this.controller});

  final DiaryCodeBlockStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.codeBlockBrightnessTitle,
              child: ExpressiveButtonGroup<DiaryCodeBrightness>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<DiaryCodeBrightness>>[
                  ButtonSegment<DiaryCodeBrightness>(
                    value: DiaryCodeBrightness.system,
                    label: Text(l10n.codeBlockBrightnessSystem),
                  ),
                  ButtonSegment<DiaryCodeBrightness>(
                    value: DiaryCodeBrightness.light,
                    label: Text(l10n.codeBlockBrightnessLight),
                  ),
                  ButtonSegment<DiaryCodeBrightness>(
                    value: DiaryCodeBrightness.dark,
                    label: Text(l10n.codeBlockBrightnessDark),
                  ),
                ],
                selected: <DiaryCodeBrightness>{style.brightness},
                onSelectionChanged: (Set<DiaryCodeBrightness> v) => controller
                    .commitWith((s) => s.copyWith(brightness: v.single)),
              ),
            ),
          ],
        ),
        SettingsCardGroup(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: _ThemeGrid(
                selected: style.theme,
                onSelected: (DiaryCodeThemeId id) =>
                    controller.commitWith((s) => s.copyWith(theme: id)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 全部配色主题的两列网格；每行两格等高（只有五行，IntrinsicHeight 的开销
/// 可忽略）。
class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.selected, required this.onSelected});

  final DiaryCodeThemeId selected;
  final ValueChanged<DiaryCodeThemeId> onSelected;

  @override
  Widget build(BuildContext context) {
    const themes = DiaryCodeThemeId.values;
    return Column(
      children: <Widget>[
        for (var row = 0; row < themes.length; row += 2) ...<Widget>[
          if (row > 0) const SizedBox(height: AppSpacing.s),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var col = 0; col < 2; col++) ...<Widget>[
                  if (col > 0) const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: row + col < themes.length
                        ? DiaryCodeThemeCard(
                            theme: themes[row + col],
                            selected: selected == themes[row + col],
                            onTap: () => onSelected(themes[row + col]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
