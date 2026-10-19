import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../diary_templates/providers/diary_template_providers.dart';
import '../../diary_templates/sections/diary_template_choice_sheet.dart';
import '../../diary_templates/viewmodels/diary_template_auto_labels.dart';
import '../../diary_templates/viewmodels/diary_template_library.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../controllers/notebook_editor_controller.dart';
import '../viewmodels/notebook_labels.dart';

/// 类型（只在新建时出现）：普通 | 智能，下方一行说明。选了智能时，编辑页在
/// 这一节下方显示规则编辑区（`NotebookEditorRulesSection`）。
class NotebookEditorTypeSection extends StatelessWidget {
  const NotebookEditorTypeSection({super.key, required this.controller});

  final NotebookEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SettingsCardGroup(
      title: l10n.notebookTypeLabel,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ExpressiveButtonGroup<NotebookKind>(
                minSegmentWidth: 88,
                segments: <ButtonSegment<NotebookKind>>[
                  ButtonSegment<NotebookKind>(
                    value: NotebookKind.manual,
                    label: Text(l10n.notebookTypeManual),
                  ),
                  ButtonSegment<NotebookKind>(
                    value: NotebookKind.smart,
                    label: Text(l10n.notebookTypeSmart),
                  ),
                ],
                selected: <NotebookKind>{controller.kind},
                onSelectionChanged: (value) => controller.kind = value.single,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                controller.isSmart
                    ? l10n.notebookTypeSmartHint
                    : l10n.notebookTypeManualHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 隐私（只对普通日记本）：正常 / 不在全部日记中显示 / 上锁。
class NotebookEditorPrivacySection extends StatelessWidget {
  const NotebookEditorPrivacySection({super.key, required this.controller});

  final NotebookEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsCardGroup(
      title: l10n.notebookPrivacyLabel,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s),
          child: Column(
            children: <Widget>[
              for (final visibility in NotebookVisibility.values)
                ExpressiveChoiceTile(
                  label: notebookVisibilityLabel(l10n, visibility),
                  description: notebookVisibilityDescription(l10n, visibility),
                  selected: controller.visibility == visibility,
                  onTap: () => controller.visibility = visibility,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 本子里日记的默认排序。
class NotebookEditorSortSection extends StatelessWidget {
  const NotebookEditorSortSection({super.key, required this.controller});

  final NotebookEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsCardGroup(
      title: l10n.notebookSortLabel,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s),
          child: Column(
            children: <Widget>[
              // 书序靠目录页手动排列，智能日记本没有目录，不提供（已存的书序
              // 由 effectiveNotebookSort 在显示时回退）。
              for (final sort in NotebookSort.values)
                if (sort != NotebookSort.book ||
                    controller.kind == NotebookKind.manual)
                  ExpressiveChoiceTile(
                    label: notebookSortLabel(l10n, sort),
                    description: notebookSortDescription(l10n, sort),
                    selected: controller.sort == sort,
                    onTap: () => controller.sort = sort,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 在这本里新建日记时默认套用的模板：显示模板名或“不套用”，点按打开模板
/// 单选面板（含“不套用”）。读模板库的一次性快照，不挂实时查询。
class NotebookEditorTemplateSection extends ConsumerWidget {
  const NotebookEditorTemplateSection({super.key, required this.controller});

  final NotebookEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (:library, :loaded) = watchDiaryTemplateLibrary(ref, l10n);
    final template = library.byId(controller.templateId);
    final summary = template != null
        ? diaryTemplateDisplayName(l10n, template)
        : (controller.templateId == null || loaded)
        ? l10n.notebookTemplateNone
        : '';
    return SettingsCardGroup(
      children: <Widget>[
        ListTile(
          titleAlignment: ListTileTitleAlignment.center,
          leading: FaIcon(
            FontAwesomeIcons.layerGroup,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(l10n.notebookTemplateLabel),
          subtitle: Text(summary),
          trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
          onTap: () => unawaited(_choose(context, library)),
        ),
      ],
    );
  }

  Future<void> _choose(
    BuildContext context,
    DiaryTemplateLibrary library,
  ) async {
    final l10n = context.l10n;
    final picked = await showDiaryTemplateChoiceSheet(
      context,
      library: library,
      selectedId: controller.templateId,
      title: l10n.notebookTemplateLabel,
      noneLabel: l10n.notebookTemplateNone,
    );
    if (picked != null) controller.templateId = picked.id;
  }
}
