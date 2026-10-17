import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/diary_preview_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// “翻页”标签页：左右滑动的开关、灵敏度与轻震（阅读行为，不受预设影响），
/// 以及翻页效果、正文末尾的上一篇 / 下一篇与到头提示（外观）。上方的预览
/// 可以直接左右滑动，试手感与效果。
class DiaryPreviewStylePagingTab extends StatelessWidget {
  const DiaryPreviewStylePagingTab({super.key, required this.controller});

  final DiaryPreviewStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final navigation = controller.style.navigation;
    final behavior = controller.behavior;

    void commit(DiaryPreviewNavigationStyle next) =>
        controller.commitWith((style) => style.copyWith(navigation: next));

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.diaryPreviewStyleBehaviorGroup,
          footer: l10n.diaryPreviewStyleBehaviorFootnote,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleSwipe,
              subtitle: l10n.diaryPreviewStyleSwipeSubtitle,
              value: behavior.swipeBetweenDiaries,
              onChanged: (bool v) => controller.setBehavior(
                behavior.copyWith(swipeBetweenDiaries: v),
              ),
            ),
            if (behavior.swipeBetweenDiaries) ...<Widget>[
              SettingsChoiceTile(
                title: l10n.diaryPreviewStyleSwipeSensitivity,
                subtitle: l10n.diaryPreviewStyleSensitivityHint,
                child: ExpressiveButtonGroup<DiaryPreviewSwipeSensitivity>(
                  minSegmentWidth: 72,
                  segments: <ButtonSegment<DiaryPreviewSwipeSensitivity>>[
                    ButtonSegment<DiaryPreviewSwipeSensitivity>(
                      value: DiaryPreviewSwipeSensitivity.sensitive,
                      label: Text(l10n.diaryPreviewStyleSensitivitySensitive),
                    ),
                    ButtonSegment<DiaryPreviewSwipeSensitivity>(
                      value: DiaryPreviewSwipeSensitivity.standard,
                      label: Text(l10n.diaryPreviewStyleSensitivityStandard),
                    ),
                    ButtonSegment<DiaryPreviewSwipeSensitivity>(
                      value: DiaryPreviewSwipeSensitivity.strict,
                      label: Text(l10n.diaryPreviewStyleSensitivityStrict),
                    ),
                  ],
                  selected: <DiaryPreviewSwipeSensitivity>{
                    behavior.swipeSensitivity,
                  },
                  onSelectionChanged: (Set<DiaryPreviewSwipeSensitivity> v) =>
                      controller.setBehavior(
                        behavior.copyWith(swipeSensitivity: v.single),
                      ),
                ),
              ),
              SettingsSwitchTile(
                title: l10n.diaryPreviewStyleHapticOnPage,
                value: behavior.hapticOnPage,
                onChanged: (bool v) =>
                    controller.setBehavior(behavior.copyWith(hapticOnPage: v)),
              ),
            ],
          ],
        ),
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleTransition,
              child: ExpressiveButtonGroup<DiaryPreviewPageTransition>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<DiaryPreviewPageTransition>>[
                  ButtonSegment<DiaryPreviewPageTransition>(
                    value: DiaryPreviewPageTransition.slide,
                    label: Text(l10n.diaryPreviewStyleTransitionSlide),
                  ),
                  ButtonSegment<DiaryPreviewPageTransition>(
                    value: DiaryPreviewPageTransition.stack,
                    label: Text(l10n.diaryPreviewStyleTransitionStack),
                  ),
                  ButtonSegment<DiaryPreviewPageTransition>(
                    value: DiaryPreviewPageTransition.fade,
                    label: Text(l10n.diaryPreviewStyleTransitionFade),
                  ),
                ],
                selected: <DiaryPreviewPageTransition>{navigation.transition},
                onSelectionChanged: (Set<DiaryPreviewPageTransition> v) =>
                    commit(navigation.copyWith(transition: v.single)),
              ),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleNeighborCards,
              value: navigation.neighborCards,
              onChanged: (bool v) =>
                  commit(navigation.copyWith(neighborCards: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleEdgeHint,
              subtitle: l10n.diaryPreviewStyleEdgeHintSubtitle,
              value: navigation.edgeHint,
              onChanged: (bool v) => commit(navigation.copyWith(edgeHint: v)),
            ),
          ],
        ),
      ],
    );
  }
}
