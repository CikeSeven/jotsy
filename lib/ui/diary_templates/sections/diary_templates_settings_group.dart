import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../models/diary_template.dart';
import '../viewmodels/diary_template_library.dart';

/// 模板管理页顶部的“新建日记时”分组：建议条开关与自动套用的模板。
class DiaryTemplatesSettingsGroup extends StatelessWidget {
  const DiaryTemplatesSettingsGroup({
    super.key,
    required this.library,
    required this.onStripChanged,
    required this.onAutoChanged,
  });

  final DiaryTemplateLibrary library;
  final ValueChanged<bool> onStripChanged;

  /// 选定自动套用的模板（null 为不自动套用）。
  final ValueChanged<String?> onAutoChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auto = library.autoTemplate;
    return SettingsCardGroup(
      title: l10n.diaryTemplatesNewEntryGroup,
      children: <Widget>[
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          value: library.prefs.showStrip,
          title: Text(l10n.diaryTemplatesStripSwitch),
          subtitle: Text(l10n.diaryTemplatesStripSwitchSubtitle),
          onChanged: onStripChanged,
        ),
        ListTile(
          title: Text(l10n.diaryTemplatesAutoApply),
          subtitle: Text(
            auto == null ? l10n.diaryTemplatesAutoApplyNone : _name(l10n, auto),
          ),
          trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
          onTap: () async {
            final picked = await _showAutoApplySheet(context, library);
            if (picked != null) onAutoChanged(picked.id);
          },
        ),
      ],
    );
  }
}

String _name(AppLocalizations l10n, DiaryTemplate template) =>
    template.name.isEmpty ? l10n.diaryTemplateUntitled : template.name;

/// 选择自动套用的模板；关闭面板返回 null，选“不自动套用”返回 `(id: null)`。
Future<({String? id})?> _showAutoApplySheet(
  BuildContext context,
  DiaryTemplateLibrary library,
) {
  return showModalBottomSheet<({String? id})>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      final theme = Theme.of(sheetContext);
      final current = library.autoTemplate?.id;
      void pick(String? id) => Navigator.of(sheetContext).pop((id: id));
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        builder: (BuildContext context, ScrollController controller) {
          return ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.l + MediaQuery.paddingOf(context).bottom,
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  l10n.diaryTemplatesAutoApply,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.m,
                ),
                child: Text(
                  l10n.diaryTemplatesAutoApplyHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ExpressiveChoiceTile(
                label: l10n.diaryTemplatesAutoApplyNone,
                selected: current == null,
                onTap: () => pick(null),
              ),
              for (final template in library.visible) ...<Widget>[
                const SizedBox(height: AppSpacing.s),
                ExpressiveChoiceTile(
                  label: _name(l10n, template),
                  description: template.description.isEmpty
                      ? null
                      : template.description,
                  selected: current == template.id,
                  onTap: () => pick(template.id),
                ),
              ],
            ],
          );
        },
      );
    },
  );
}
