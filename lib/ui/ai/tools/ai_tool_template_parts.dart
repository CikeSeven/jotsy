// 日记模板工具共用的部分：模板库、按 id 找模板、模板字段的参数与校验、
// 发给模型的模板 JSON 与撤销数据（卡片详情里参数的读法见
// `ai_tool_template_facts.dart`）。
//
// 口径与模板管理页一致：内置模板按界面语言编译、库里改过的替换默认内容、
// 被删除的内置模板不可用（只能先恢复）；读写只经 `DiaryTemplatesController`
// 与模板模型（`DiaryTemplateJson` 清洗、`sanitizeDiaryTemplateBlocks` 白名单），
// 正文只经模板 Markdown（`ai_template_markdown*.dart`）进出。

import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diary_templates/controllers/diary_templates_controller.dart';
import '../../diary_templates/models/built_in/diary_template_built_ins.dart';
import '../../diary_templates/models/diary_template.dart';
import '../../diary_templates/models/diary_template_auto_rule.dart';
import '../../diary_templates/models/diary_template_json.dart';
import '../../diary_templates/models/diary_template_prefs.dart';
import '../../diary_templates/models/diary_template_recommend.dart';
import '../../diary_templates/models/diary_template_variables.dart';
import '../../diary_templates/providers/diary_template_providers.dart';
import '../../diary_templates/viewmodels/diary_template_auto_labels.dart';
import '../../diary_templates/viewmodels/diary_template_labels.dart';
import '../../diary_templates/viewmodels/diary_template_library.dart';
import '../models/ai_tool_subject.dart';
import 'ai_template_markdown.dart';
import 'ai_template_markdown_parse.dart';
import 'ai_tool.dart';
import 'ai_tool_writes.dart';

/// 模板库（与管理页同一口径），直接读库与设置原文，不等 provider。
Future<DiaryTemplateLibrary> aiTemplateLibrary(AiToolContext context) async {
  final settings = await context.container.read(settingsServiceProvider.future);
  return DiaryTemplateLibrary(
    builtIns: buildBuiltInDiaryTemplates(context.l10n),
    userTemplates: parseDiaryTemplateRows(
      await context.database.getDiaryTemplates(),
    ),
    prefs: DiaryTemplatePrefs.decode(settings.diaryTemplatePrefsRaw),
  );
}

/// 模板的读写控制器：写入后让新建编辑页读的模板快照失效（与管理页同一个
/// 控制器、同一种刷新）。
DiaryTemplatesController aiTemplatesController(
  ProviderContainer container,
  SettingsService settings,
) => DiaryTemplatesController(
  database: container.read(appDatabaseProvider),
  settings: settings,
  onTemplatesChanged: () =>
      container.invalidate(userDiaryTemplatesSnapshotProvider),
);

/// 按 id 找可用的模板；也认名称（不分大小写、只有一个同名时）。找不到时
/// 抛 [AiToolFailure]：被删除的内置模板单独说明要先恢复。
DiaryTemplate aiFindTemplate(DiaryTemplateLibrary library, String idOrName) {
  final key = idOrName.trim();
  final byId = library.byId(key);
  if (byId != null) return byId;
  final named = [
    for (final template in library.visible)
      if (template.name.toLowerCase() == key.toLowerCase()) template,
  ];
  if (named.length == 1) return named.single;
  if (library.deletedBuiltIns.any((t) => t.id == key || t.name == key)) {
    throw AiToolFailure(
      'Template "$key" is a deleted built-in template. Restore it with '
      'restore_templates first.',
    );
  }
  throw AiToolFailure('No template "$key". Use an id from list_templates.');
}

/// 模板作为涉及对象。
AiToolSubject aiTemplateSubject(
  AppLocalizations l10n,
  DiaryTemplate template, {
  bool input = false,
}) => AiToolSubject.template(
  template.id,
  diaryTemplateDisplayName(l10n, template),
  input: input,
);

// ---------------------------------------------------------------------------
// 发给模型的 JSON

