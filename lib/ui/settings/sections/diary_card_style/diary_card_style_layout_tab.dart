import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import 'diary_card_style_common.dart';
import 'diary_card_style_labels.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// “布局”标签页：圆角与对齐（共用），内边距、间距、边距与瀑布流列数
/// （当前布局专属）。
class DiaryCardStyleLayoutTab extends StatelessWidget {
  const DiaryCardStyleLayoutTab({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final m = controller.modeStyle;
    String dp(double value) => diaryCardDpLabel(l10n, value);

    Widget modeSlider({
      required String title,
      required double value,
      required DiaryCardRange range,
      required DiaryCardModeStyle Function(DiaryCardModeStyle, double) apply,
    }) {
      return SettingsSliderTile(
        title: title,
        value: value,
        min: range.min,
        max: range.max,
        divisions: range.divisions,
        valueLabel: dp,
        onChanged: (double v) => controller.previewMode((s) => apply(s, v)),
        onChangeEnd: (double v) => controller.commitMode((s) => apply(s, v)),
      );
    }

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.diaryCardStyleSharedGroup,
          children: <Widget>[
            SettingsSliderTile(
              title: l10n.diaryCardStyleCornerRadius,
              value: style.surface.cornerRadius,
              min: DiaryCardStyleLimits.cornerRadius.min,
              max: DiaryCardStyleLimits.cornerRadius.max,
              divisions: DiaryCardStyleLimits.cornerRadius.divisions,
              valueLabel: dp,
              onChanged: (double v) => controller.preview(
                style.copyWith(
                  surface: style.surface.copyWith(cornerRadius: v),
                ),
              ),
              onChangeEnd: (double v) => controller.commit(
                style.copyWith(
                  surface: style.surface.copyWith(cornerRadius: v),
                ),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.diaryCardStyleTextAlign,
              child: ExpressiveButtonGroup<DiaryCardTextAlign>(
                segments: <ButtonSegment<DiaryCardTextAlign>>[
                  ButtonSegment<DiaryCardTextAlign>(
                    value: DiaryCardTextAlign.start,
                    icon: const FaIcon(FontAwesomeIcons.alignLeft, size: 14),
                    label: Text(l10n.diaryCardStyleAlignStart),
                  ),
                  ButtonSegment<DiaryCardTextAlign>(
                    value: DiaryCardTextAlign.center,
                    icon: const FaIcon(FontAwesomeIcons.alignCenter, size: 14),
                    label: Text(l10n.diaryCardStyleAlignCenter),
                  ),
                ],
                selected: <DiaryCardTextAlign>{style.typography.textAlign},
                onSelectionChanged: (Set<DiaryCardTextAlign> value) =>
                    controller.commit(
                      style.copyWith(
                        typography: style.typography.copyWith(
                          textAlign: value.single,
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
        diaryCardModeGroup(
          context,
          mode: controller.mode,
          footer: controller.mode == DiaryCardMode.waterfall
              ? l10n.diaryCardStyleColumnsFootnote
              : null,
          children: <Widget>[
            if (controller.mode == DiaryCardMode.waterfall)
              SettingsChoiceTile(
                title: l10n.diaryCardStyleColumns,
                child: ExpressiveButtonGroup<int>(
                  segments: <ButtonSegment<int>>[
                    for (
                      var count = DiaryCardStyleLimits.columns.min.round();
                      count <= DiaryCardStyleLimits.columns.max.round();
                      count++
                    )
                      ButtonSegment<int>(
                        value: count,
                        label: Text(l10n.diaryCardStyleColumnsValue(count)),
                      ),
                  ],
                  selected: <int>{m.columns},
                  onSelectionChanged: (Set<int> value) => controller.commitMode(
                    (s) => s.copyWith(columns: value.single),
                  ),
                ),
              ),
            modeSlider(
              title: l10n.diaryCardStylePaddingH,
              value: m.paddingH,
              range: DiaryCardStyleLimits.paddingH,
              apply: (s, v) => s.copyWith(paddingH: v),
            ),
            modeSlider(
              title: l10n.diaryCardStylePaddingV,
              value: m.paddingV,
              range: DiaryCardStyleLimits.paddingV,
              apply: (s, v) => s.copyWith(paddingV: v),
            ),
            modeSlider(
              title: l10n.diaryCardStyleElementGap,
              value: m.elementGap,
              range: DiaryCardStyleLimits.elementGap,
              apply: (s, v) => s.copyWith(elementGap: v),
            ),
            modeSlider(
              title: l10n.diaryCardStyleCardGap,
              value: m.cardGap,
              range: DiaryCardStyleLimits.cardGap,
              apply: (s, v) => s.copyWith(cardGap: v),
            ),
            modeSlider(
              title: l10n.diaryCardStyleSideMargin,
              value: m.sideMargin,
              range: DiaryCardStyleLimits.sideMargin,
              apply: (s, v) => s.copyWith(sideMargin: v),
            ),
          ],
        ),
      ],
    );
  }
}
