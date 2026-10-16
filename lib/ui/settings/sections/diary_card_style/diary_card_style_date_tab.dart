import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../diaries/viewmodels/diary_card_date_formatter.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../../widgets/expressive_choice_tile.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import 'diary_card_style_common.dart';

/// “日期”标签页：眉线日期的显隐、格式（每项附当前时间的实时示例）、
/// 星期/时刻与日期依据，以及底栏时间。两种布局共用。
class DiaryCardStyleDateTab extends StatelessWidget {
  const DiaryCardStyleDateTab({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final meta = style.meta;
    final now = DateTime.now();
    // 示例取“三天前的上午”：相对时间读作“3 天前”，日期也不是今天。
    final sample = DateTime(
      now.year,
      now.month,
      now.day,
      9,
      30,
    ).subtract(const Duration(days: 3));

    void commitMeta(DiaryCardMetaStyle next) =>
        controller.commit(style.copyWith(meta: next));

    String eyebrowExample(DiaryCardDateFormat format) =>
        DiaryCardDateFormatter.eyebrow(
          l10n: l10n,
          meta: meta.copyWith(dateFormat: format),
          createdAt: sample,
          updatedAt: sample,
          now: now,
        );

    String? footerExample(DiaryCardFooterTime mode) =>
        DiaryCardDateFormatter.footer(
          l10n: l10n,
          mode: mode,
          createdAt: sample,
          updatedAt: sample,
          now: now,
        );

    final relative = meta.dateFormat == DiaryCardDateFormat.relative;
    final dateFormats = <(DiaryCardDateFormat, String)>[
      (DiaryCardDateFormat.eyebrow, l10n.diaryCardStyleDateEyebrow),
      (DiaryCardDateFormat.full, l10n.diaryCardStyleDateFull),
      (DiaryCardDateFormat.numeric, l10n.diaryCardStyleDateNumeric),
      (DiaryCardDateFormat.relative, l10n.diaryCardStyleDateRelative),
    ];
    final footerModes = <(DiaryCardFooterTime, String)>[
      (DiaryCardFooterTime.relativeUpdated, l10n.diaryCardStyleFooterRelative),
      (DiaryCardFooterTime.absoluteUpdated, l10n.diaryCardStyleFooterUpdated),
      (DiaryCardFooterTime.created, l10n.diaryCardStyleFooterCreated),
      (DiaryCardFooterTime.hidden, l10n.diaryCardStyleFooterHidden),
    ];

    return DiaryCardStyleTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.diaryCardStyleBlockEyebrow,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryCardStyleShowDate,
              value: meta.showDate,
              onChanged: (bool v) => commitMeta(meta.copyWith(showDate: v)),
            ),
            if (meta.showDate) ...<Widget>[
              SettingsChoiceTile(
                title: l10n.diaryCardStyleDateFormat,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final (format, label) in dateFormats)
                      ExpressiveChoiceTile(
                        label: label,
                        description: eyebrowExample(format),
                        selected: meta.dateFormat == format,
                        onTap: () =>
                            commitMeta(meta.copyWith(dateFormat: format)),
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
                    : (bool v) => commitMeta(meta.copyWith(showWeekday: v)),
              ),
              SettingsSwitchTile(
                title: l10n.diaryCardStyleShowTime,
                subtitle: relative ? l10n.diaryCardStyleRelativeNote : null,
                value: meta.showTime,
                onChanged: relative
                    ? null
                    : (bool v) => commitMeta(meta.copyWith(showTime: v)),
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
                      commitMeta(meta.copyWith(dateSource: v.single)),
                ),
              ),
            ],
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryCardStyleFooterTime,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final (mode, label) in footerModes)
                    ExpressiveChoiceTile(
                      label: label,
                      description: footerExample(mode),
                      selected: meta.footerTime == mode,
                      onTap: () => commitMeta(meta.copyWith(footerTime: mode)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