String _hhmm(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// 一个模板的设置（[body] 为 true 时连同模板 Markdown 正文）。
Map<String, Object?> aiTemplateJson(
  DiaryTemplate template,
  DiaryTemplateLibrary library, {
  bool body = false,
}) {
  final recommend = template.recommend;
  return <String, Object?>{
    'id': template.id,
    'name': template.name,
    'built_in': template.isBuiltIn,
    if (library.editedBuiltIns.contains(template.id)) 'edited': true,
    if (template.description.isNotEmpty) 'description': template.description,
    'category': template.category.name,
    'icon': template.icon.name,
    if (template.accent case final accent?) 'color': _hex(accent),
    if (template.titlePattern.isNotEmpty) 'title': template.titlePattern,
    if (template.tags.isNotEmpty)
      'tags': [for (final tag in template.tags) tag.name],
    'mood': ?template.mood,
    'energy': ?template.energy,
    if (template.capsule case final capsule?) 'capsule': capsule.name,
    if (!recommend.isEmpty) 'recommend': aiTemplateRecommendJson(recommend),
    if (body) 'body': aiTemplateMarkdownOf(template.bodyJson),
  };
}

Map<String, Object?> aiTemplateRecommendJson(
  DiaryTemplateRecommendRules rules,
) => <String, Object?>{
  if (rules.slots.isNotEmpty)
    'times': [
      for (final slot in DiaryTemplateTimeSlot.values)
        if (rules.slots.contains(slot)) slot.name,
    ],
  if (rules.weekdays.isNotEmpty) 'weekdays': rules.weekdays.toList()..sort(),
  if (rules.monthPhases.isNotEmpty)
    'month': [
      for (final phase in DiaryTemplateMonthPhase.values)
        if (rules.monthPhases.contains(phase)) phase.name,
    ],
};

/// 一条按时间段自动套用的规则。
Map<String, Object?> aiTemplateRuleJson(DiaryTemplateAutoRule rule) =>
    <String, Object?>{
      'from': _hhmm(rule.startMinute),
      'to': _hhmm(rule.endMinute),
      if (rule.weekdays.isNotEmpty) 'weekdays': rule.sortedWeekdays,
      'template_id': rule.templateId,
    };

/// 变量在界面语言里的写法（`{"date": "{{日期}}", …}`），模型写模板时照抄。
Map<String, String> aiTemplateVariables(AppLocalizations l10n) =>
    <String, String>{
      for (final variable in DiaryTemplateVariable.values)
        _snake(variable.name): diaryTemplateVariableToken(l10n, variable),
    };

String _snake(String name) => name.replaceAllMapped(
  RegExp('[A-Z]'),
  (match) => '_${match.group(0)!.toLowerCase()}',
);

// ---------------------------------------------------------------------------
// 模板字段：create_template 与 update_template 共用的参数

/// 推荐时间（与模板编辑页“推荐时间”同一组条件）。
const AiObjectSchema aiTemplateRecommendSchema = AiObjectSchema(
  description:
      'When the template is suggested first: every given group must match, '
      'any value within a group. An empty object clears it.',
  properties: <String, AiSchema>{
    'times': AiArraySchema(
      items: AiStringSchema(
        enumValues: ['morning', 'afternoon', 'evening', 'night'],
      ),
      description: 'morning 5-11, afternoon 11-17, evening 17-22, night 22-5.',
    ),
    'weekdays': AiArraySchema(
      items: AiIntegerSchema(minimum: 1, maximum: 7),
      description: '1 = Monday … 7 = Sunday.',
    ),
    'month': AiArraySchema(
      items: AiStringSchema(enumValues: ['start', 'end']),
      description: 'First or last 3 days of the month.',
    ),
  },
);

/// 模板的各个字段（新建与修改共用）。
final Map<String, AiSchema> aiTemplateFieldSchemas = <String, AiSchema>{
  'name': const AiStringSchema(maxLength: DiaryTemplate.maxNameLength),
  'description': const AiStringSchema(
    maxLength: DiaryTemplate.maxDescriptionLength,
    allowEmpty: true,
  ),
  'category': AiStringSchema(
    enumValues: [for (final c in DiaryTemplateCategory.values) c.name],
  ),
  'icon': AiStringSchema(
    enumValues: [for (final i in DiaryTemplateIcon.values) i.name],
  ),
  'color': const AiStringSchema(
    description: 'Accent color #RRGGBB, or "theme" to follow the app theme.',
  ),
  'title': const AiStringSchema(
    maxLength: DiaryTemplate.maxTitleLength,
    allowEmpty: true,
    description: 'Title pattern for new entries; may use {{variables}}.',
  ),
  'body': const AiStringSchema(
    allowEmpty: true,
    description: 'The body in template Markdown (see the tool description).',
  ),
  'tags': const AiArraySchema(
    items: AiStringSchema(maxLength: 40),
    maxItems: DiaryTemplate.maxTags,
    description:
        'Tag names set on new entries (missing tags are created '
        'when the template is used). [] clears.',
  ),
  'mood': const AiStringSchema(
    allowEmpty: true,
    description: 'One of the mood options from get_app_context; "" clears.',
  ),
  'energy': const AiIntegerSchema(
    minimum: 0,
    maximum: 5,
    description: 'Energy 1-5 set on new entries; 0 clears.',
  ),
  'capsule': AiStringSchema(
    enumValues: ['none', for (final p in TimeCapsulePreset.values) p.name],
    description: 'Seal new entries as a time capsule for this long.',
  ),
  'recommend': aiTemplateRecommendSchema,
};

/// 在 [base] 上改 [args] 里给出的字段（没给的不动），全部校验通过才返回。
Future<DiaryTemplate> aiTemplateWithFields(
  AiToolContext context,
  DiaryTemplate base,
  Map<String, Object?> args,
) async {
  var template = base;
  if (args['name'] case final String name) {
    final normalized = normalizeDiaryTemplateLine(
      name,
      DiaryTemplate.maxNameLength,
    );
    if (normalized.isEmpty) throw const AiToolFailure('`name` is empty.');
    template = template.copyWith(name: normalized);
  }
  if (args['description'] case final String description) {
    template = template.copyWith(
      description: normalizeDiaryTemplateLine(
        description,
        DiaryTemplate.maxDescriptionLength,
      ),
    );
  }
  if (args['category'] case final String category) {
    template = template.copyWith(
      category: DiaryTemplateCategory.values.byName(category),
    );
  }
  if (args['icon'] case final String icon) {
    template = template.copyWith(icon: DiaryTemplateIcon.values.byName(icon));
  }
  if (args['color'] case final String color) {
    template = template.copyWith(accent: () => _accent(color));
  }
  if (args['title'] case final String title) {
    template = template.copyWith(
      titlePattern: normalizeDiaryTemplateLine(
        title,
        DiaryTemplate.maxTitleLength,
      ),
    );
  }
  // 正文与现在的写法逐字相同（模型把 get_template 的正文原样交回）时不动：
  // 重新编码虽然显示一样，存下的 JSON 未必逐字节相同，内置模板会因此平白
  // 变成“已修改”。
  if (args['body'] case final String body
      when body != aiTemplateMarkdownOf(base.bodyJson)) {
    template = template.copyWith(
      bodyJson: encodeDiaryBlocks(aiTemplateBodyFromMarkdown(body)),
    );
  }
  if (args['tags'] case final List tags) {
    template = template.copyWith(
      tags: await _tagRefs(context, base, tags.cast<String>()),
    );
  }
  if (args['mood'] case final String mood) {
    final checked = await _mood(context, mood);
    template = template.copyWith(mood: () => checked);
  }
  if (args['energy'] case final int energy) {
    template = template.copyWith(energy: () => energy == 0 ? null : energy);
  }
  if (args['capsule'] case final String capsule) {
    template = template.copyWith(
      capsule: () =>
          capsule == 'none' ? null : TimeCapsulePreset.values.byName(capsule),
    );
  }
  if (args['recommend'] case final Map recommend) {
    template = template.copyWith(
      recommend: _recommend(recommend.cast<String, Object?>()),
    );
  }
  return template;
}

int? _accent(String raw) {
  final value = raw.trim();
  if (value.toLowerCase() == 'theme') return null;
  final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value);
  if (match == null) {
    throw const AiToolFailure('`color` is #RRGGBB or "theme".');
  }
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16)).toARGB32();
}

