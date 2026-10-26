import 'dart:convert';

import 'package:flutter/widgets.dart' show StringCharacters;

import '../../diaries/models/style_library/style_json.dart';
import '../../diaries/models/time_capsule.dart';
import 'diary_template.dart';
import 'diary_template_blocks.dart';
import 'diary_template_recommend.dart';

/// 模板与 JSON 的互转：数据库 `payload` 列与模板码共用同一种 JSON。
///
/// 格式（稀疏，默认值不写）：
/// `{"v":2,"name":…,"description":…,"icon":"sun","accent":"#FB8C00",
///   "category":"daily","title":…,"body":{"document":…},"tags":[{"name","color"}],
///   "mood":"🙂","energy":4,"capsule":"year","recommend":{…}}`
///
/// 解码逐字段容错：一个字段坏了只回退该字段的默认值；正文一律经
/// [sanitizeDiaryTemplateBlocks] 白名单清洗——数据库行、备份、模板码都可能被
/// 手工改过，不能信任其中的嵌入。id 不在 JSON 里，由调用方给出（数据库行的
/// `templateId`；导入模板码时新生成）。
abstract final class DiaryTemplateJson {
  static const int version = 2;

  /// 预设标签缺颜色时用的颜色（色板里的蓝）。
  static const int fallbackTagColor = 0xFF1E88E5;

  static Map<String, Object> toJson(DiaryTemplate template) {
    final json = <String, Object>{'v': version, 'name': template.name};
    if (template.description.isNotEmpty) {
      json['description'] = template.description;
    }
    StyleJson.putEnum(json, 'icon', template.icon, DiaryTemplateIcon.penNib);
    StyleJson.putColor(json, 'accent', template.accent, null);
    StyleJson.putEnum(
      json,
      'category',
      template.category,
      DiaryTemplateCategory.other,
    );
    if (template.titlePattern.isNotEmpty) json['title'] = template.titlePattern;
    json['body'] = sanitizeDiaryTemplateBlocks(template.bodyJson);
    if (template.tags.isNotEmpty) {
      json['tags'] = <Object>[
        for (final tag in template.tags)
          <String, Object>{'name': tag.name, 'color': StyleJson.hex(tag.color)},
      ];
    }
    if (template.mood case final mood?) json['mood'] = mood;
    if (template.energy case final energy?) json['energy'] = energy;
    if (template.capsule case final capsule?) json['capsule'] = capsule.name;
    StyleJson.putObject(json, 'recommend', template.recommend.toJson());
    return json;
  }

  static DiaryTemplate fromJson(Object? raw, {required String id}) {
    final json = StyleJson.map(raw) ?? const <String, dynamic>{};
    String text(String key, int max) {
      final value = json[key];
      return value is String ? normalizeDiaryTemplateLine(value, max) : '';
    }

    final energy = json['energy'];
    final mood = json['mood'];
    return DiaryTemplate(
      id: id,
      name: text('name', DiaryTemplate.maxNameLength),
      description: text('description', DiaryTemplate.maxDescriptionLength),
      icon: StyleJson.enumByName(
        DiaryTemplateIcon.values,
        json['icon'],
        DiaryTemplateIcon.penNib,
      ),
      accent: StyleJson.argb(json['accent']),
      category: StyleJson.enumByName(
        DiaryTemplateCategory.values,
        json['category'],
        DiaryTemplateCategory.other,
      ),
      titlePattern: text('title', DiaryTemplate.maxTitleLength),
      bodyJson: encodeDiaryTemplateBody(json['body']),
      tags: List<DiaryTemplateTagRef>.unmodifiable(_tags(json['tags'])),
      mood: mood is String && mood.trim().isNotEmpty
          ? mood.trim().characters.take(4).toString()
          : null,
      energy: energy is num && energy.isFinite
          ? energy.round().clamp(1, 5).toInt()
          : null,
      capsule: TimeCapsulePreset.values
          .where((preset) => preset.name == json['capsule'])
          .firstOrNull,
      recommend: DiaryTemplateRecommendRules.fromJson(json['recommend']),
    );
  }

  static String toPayload(DiaryTemplate template) =>
      jsonEncode(toJson(template));

  /// 数据库行的 payload；JSON 坏掉时返回 null，调用方跳过这一行。
  static DiaryTemplate? fromPayload(String payload, {required String id}) {
    final Object? json;
    try {
      json = jsonDecode(payload);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    return fromJson(json, id: id);
  }

  /// 按名称去重、跳过空名与超过标签名上限的项，最多 [DiaryTemplate.maxTags] 个。
  static List<DiaryTemplateTagRef> _tags(Object? raw) {
    if (raw is! List) return const <DiaryTemplateTagRef>[];
    final seen = <String>{};
    final tags = <DiaryTemplateTagRef>[];
    for (final item in raw) {
      if (tags.length >= DiaryTemplate.maxTags) break;
      if (item is! Map) continue;
      final name = item['name'];
      if (name is! String) continue;
      final trimmed = name.trim();
      if (trimmed.isEmpty || trimmed.length > 40 || !seen.add(trimmed)) {
        continue;
      }
      tags.add(
        DiaryTemplateTagRef(
          name: trimmed,
          color: StyleJson.argb(item['color']) ?? fallbackTagColor,
        ),
      );
    }
    return tags;
  }
}

/// 正文统一写块文档；v1 的 Delta 仅在读取时兼容转换。
String encodeDiaryTemplateBody(Object? body) =>
    jsonEncode(sanitizeDiaryTemplateBlocks(body));

Map<String, Object?> decodeDiaryTemplateBody(String bodyJson) =>
    sanitizeDiaryTemplateBlocks(bodyJson);
