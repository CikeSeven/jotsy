import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/diary_preview_style_editor_controller.dart';
import '../../pages/diary_typography_page.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// “正文”标签页：正文字体与排版（入口，设置与编辑页共用、只存一处）、空正文
/// 提示、“最后编辑于”、时间胶囊解封提示，以及不受预设影响的阅读行为（勾选
/// 待办、长按选择文字、长图折叠或完整显示）。
class DiaryPreviewStyleBodyTab extends StatelessWidget {
  const DiaryPreviewStyleBodyTab({super.key, required this.controller});

  final DiaryPreviewStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = controller.style.body;
    final behavior = controller.behavior;
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

    void commit(DiaryPreviewBodyStyle next) =>
        controller.commitWith((style) => style.copyWith(body: next));

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            ListTile(
              contentPadding: padding,
              leading: const FaIcon(FontAwesomeIcons.font, size: 16),
              title: Text(l10n.diaryPreviewStyleTypographyEntry),
              subtitle: Text(l10n.diaryPreviewStyleTypographyEntrySubtitle),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      const DiaryTypographyPage(),
                ),
              ),
            ),
          ],
        ),
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleEmptyHint,
              value: body.showEmptyHint,
              onChanged: (bool v) => commit(body.copyWith(showEmptyHint: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleLastEdited,
              value: body.showLastEdited,
              onChanged: (bool v) => commit(body.copyWith(showLastEdited: v)),
            ),
            if (body.showLastEdited)
              SettingsChoiceTile(
                title: l10n.diaryPreviewStyleEditedFormat,
                child: ExpressiveButtonGroup<DiaryPreviewEditedFormat>(
                  minSegmentWidth: 72,
                  segments: <ButtonSegment<DiaryPreviewEditedFormat>>[
                    ButtonSegment<DiaryPreviewEditedFormat>(
                      value: DiaryPreviewEditedFormat.precise,
                      label: Text(l10n.diaryPreviewStyleEditedPrecise),
                    ),
                    ButtonSegment<DiaryPreviewEditedFormat>(
                      value: DiaryPreviewEditedFormat.relative,
                      label: Text(l10n.diaryPreviewStyleEditedRelative),
                    ),
                    ButtonSegment<DiaryPreviewEditedFormat>(
                      value: DiaryPreviewEditedFormat.full,
                      label: Text(l10n.diaryPreviewStyleEditedFull),
                    ),
                  ],
                  selected: <DiaryPreviewEditedFormat>{body.editedFormat},
                  onSelectionChanged: (Set<DiaryPreviewEditedFormat> v) =>
                      commit(body.copyWith(editedFormat: v.single)),
                ),
              ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleCapsuleInsight,
              value: body.showCapsuleInsight,
              onChanged: (bool v) =>
                  commit(body.copyWith(showCapsuleInsight: v)),
            ),
          ],
        ),
        SettingsCardGroup(
          title: l10n.diaryPreviewStyleBehaviorGroup,
          footer: l10n.diaryPreviewStyleBehaviorFootnote,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleTodoToggle,
              subtitle: l10n.diaryPreviewStyleTodoToggleSubtitle,
              value: behavior.todoToggle,
              onChanged: (bool v) =>
                  controller.setBehavior(behavior.copyWith(todoToggle: v)),
            ),
            SettingsSwitchTile(
              title: l10n.diaryPreviewStyleTextSelection,
              subtitle: l10n.diaryPreviewStyleTextSelectionSubtitle,
              value: behavior.textSelection,
              onChanged: (bool v) =>
                  controller.setBehavior(behavior.copyWith(textSelection: v)),
            ),
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleLongImage,
              subtitle: l10n.diaryPreviewStyleLongImageSubtitle,
              child: ExpressiveButtonGroup<DiaryPreviewLongImageMode>(
                minSegmentWidth: 96,
                segments: <ButtonSegment<DiaryPreviewLongImageMode>>[
                  ButtonSegment<DiaryPreviewLongImageMode>(
                    value: DiaryPreviewLongImageMode.fold,
                    label: Text(l10n.diaryPreviewStyleLongImageFold),
                  ),
                  ButtonSegment<DiaryPreviewLongImageMode>(
                    value: DiaryPreviewLongImageMode.full,
                    label: Text(l10n.diaryPreviewStyleLongImageFull),
                  ),
                ],
                selected: <DiaryPreviewLongImageMode>{behavior.longImageMode},
                onSelectionChanged: (Set<DiaryPreviewLongImageMode> v) =>
                    controller.setBehavior(
                      behavior.copyWith(longImageMode: v.single),
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
