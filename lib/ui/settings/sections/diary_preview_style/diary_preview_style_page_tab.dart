import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/diary_preview_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import '../diary_card_style/diary_card_style_labels.dart';
import 'diary_preview_style_color_group.dart';

/// “页面”标签页：配色基调、纸张与正文颜色，边距与正文宽度，顶栏，阅读
/// 辅助（进度线、回到顶部）。
class DiaryPreviewStylePageTab extends StatelessWidget {
  const DiaryPreviewStylePageTab({super.key, required this.controller});

  final DiaryPreviewStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = controller.style.page;

    void commit(DiaryPreviewPageStyle next) =>
        controller.commitWith((style) => style.copyWith(page: next));
    void preview(DiaryPreviewPageStyle next) =>
        controller.previewWith((style) => style.copyWith(page: next));

    return StyleEditorTabList(
      children: <Widget>[
        DiaryPreviewStyleColorGroup(controller: controller),
        SettingsCardGroup(
          title: l10n.diaryPreviewStyleLayoutGroup,
          children: <Widget>[
            SettingsSliderTile(
              title: l10n.diaryPreviewStylePadding,
              value: page.horizontalPadding,
              min: DiaryPreviewStyleLimits.horizontalPadding.min,
              max: DiaryPreviewStyleLimits.horizontalPadding.max,
              divisions: DiaryPreviewStyleLimits.horizontalPadding.divisions,
              valueLabel: (double v) => diaryCardDpLabel(l10n, v),
              onChanged: (double v) =>
                  preview(page.copyWith(horizontalPadding: v)),
              onChangeEnd: (double v) =>
                  commit(page.copyWith(horizontalPadding: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleLimitWidth,
              subtitle: l10n.diaryPreviewStyleLimitWidthSubtitle,
              value: page.limitWidth,
              onChanged: (bool v) => commit(page.copyWith(limitWidth: v)),
            ),
            if (page.limitWidth)
              SettingsSliderTile(
                title: l10n.diaryPreviewStyleContentWidth,
                value: page.contentWidth,
                min: DiaryPreviewStyleLimits.contentWidth.min,
                max: DiaryPreviewStyleLimits.contentWidth.max,
                divisions: DiaryPreviewStyleLimits.contentWidth.divisions,
                valueLabel: (double v) => diaryCardDpLabel(l10n, v),
                onChanged: (double v) =>
                    preview(page.copyWith(contentWidth: v)),
                onChangeEnd: (double v) =>
                    commit(page.copyWith(contentWidth: v)),
              ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryPreviewStyleTopBarGroup,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleTopBarGroup,
              child: ExpressiveButtonGroup<DiaryPreviewTopBarMode>(
                segments: <ButtonSegment<DiaryPreviewTopBarMode>>[
                  ButtonSegment<DiaryPreviewTopBarMode>(
                    value: DiaryPreviewTopBarMode.floating,
                    label: Text(l10n.diaryPreviewStyleTopBarFloating),
                  ),
                  ButtonSegment<DiaryPreviewTopBarMode>(
                    value: DiaryPreviewTopBarMode.pinned,
                    label: Text(l10n.diaryPreviewStyleTopBarPinned),
                  ),
                ],
                selected: <DiaryPreviewTopBarMode>{page.topBar},
                onSelectionChanged: (Set<DiaryPreviewTopBarMode> v) =>
                    commit(page.copyWith(topBar: v.single)),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleTopBarTitle,
              child: ExpressiveButtonGroup<DiaryPreviewTopBarTitle>(
                minSegmentWidth: 64,
                segments: <ButtonSegment<DiaryPreviewTopBarTitle>>[
                  ButtonSegment<DiaryPreviewTopBarTitle>(
                    value: DiaryPreviewTopBarTitle.label,
                    label: Text(l10n.autoT0120),
                  ),
                  ButtonSegment<DiaryPreviewTopBarTitle>(
                    value: DiaryPreviewTopBarTitle.date,
                    label: Text(l10n.diaryPreviewStyleTopBarTitleDate),
                  ),
                  ButtonSegment<DiaryPreviewTopBarTitle>(
                    value: DiaryPreviewTopBarTitle.position,
                    label: Text(l10n.diaryPreviewStyleTopBarTitlePosition),
                  ),
                  ButtonSegment<DiaryPreviewTopBarTitle>(
                    value: DiaryPreviewTopBarTitle.none,
                    label: Text(l10n.diaryPreviewStyleTopBarTitleNone),
                  ),
                ],
                selected: <DiaryPreviewTopBarTitle>{page.topBarTitle},
                onSelectionChanged: (Set<DiaryPreviewTopBarTitle> v) =>
                    commit(page.copyWith(topBarTitle: v.single)),
              ),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleShowTypographyButton,
              value: page.showTypographyButton,
              onChanged: (bool v) =>
                  commit(page.copyWith(showTypographyButton: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleShowShareButton,
              value: page.showShareButton,
              onChanged: (bool v) => commit(page.copyWith(showShareButton: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleShowEditButton,
              value: page.showEditButton,
              onChanged: (bool v) => commit(page.copyWith(showEditButton: v)),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryPreviewStyleReadingGroup,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleProgress,
              subtitle: l10n.diaryPreviewStyleProgressSubtitle,
              value: page.progress == DiaryPreviewProgress.line,
              onChanged: (bool v) => commit(
                page.copyWith(
                  progress: v
                      ? DiaryPreviewProgress.line
                      : DiaryPreviewProgress.none,
                ),
              ),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleBackToTop,
              subtitle: l10n.diaryPreviewStyleBackToTopSubtitle,
              value: page.backToTop,
              onChanged: (bool v) => commit(page.copyWith(backToTop: v)),
            ),
          ],
        ),
      ],
    );
  }
}
