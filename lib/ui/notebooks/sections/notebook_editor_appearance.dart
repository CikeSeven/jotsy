import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../calendar/widgets/calendar_options_controls.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../widgets/color_palette_picker.dart';
import '../controllers/notebook_editor_controller.dart';
import '../widgets/notebook_cover_tile.dart';
import '../widgets/notebook_icon_grid.dart';
import 'notebook_editor_cover_section.dart';

/// 编辑页顶部的实时预览：132dp 宽的封面，随表单即时变化（含封面版式、
/// 纹理与取景）。
class NotebookEditorPreview extends StatelessWidget {
  const NotebookEditorPreview({super.key, required this.controller});

  final NotebookEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = controller.name.text.trim();
    return Center(
      child: SizedBox(
        width: 132,
        child: NotebookCoverTile(
          name: name.isEmpty ? l10n.notebookNameHint : name,
          icon: controller.icon,
          color: controller.color,
          coverPath: controller.coverPath,
          style: controller.coverStyle,
          kind: controller.kind,
          visibility: controller.effectiveVisibility,
        ),
      ),
    );
  }
}

/// 名称（必填）与简介。
class NotebookEditorTextFields extends StatelessWidget {
  const NotebookEditorTextFields({
    super.key,
    required this.controller,
    required this.nameFocus,
  });

  final NotebookEditorController controller;
  final FocusNode nameFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsCardGroup(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CalendarOptionsFieldLabel(text: l10n.notebookNameLabel),
              TextField(
                controller: controller.name,
                focusNode: nameFocus,
                maxLength: NotebookEditorController.maxNameLength,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(hintText: l10n.notebookNameHint),
              ),
              const SizedBox(height: AppSpacing.xs),
              CalendarOptionsFieldLabel(text: l10n.notebookDescriptionLabel),
              TextField(
                controller: controller.description,
                maxLength: 120,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.notebookDescriptionHint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 图标、颜色与封面三组（封面见 [NotebookEditorCoverSection]）。
class NotebookEditorAppearance extends StatelessWidget {
  const NotebookEditorAppearance({
    super.key,
    required this.controller,
    required this.onPickCover,
  });

  final NotebookEditorController controller;
  final Future<void> Function() onPickCover;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const padding = EdgeInsets.all(AppSpacing.l);
    // stretch：否则窄的分组会在页面里居中，标题与上下分组的左缘对不齐。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.notebookIconLabel,
          children: <Widget>[
            Padding(
              padding: padding,
              // 卡片宽度取子项宽度（SettingsCardGroup 内是 start 对齐的 Column），
              // Wrap 只有固有宽度，撑满后才与其他分组同宽。
              child: SizedBox(
                width: double.infinity,
                child: NotebookIconGrid(
                  selected: controller.icon,
                  color: controller.color,
                  onSelected: (icon) => controller.icon = icon,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsCardGroup(
          title: l10n.notebookColorLabel,
          children: <Widget>[
            Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ChoiceChip(
                    label: Text(l10n.notebookColorFollowTheme),
                    selected: controller.color == null,
                    onSelected: (_) => controller.color = null,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  ColorPalettePicker(
                    selectedColor: controller.color,
                    onSelected: (color) => controller.color = color,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        NotebookEditorCoverSection(
          controller: controller,
          onPickCover: onPickCover,
        ),
      ],
    );
  }
}
