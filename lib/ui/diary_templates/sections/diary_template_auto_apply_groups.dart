import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../settings/widgets/settings_card_group.dart';
import '../models/diary_template_auto_rule.dart';
import '../models/diary_template_prefs.dart';
import '../viewmodels/diary_template_auto_labels.dart';
import '../viewmodels/diary_template_library.dart';

/// 自动套用页的“按时间段”分组：每条规则一行（时间段 + 星期 · 模板），
/// 最后一行“添加时间段”，满 [DiaryTemplatePrefs.maxAutoRules] 条后不可点。
class DiaryTemplateAutoRulesGroup extends StatelessWidget {
  const DiaryTemplateAutoRulesGroup({
    super.key,
    required this.library,
    required this.onEdit,
    required this.onAdd,
  });

  final DiaryTemplateLibrary library;
  final ValueChanged<DiaryTemplateAutoRule> onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final rules = library.prefs.autoRules;
    final full = rules.length >= DiaryTemplatePrefs.maxAutoRules;
    // 一个可选模板都没有时新规则无处可指，同样不能添加。
    final canAdd = !full && library.visible.isNotEmpty;
    final addColor = canAdd
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.38);
    return SettingsCardGroup(
      title: l10n.diaryTemplatesAutoApplyRulesGroup,
      children: <Widget>[
        for (final rule in rules)
          _RuleTile(library: library, rule: rule, onTap: () => onEdit(rule)),
        ListTile(
          key: const ValueKey<String>('auto_rule_add'),
          enabled: canAdd,
          leading: FaIcon(FontAwesomeIcons.plus, size: 16, color: addColor),
          title: Text(
            l10n.diaryTemplatesAutoApplyAddRule,
            style: TextStyle(color: addColor),
          ),
          subtitle: full
              ? Text(
                  l10n.diaryTemplatesAutoApplyRuleLimit(
                    DiaryTemplatePrefs.maxAutoRules,
                  ),
                )
              : null,
          onTap: onAdd,
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.library,
    required this.rule,
    required this.onTap,
  });

  final DiaryTemplateLibrary library;
  final DiaryTemplateAutoRule rule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final template = library.byId(rule.templateId);
    return ListTile(
      title: Text(
        diaryTemplateAutoRangeLabel(context, rule),
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Text(
        l10n.diaryTemplatesAutoApplyRuleSubtitle(
          diaryTemplateAutoDaysLabel(l10n, rule.weekdays),
          template == null
              ? l10n.diaryTemplatesAutoApplyMissing
              : diaryTemplateDisplayName(l10n, template),
        ),
        // 规则指向的模板已被删除（控制器删除模板时会一并删掉规则，这里只防
        // 备份恢复等少见情况）：整行提示用错误色，提醒用户换一个。
        style: template == null
            ? TextStyle(color: theme.colorScheme.error)
            : null,
      ),
      trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
      onTap: onTap,
    );
  }
}

/// 自动套用页的“其他时间”分组：不在任何时间段内时套用的默认模板。
class DiaryTemplateAutoDefaultGroup extends StatelessWidget {
  const DiaryTemplateAutoDefaultGroup({
    super.key,
    required this.library,
    required this.onTap,
  });

  final DiaryTemplateLibrary library;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auto = library.autoTemplate;
    return SettingsCardGroup(
      title: l10n.diaryTemplatesAutoApplyOtherGroup,
      children: <Widget>[
        ListTile(
          title: Text(l10n.diaryTemplatesAutoApplyDefault),
          subtitle: Text(
            auto == null
                ? l10n.diaryTemplatesAutoApplyNone
                : diaryTemplateDisplayName(l10n, auto),
          ),
          trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
          onTap: onTap,
        ),
      ],
    );
  }
}
