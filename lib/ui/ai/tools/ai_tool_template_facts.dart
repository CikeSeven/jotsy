// 日记模板工具在卡片详情里的参数名与读法：参数名复用模板编辑页的文案，
// 正文显示成纯文字（不给用户看标记），枚举写成界面名称，推荐时间与时间
// 段规则写成一句话。

import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diary_templates/models/diary_template.dart';
import '../../diary_templates/viewmodels/diary_template_auto_labels.dart';
import '../../diary_templates/viewmodels/diary_template_labels.dart';
import 'ai_template_markdown_parse.dart';

/// 模板字段在详情里的名称：复用模板编辑页的文案。
String? aiTemplateArgLabel(AppLocalizations l10n, String key) => switch (key) {
  'description' => l10n.diaryTemplateEditorDescription,
  'category' => l10n.diaryTemplateEditorCategory,
  'icon' => l10n.diaryTemplateEditorIcon,
  'energy' => l10n.diaryTemplateEditorEnergy,
  'capsule' => l10n.diaryTemplateEditorCapsule,
  'recommend' => l10n.diaryTemplateEditorRecommend,
  _ => null,
};

/// 模板字段在详情里的读法：正文显示为纯文字（不给用户看标记），枚举写成
/// 界面名称，推荐时间与规则写成一句话。
String? aiTemplateDescribeArg(
  AppLocalizations l10n,
  String key,
  Object? value,
) {
  switch (key) {
    case 'body' when value is String:
      return diaryBlocksPlainText(aiTemplateBodyFromMarkdown(value)).trim();
    case 'category' when value is String:
      final category = DiaryTemplateCategory.values.asNameMap()[value];
      return category == null
          ? value
          : diaryTemplateCategoryLabel(l10n, category);
    case 'icon':
      return '';
    case 'color' when value is String && value.toLowerCase() == 'theme':
      return l10n.diaryTemplateEditorAccentTheme;
    case 'capsule' when value is String:
      final preset = TimeCapsulePreset.values.asNameMap()[value];
      return preset == null
          ? l10n.diaryTemplateEditorNone
          : diaryTemplateCapsuleLabel(l10n, preset);
    case 'energy' when value == 0:
      return l10n.diaryTemplateEditorNone;
    case 'mood' when value == '':
      return l10n.diaryTemplateEditorNone;
    case 'recommend' when value is Map:
      return _recommendText(l10n, value);
    case 'add_rules' || 'remove_rules' when value is List:
      return [
        for (final rule in value)
          if (rule is Map) _ruleText(l10n, rule),
      ].join(l10n.aiListSeparator);
  }
  return null;
}

String _recommendText(AppLocalizations l10n, Map<Object?, Object?> raw) {
  final times = raw['times'];
  final weekdays = raw['weekdays'];
  final month = raw['month'];
  final parts = <String>[
    if (times is List)
      for (final slot in times)
        switch (slot) {
          'morning' => l10n.diaryTemplateSlotMorning,
          'afternoon' => l10n.diaryTemplateSlotAfternoon,
          'evening' => l10n.diaryTemplateSlotEvening,
          'night' => l10n.diaryTemplateSlotNight,
          _ => '$slot',
        },
    if (weekdays is List && weekdays.isNotEmpty)
      diaryTemplateAutoDaysLabel(l10n, {
        for (final day in weekdays)
          if (day is int) day,
      }),
    if (month is List)
      for (final phase in month)
        phase == 'end'
            ? l10n.diaryTemplateMonthEnd
            : l10n.diaryTemplateMonthStart,
  ];
  return parts.isEmpty ? l10n.diaryTemplateEditorNone : parts.join(' · ');
}

String _ruleText(AppLocalizations l10n, Map<Object?, Object?> rule) {
  final weekdays = rule['weekdays'];
  return [
    l10n.diaryTemplatesAutoApplyRange(
      '${rule['from'] ?? ''}',
      '${rule['to'] ?? ''}',
    ),
    diaryTemplateAutoDaysLabel(l10n, {
      if (weekdays is List)
        for (final day in weekdays)
          if (day is int) day,
    }),
  ].join(' · ');
}
