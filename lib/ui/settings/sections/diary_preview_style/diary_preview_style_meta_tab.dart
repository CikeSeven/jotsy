import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_style.dart';
import '../../../diaries/viewmodels/diary_card_date_formatter.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../../widgets/expressive_choice_tile.dart';
import '../../../widgets/expressive_icon_choice_row.dart';
import '../../controllers/diary_preview_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import 'diary_preview_style_labels.dart';

/// “信息”标签页：位置与版式、显示哪些信息、时间格式（附实时示例）、标签与
/// 心情精力的样式。
class DiaryPreviewStyleMetaTab extends StatelessWidget {
  const DiaryPreviewStyleMetaTab({super.key, required this.controller});

  final DiaryPreviewStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meta = controller.style.meta;
    final now = DateTime.now();
    // 示例取“三天前的上午”：相对时间读作“3 天前”，日期也不是今天。
    final sample = DateTime(
      now.year,
      now.month,
      now.day,
      9,
      30,
    ).subtract(const Duration(days: 3));

    void commit(DiaryPreviewMetaStyle next) =>
        controller.commitWith((style) => style.copyWith(meta: next));

    String example(DiaryCardDateFormat format) => DiaryCardDateFormatter.format(
      l10n: l10n,
      format: format,
      showWeekday: meta.showWeekday,
      showTime: meta.showTime,
      date: sample,
      now: now,
    );

