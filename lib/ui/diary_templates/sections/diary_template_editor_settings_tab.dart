import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../calendar/widgets/calendar_options_controls.dart';
import '../../widgets/color_swatch_button.dart';
import '../../widgets/color_palette_families.dart';
import '../controllers/diary_template_editor_controller.dart';
import '../models/diary_template.dart';
import '../viewmodels/diary_template_accent.dart';
import '../viewmodels/diary_template_labels.dart';
import '../widgets/diary_template_icon_badge.dart';
import 'diary_template_editor_presets.dart';
import 'diary_templates_lists.dart';

/// 模板编辑页的“设置”标签：名称与说明、外观（分类、图标、颜色）、套用时
/// 一并设置的预设，以及推荐时间。只读写 [controller]，不涉及数据库。
class DiaryTemplateEditorSettingsTab extends StatelessWidget {
  const DiaryTemplateEditorSettingsTab({super.key, required this.controller});

  final DiaryTemplateEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        return ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            CalendarOptionsFieldLabel(text: l10n.diaryTemplateEditorName),
            TextField(
              controller: controller.name,
              maxLength: DiaryTemplate.maxNameLength,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                errorText: controller.nameMissing
                    ? l10n.diaryTemplateEditorNameRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            CalendarOptionsFieldLabel(
              text: l10n.diaryTemplateEditorDescription,
            ),
            TextField(
              controller: controller.description,
              maxLength: DiaryTemplate.maxDescriptionLength,
              textInputAction: TextInputAction.done,
            ),
            const _GroupHeader.look(),
            CalendarOptionsFieldLabel(text: l10n.diaryTemplateEditorCategory),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: <Widget>[
                for (final category in DiaryTemplateCategory.values)
                  ChoiceChip(
                    label: Text(diaryTemplateCategoryLabel(l10n, category)),
                    selected: controller.category == category,
                    onSelected: (_) => controller.category = category,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            CalendarOptionsFieldLabel(text: l10n.diaryTemplateEditorIcon),
            _IconGrid(controller: controller),
            const SizedBox(height: AppSpacing.l),
            CalendarOptionsFieldLabel(text: l10n.diaryTemplateEditorAccent),
            _AccentPicker(controller: controller),
            DiaryTemplatesSectionHeader(title: l10n.diaryTemplateEditorPresets),
            DiaryTemplateEditorPresets(controller: controller),
            DiaryTemplatesSectionHeader(
              title: l10n.diaryTemplateEditorRecommend,
            ),
            DiaryTemplateEditorRules(controller: controller),
          ],
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader.look();

  @override
  Widget build(BuildContext context) =>
      DiaryTemplatesSectionHeader(title: context.l10n.diaryTemplateEditorLook);
}

/// 图标网格：选中的图标以强调色容器为底，未选中为浅底。
class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.controller});

  final DiaryTemplateEditorController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: <Widget>[
        for (final icon in DiaryTemplateIcon.values)
          Semantics(
            button: true,
            selected: controller.icon == icon,
            label: icon.name,
            child: InkResponse(
              onTap: () => controller.icon = icon,
              radius: 24,
              child: controller.icon == icon
                  ? DiaryTemplateIconBadge(
                      icon: icon,
                      accent: controller.accent,
                      size: 44,
                    )
                  : SizedBox.square(
                      dimension: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: FaIcon(
                            diaryTemplateIconData(icon),
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

/// 颜色：“跟随主题”或色板里十个色系的中间色；预览按当前明暗换算后的
/// 容器色显示，与列表里看到的一致。
class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.controller});

  final DiaryTemplateEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ChoiceChip(
          label: Text(l10n.diaryTemplateEditorAccentTheme),
          selected: controller.accent == null,
          onSelected: (_) => controller.accent = null,
        ),
        for (final family in kColorPaletteFamilies)
          ColorSwatchButton(
            color: diaryTemplateAccentColors(
              family.colors[5].toARGB32(),
              scheme,
            ).container,
            selected: controller.accent == family.colors[5].toARGB32(),
            semanticLabel: family.label,
            onTap: () => controller.accent = family.colors[5].toARGB32(),
          ),
      ],
    );
  }
}
