import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../../widgets/expressive_icon_choice_row.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import 'diary_card_style_common.dart';
import 'diary_card_style_labels.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// “封面”标签页：封面位置与该位置下的尺寸、形状、圆角等（当前布局专属），
/// 以及多图拼贴与无封面占位（共用）。只列出当前位置用得上的选项。
class DiaryCardStyleCoverTab extends StatelessWidget {
  const DiaryCardStyleCoverTab({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final m = controller.modeStyle;
    final position = m.coverPosition;
    final side =
        position == DiaryCardCoverPosition.start ||
        position == DiaryCardCoverPosition.end;
    String dp(double value) => diaryCardDpLabel(l10n, value);

    Widget slider({
      required String title,
      required double value,
      required DiaryCardRange range,
      required DiaryCardModeStyle Function(DiaryCardModeStyle, double) apply,
      String Function(double)? label,
      String? subtitle,
    }) {
      return SettingsSliderTile(
        title: title,
        subtitle: subtitle,
        value: value,
        min: range.min,
        max: range.max,
        divisions: range.divisions,
        valueLabel: label ?? dp,
        onChanged: (double v) => controller.previewMode((s) => apply(s, v)),
        onChangeEnd: (double v) => controller.commitMode((s) => apply(s, v)),
      );
    }

    final modeChildren = <Widget>[
      SettingsChoiceTile(
        title: l10n.diaryCardStyleCoverPosition,
        child: ExpressiveIconChoiceRow<DiaryCardCoverPosition>(
          choices: diaryCardCoverPositionChoices(l10n, controller.mode),
          selected: position,
          onSelected: (DiaryCardCoverPosition value) =>
              controller.commitMode((s) => s.copyWith(coverPosition: value)),
        ),
      ),
      if (side) ...<Widget>[
        slider(
          title: l10n.diaryCardStyleCoverSize,
          subtitle: l10n.diaryCardStyleCoverSizeFootnote,
          value: m.coverSide,
          range: DiaryCardStyleLimits.coverSide,
          apply: (s, v) => s.copyWith(coverSide: v),
        ),
        SettingsChoiceTile(
          title: l10n.diaryCardStyleCoverShape,
          child: ExpressiveIconChoiceRow<DiaryCardCoverShape>(
            choices: diaryCardCoverShapeChoices(l10n),
            selected: m.coverShape,
            onSelected: (DiaryCardCoverShape value) =>
                controller.commitMode((s) => s.copyWith(coverShape: value)),
          ),
        ),
        if (m.coverShape != DiaryCardCoverShape.circle)
          slider(
            title: l10n.diaryCardStyleCoverRadius,
            value: m.coverRadius,
            range: DiaryCardStyleLimits.coverRadius,
            apply: (s, v) => s.copyWith(coverRadius: v),
          ),
        slider(
          title: l10n.diaryCardStyleCoverGap,
          value: m.coverGap,
          range: DiaryCardStyleLimits.coverGap,
          apply: (s, v) => s.copyWith(coverGap: v),
        ),
      ],
      if (position == DiaryCardCoverPosition.top) ...<Widget>[
        slider(
          title: l10n.diaryCardStyleCoverHeight,
          value: m.coverHeight,
          range: DiaryCardStyleLimits.coverHeight,
          apply: (s, v) => s.copyWith(coverHeight: v),
        ),
        SettingsSwitchTile(
          title: l10n.diaryCardStyleCoverInset,
          subtitle: l10n.diaryCardStyleCoverInsetSubtitle,
          value: m.coverInset,
          onChanged: (bool value) =>
              controller.commitMode((s) => s.copyWith(coverInset: value)),
        ),
        if (m.coverInset) ...<Widget>[
          slider(
            title: l10n.diaryCardStyleCoverRadius,
            value: m.coverRadius,
            range: DiaryCardStyleLimits.coverRadius,
            apply: (s, v) => s.copyWith(coverRadius: v),
          ),
          slider(
            title: l10n.diaryCardStyleCoverGap,
            value: m.coverGap,
            range: DiaryCardStyleLimits.coverGap,
            apply: (s, v) => s.copyWith(coverGap: v),
          ),
        ] else
          SettingsSwitchTile(
            title: l10n.diaryCardStyleCoverDivider,
            value: m.coverDivider,
            onChanged: (bool value) =>
                controller.commitMode((s) => s.copyWith(coverDivider: value)),
          ),
      ],
      if (position == DiaryCardCoverPosition.background) ...<Widget>[
        slider(
          title: l10n.diaryCardStyleCoverHeight,
          value: m.coverHeight,
          range: DiaryCardStyleLimits.coverHeight,
          apply: (s, v) => s.copyWith(coverHeight: v),
        ),
        slider(
          title: l10n.diaryCardStyleScrim,
          value: m.scrim,
          range: DiaryCardStyleLimits.scrim,
          apply: (s, v) => s.copyWith(scrim: v),
          label: (double v) => diaryCardPercentLabel(l10n, v),
        ),
      ],
    ];

    return StyleEditorTabList(
      children: <Widget>[
        diaryCardModeGroup(
          context,
          mode: controller.mode,
          children: modeChildren,
        ),
        SettingsCardGroup(
          title: l10n.diaryCardStyleSharedGroup,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryCardStyleCollage,
              subtitle: l10n.diaryCardStyleCollageSubtitle,
              value: style.content.collage,
              onChanged: (bool value) => controller.commit(
                style.copyWith(content: style.content.copyWith(collage: value)),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.diaryCardStyleCoverFallback,
              child: ExpressiveButtonGroup<DiaryCardCoverFallback>(
                minSegmentWidth: 88,
                segments: <ButtonSegment<DiaryCardCoverFallback>>[
                  ButtonSegment<DiaryCardCoverFallback>(
                    value: DiaryCardCoverFallback.none,
                    label: Text(l10n.diaryCardStyleFallbackNone),
                  ),
                  ButtonSegment<DiaryCardCoverFallback>(
                    value: DiaryCardCoverFallback.dateBlock,
                    label: Text(l10n.diaryCardStyleFallbackDate),
                  ),
                  ButtonSegment<DiaryCardCoverFallback>(
                    value: DiaryCardCoverFallback.moodTile,
                    label: Text(l10n.diaryCardStyleFallbackMood),
                  ),
                ],
                selected: <DiaryCardCoverFallback>{style.content.coverFallback},
                onSelectionChanged: (Set<DiaryCardCoverFallback> value) =>
                    controller.commit(
                      style.copyWith(
                        content: style.content.copyWith(
                          coverFallback: value.single,
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