/// 心情预设：空串清除；否则必须是用户的心情选项（模板管理页同样只能从
/// 选项里挑，套用时也只认选项里的）。
Future<String?> _mood(AiToolContext context, String raw) async {
  final mood = raw.trim();
  if (mood.isEmpty) return null;
  final settings = await context.container.read(settingsServiceProvider.future);
  final options = settings.moodOptions;
  if (!options.contains(mood)) {
    throw AiToolFailure(
      "`mood` must be one of the user's mood options: ${options.join(' ')}",
    );
  }
  return mood;
}

/// 预设标签按名称引用：本机已有同名标签时用它的名称与颜色，模板原来就
/// 有的保留原色，其余用 AI 新建标签的默认色（套用时才真的新建）。
Future<List<DiaryTemplateTagRef>> _tagRefs(
  AiToolContext context,
  DiaryTemplate base,
  List<String> names,
) async {
  final existing = await context.database.watchAllTags().first;
  final refs = <DiaryTemplateTagRef>[];
  final seen = <String>{};
  for (final raw in names) {
    final name = raw.trim();
    if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
    final tag = existing
        .where((tag) => tag.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    final old = base.tags.where((tag) => tag.name == name).firstOrNull;
    refs.add(
      DiaryTemplateTagRef(
        name: tag?.name ?? name,
        color: tag?.color ?? old?.color ?? aiDefaultTagColor,
      ),
    );
  }
  return List<DiaryTemplateTagRef>.unmodifiable(refs);
}

DiaryTemplateRecommendRules _recommend(Map<String, Object?> raw) {
  Set<T> named<T extends Enum>(Object? list, List<T> values) => <T>{
    if (list is List)
      for (final item in list) values.byName('$item'),
  };
  final weekdays = raw['weekdays'];
  return DiaryTemplateRecommendRules(
    slots: Set.unmodifiable(named(raw['times'], DiaryTemplateTimeSlot.values)),
    weekdays: Set.unmodifiable(<int>{
      if (weekdays is List)
        for (final day in weekdays) day as int,
    }),
    monthPhases: Set.unmodifiable(
      named(raw['month'], DiaryTemplateMonthPhase.values),
    ),
  );
}

/// 模板行的指纹：写入后的 payload，撤销前据此判断之后有没有被别处改过。
Future<String?> aiTemplatePayloadOf(AppDatabase database, String id) async =>
    (await database.getDiaryTemplate(id))?.payload;

/// 撤销数据里存的模板行（`DiaryTemplateRow.toJson`）。
DiaryTemplateRow aiTemplateRowFrom(Object? raw) =>
    DiaryTemplateRow.fromJson((raw! as Map).cast<String, dynamic>());

/// 写进撤销数据的“删除时一并撤下的自动套用设置”。
Map<String, Object?> aiTemplateAutoRemovalJson(
  DiaryTemplateAutoRemoval removal,
) => <String, Object?>{
  'wasAuto': removal.wasAuto,
  'rules': [for (final rule in removal.rules) rule.toJson()],
};

DiaryTemplateAutoRemoval aiTemplateAutoRemovalFrom(Object? raw) {
  final map = raw is Map ? raw : const <String, Object?>{};
  final rules = map['rules'];
  return (
    wasAuto: map['wasAuto'] == true,
    rules: <DiaryTemplateAutoRule>[
      if (rules is List)
        for (final rule in rules) ?DiaryTemplateAutoRule.fromJson(rule),
    ],
  );
}

/// 把一份完整模板以 payload 写回（撤销修改用，名称镜像同步写）。
Future<void> aiWriteTemplatePayload(
  AppDatabase database,
  String id,
  String payload,
) async {
  final template = DiaryTemplateJson.fromPayload(payload, id: id);
  await database.saveDiaryTemplate(
    templateId: id,
    name: template?.name ?? '',
    payload: payload,
  );
}
