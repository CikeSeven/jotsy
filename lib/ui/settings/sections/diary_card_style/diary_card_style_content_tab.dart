import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/diary_card_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../settings_diary_card_section.dart';
import 'diary_card_style_common.dart';

/// “内容”标签页：标题/摘要显隐与行数、“无标题”占位、标签（数量沿用独立的
/// 旧设置）、置顶标记、心情天气与底栏附加信息。“无标题”占位只在显示标题时
/// 才有意义，标题关闭时随之收起。
class DiaryCardStyleContentTab extends StatelessWidget {
  const DiaryCardStyleContentTab({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    final content = style.content;
    final meta = style.meta;
    final m = controller.modeStyle;

    void commitContent(DiaryCardContentStyle next) =>
        controller.commit(style.copyWith(content: next));
    void commitMeta(DiaryCardMetaStyle next) =>
        controller.commit(style.copyWith(meta: next));

    Widget lines({
      required String title,
      required int value,
      required DiaryCardRange range,
      required DiaryCardModeStyle Function(DiaryCardModeStyle, int) apply,
    }) {
      return SettingsSliderTile(
        title: title,
        value: value.toDouble(),
        min: range.min,
        max: range.max,
        divisions: range.divisions,
        valueLabel: (double v) => l10n.diaryCardStyleLinesValue(v.round()),
        onChanged: (double v) =>
            controller.previewMode((s) => apply(s, v.round())),
        onChangeEnd: (double v) =>
            controller.commitMode((s) => apply(s, v.round())),
      );
    }

    return DiaryCardStyleTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.diaryCardStyleSharedGroup,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryCardStyleShowTitle,
              value: content.showTitle,
              onChanged: (bool v) =>
                  commitContent(content.copyWith(showTitle: v)),
            ),
            if (content.showTitle)
              SettingsSwitchTile(
                title: l10n.diaryCardStyleShowUntitled,
                subtitle: l10n.diaryCardStyleShowUntitledSubtitle,
                value: content.showUntitled,
                onChanged: (bool v) =>
                    commitContent(content.copyWith(showUntitled: v)),
              ),
            SettingsSwitchTile(
              title: l10n.diaryCardStyleShowPreview,
              value: content.showPreview,
              onChanged: (bool v) =>
                  commitContent(content.copyWith(showPreview: v)),
            ),
            SettingsDiaryCardSection(
              settingsAsync: AsyncData(controller.settingsService),
            ),
            SettingsChoiceTile(
              title: l10n.diaryCardStyleTagStyle,
              child: ExpressiveButtonGroup<DiaryCardTagStyle>(
                minSegmentWidth: 80,
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
                selected: <DiaryCardTagStyle>{content.tagStyle},
                onSelectionChanged: (Set<DiaryCardTagStyle> v) =>
                    commitContent(content.copyWith(tagStyle: v.single)),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.diaryCardStylePinnedBadge,
              child: ExpressiveButtonGroup<DiaryCardPinnedBadge>(
                minSegmentWidth: 96,
                segments: <ButtonSegment<DiaryCardPinnedBadge>>[
                  ButtonSegment<DiaryCardPinnedBadge>(
                    value: DiaryCardPinnedBadge.standard,
                    label: Text(l10n.diaryCardStylePinnedStandard),
                  ),
                  ButtonSegment<DiaryCardPinnedBadge>(
                    value: DiaryCardPinnedBadge.iconOnly,
                    label: Text(l10n.diaryCardStylePinnedIcon),
                  ),
                  ButtonSegment<DiaryCardPinnedBadge>(
                    value: DiaryCardPinnedBadge.hidden,
                    label: Text(l10n.diaryCardStylePinnedHidden),
                  ),
                ],
                selected: <DiaryCardPinnedBadge>{content.pinnedBadge},
                onSelectionChanged: (Set<DiaryCardPinnedBadge> v) =>
                    commitContent(content.copyWith(pinnedBadge: v.single)),
              ),
            ),
            SettingsSwitchTile(
              title: l10n.diaryCardStylePinnedTint,
              subtitle: l10n.diaryCardStylePinnedTintSubtitle,
              value: style.surface.pinnedTint,
              onChanged: (bool v) => controller.commit(
                style.copyWith(surface: style.surface.copyWith(pinnedTint: v)),
              ),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryCardStyleIndicatorStyle,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryCardStyleShowMood,
              value: meta.showMood,
              onChanged: (bool v) => commitMeta(meta.copyWith(showMood: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryCardStyleShowWeather,
              value: meta.showWeather,
              onChanged: (bool v) => commitMeta(meta.copyWith(showWeather: v)),
            ),
            SettingsChoiceTile(
              title: l10n.diaryCardStyleIndicatorStyle,
              child: ExpressiveButtonGroup<DiaryCardIndicatorStyle>(
                segments: <ButtonSegment<DiaryCardIndicatorStyle>>[
                  ButtonSegment<DiaryCardIndicatorStyle>(
                    value: DiaryCardIndicatorStyle.stamp,
                    label: Text(l10n.diaryCardStyleIndicatorStamp),
                  ),
                  ButtonSegment<DiaryCardIndicatorStyle>(
                    value: DiaryCardIndicatorStyle.plain,
                    label: Text(l10n.diaryCardStyleIndicatorPlain),
                  ),
                ],
                selected: <DiaryCardIndicatorStyle>{meta.indicatorStyle},
                onSelectionChanged: (Set<DiaryCardIndicatorStyle> v) =>
                    commitMeta(meta.copyWith(indicatorStyle: v.single)),
              ),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryCardStyleExtras,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryCardStyleShowLocation,
              value: meta.showLocation,
              onChanged: (bool v) => commitMeta(meta.copyWith(showLocation: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryCardStyleShowEnergy,
              value: meta.showEnergy,
              onChanged: (bool v) => commitMeta(meta.copyWith(showEnergy: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryCardStyleShowWordCount,
              value: meta.showWordCount,
              onChanged: (bool v) =>
                  commitMeta(meta.copyWith(showWordCount: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryCardStyleShowMedia,
              value: meta.showMedia,
              onChanged: (bool v) => commitMeta(meta.copyWith(showMedia: v)),
            ),
          ],
        ),
        diaryCardModeGroup(
          context,
          mode: controller.mode,
          children: <Widget>[
            lines(
              title: l10n.diaryCardStyleTitleLines,
              value: m.titleMaxLines,
              range: DiaryCardStyleLimits.titleMaxLines,
              apply: (s, v) => s.copyWith(titleMaxLines: v),
            ),
            lines(
              title: l10n.diaryCardStylePreviewLines,
              value: m.previewMaxLines,
              range: DiaryCardStyleLimits.previewMaxLines,
              apply: (s, v) => s.copyWith(previewMaxLines: v),
            ),
            SettingsChoiceTile(
              title: l10n.diaryCardStyleMetaPosition,
              child: ExpressiveButtonGroup<DiaryCardMetaPosition>(
                minSegmentWidth: 80,
                segments: <ButtonSegment<DiaryCardMetaPosition>>[
                  ButtonSegment<DiaryCardMetaPosition>(
                    value: DiaryCardMetaPosition.eyebrow,
                    label: Text(l10n.diaryCardStyleMetaEyebrow),
                  ),
                  ButtonSegment<DiaryCardMetaPosition>(
                    value: DiaryCardMetaPosition.footer,
                    label: Text(l10n.diaryCardStyleMetaFooter),
                  ),
                  ButtonSegment<DiaryCardMetaPosition>(
                    value: DiaryCardMetaPosition.cover,
                    label: Text(l10n.diaryCardStyleMetaCover),
                  ),
                ],
                selected: <DiaryCardMetaPosition>{m.metaPosition},
                onSelectionChanged: (Set<DiaryCardMetaPosition> v) => controller
                    .commitMode((s) => s.copyWith(metaPosition: v.single)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