    final relative = meta.dateFormat == DiaryCardDateFormat.relative;
    Widget toggle(
      String title,
      bool value,
      DiaryPreviewMetaStyle Function(bool value) update,
    ) => SettingsSwitchTile(
      title: title,
      value: value,
      onChanged: (bool v) => commit(update(v)),
    );

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleMetaPosition,
              child: ExpressiveButtonGroup<DiaryPreviewMetaPosition>(
                minSegmentWidth: 80,
                segments: <ButtonSegment<DiaryPreviewMetaPosition>>[
                  ButtonSegment<DiaryPreviewMetaPosition>(
                    value: DiaryPreviewMetaPosition.aboveTitle,
                    label: Text(l10n.diaryPreviewStyleMetaAbove),
                  ),
                  ButtonSegment<DiaryPreviewMetaPosition>(
                    value: DiaryPreviewMetaPosition.belowTitle,
                    label: Text(l10n.diaryPreviewStyleMetaBelow),
                  ),
                  ButtonSegment<DiaryPreviewMetaPosition>(
                    value: DiaryPreviewMetaPosition.end,
                    label: Text(l10n.diaryPreviewStyleMetaEnd),
                  ),
                ],
                selected: <DiaryPreviewMetaPosition>{meta.position},
                onSelectionChanged: (Set<DiaryPreviewMetaPosition> v) =>
                    commit(meta.copyWith(position: v.single)),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleMetaLayout,
              child: ExpressiveIconChoiceRow<DiaryPreviewMetaLayout>(
                choices: diaryPreviewMetaLayoutChoices(l10n),
                selected: meta.layout,
                onSelected: (DiaryPreviewMetaLayout layout) =>
                    commit(meta.copyWith(layout: layout)),
              ),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryPreviewStyleMetaItems,
          children: <Widget>[
            toggle(
              l10n.diaryPreviewStyleShowDate,
              meta.showDate,
              (v) => meta.copyWith(showDate: v),
            ),
            toggle(
              l10n.diaryPreviewStyleShowWordCount,
              meta.showWordCount,
              (v) => meta.copyWith(showWordCount: v),
            ),
            // 阅读时长跟在字数后面，只在显示字数时可调。
            if (meta.showWordCount)
              toggle(
                l10n.diaryPreviewStyleShowReadingTime,
                meta.showReadingTime,
                (v) => meta.copyWith(showReadingTime: v),
              ),
            toggle(
              l10n.diaryPreviewStyleShowLocation,
              meta.showLocation,
              (v) => meta.copyWith(showLocation: v),
            ),
            toggle(
              l10n.diaryPreviewStyleShowWeather,
              meta.showWeather,
              (v) => meta.copyWith(showWeather: v),
            ),
            toggle(
              l10n.diaryPreviewStyleShowMood,
              meta.showMood,
              (v) => meta.copyWith(showMood: v),
            ),
            toggle(
              l10n.diaryPreviewStyleShowEnergy,
              meta.showEnergy,
              (v) => meta.copyWith(showEnergy: v),
            ),
            toggle(
              l10n.diaryPreviewStyleShowTags,
              meta.showTags,
              (v) => meta.copyWith(showTags: v),
            ),
          ],
        ),
        if (meta.showDate)
          SettingsCardGroup(
            title: l10n.diaryCardStyleDateFormat,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final (format, label)
                        in <(DiaryCardDateFormat, String)>[
                          (
                            DiaryCardDateFormat.relative,
                            l10n.diaryCardStyleDateRelative,
                          ),
                          (
                            DiaryCardDateFormat.eyebrow,
                            l10n.diaryCardStyleDateEyebrow,
                          ),
                          (
                            DiaryCardDateFormat.full,
                            l10n.diaryCardStyleDateFull,
                          ),
                          (
                            DiaryCardDateFormat.numeric,
                            l10n.diaryCardStyleDateNumeric,
                          ),
                        ])
                      ExpressiveChoiceTile(
                        label: label,
                        description: example(format),
                        centerIndicator: true,
                        selected: meta.dateFormat == format,
                        onTap: () => commit(meta.copyWith(dateFormat: format)),
                      ),
                  ],
                ),
              ),
              SettingsSwitchTile(
                title: l10n.diaryCardStyleShowWeekday,
                subtitle: relative ? l10n.diaryCardStyleRelativeNote : null,
                value: meta.showWeekday,
                onChanged: relative
                    ? null
                    : (bool v) => commit(meta.copyWith(showWeekday: v)),
              ),
              SettingsSwitchTile(
                title: l10n.diaryCardStyleShowTime,
                subtitle: relative ? l10n.diaryCardStyleRelativeNote : null,
                value: meta.showTime,
                onChanged: relative
                    ? null
                    : (bool v) => commit(meta.copyWith(showTime: v)),
              ),
              SettingsChoiceTile(
                title: l10n.diaryCardStyleDateSource,
                child: ExpressiveButtonGroup<DiaryCardDateSource>(
                  segments: <ButtonSegment<DiaryCardDateSource>>[
                    ButtonSegment<DiaryCardDateSource>(
                      value: DiaryCardDateSource.created,
                      label: Text(l10n.diaryCardStyleDateCreated),
                    ),
                    ButtonSegment<DiaryCardDateSource>(
                      value: DiaryCardDateSource.updated,
                      label: Text(l10n.diaryCardStyleDateUpdated),
                    ),
                  ],
                  selected: <DiaryCardDateSource>{meta.dateSource},
                  onSelectionChanged: (Set<DiaryCardDateSource> v) =>
                      commit(meta.copyWith(dateSource: v.single)),
                ),
              ),
              SettingsSwitchTile(
                title: l10n.diaryPreviewStyleDatePrefix,
                value: meta.datePrefix,
                onChanged: (bool v) => commit(meta.copyWith(datePrefix: v)),
              ),
            ],
          ),
        SettingsCardGroup(
          title: l10n.diaryPreviewStyleChipsGroup,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleTagStyle,
              child: ExpressiveButtonGroup<DiaryCardTagStyle>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<DiaryCardTagStyle>>[
                  ButtonSegment<DiaryCardTagStyle>(
                    value: DiaryCardTagStyle.chip,
                    label: Text(l10n.diaryCardStyleTagChip),
                  ),
                  ButtonSegment<DiaryCardTagStyle>(
                    value: DiaryCardTagStyle.plain,
                    label: Text(l10n.diaryCardStyleTagPlain),
                  ),
                  ButtonSegment<DiaryCardTagStyle>(
                    value: DiaryCardTagStyle.dot,
                    label: Text(l10n.diaryCardStyleTagDot),
                  ),
                ],
                selected: <DiaryCardTagStyle>{meta.tagStyle},
                onSelectionChanged: (Set<DiaryCardTagStyle> v) =>
                    commit(meta.copyWith(tagStyle: v.single)),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleChipStyle,
              child: ExpressiveButtonGroup<DiaryPreviewChipStyle>(
                segments: <ButtonSegment<DiaryPreviewChipStyle>>[
                  ButtonSegment<DiaryPreviewChipStyle>(
                    value: DiaryPreviewChipStyle.chip,
                    label: Text(l10n.diaryPreviewStyleChipChip),
                  ),
                  ButtonSegment<DiaryPreviewChipStyle>(
                    value: DiaryPreviewChipStyle.plain,
                    label: Text(l10n.diaryPreviewStyleChipPlain),
                  ),
                ],
                selected: <DiaryPreviewChipStyle>{meta.chipStyle},
                onSelectionChanged: (Set<DiaryPreviewChipStyle> v) =>
                    commit(meta.copyWith(chipStyle: v.single)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
