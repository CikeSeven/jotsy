import 'dart:convert';

import 'package:meta/meta.dart';

/// 从模型输出里取出第一个 JSON 对象：允许包在代码围栏里、前后带说明文字；
/// 取不出来时返回 null（调用方按“没有建议”处理，不报错）。
Map<String, Object?>? aiExtractJsonObject(String raw) {
  final text = raw.trim();
  final candidates = <String>[text];
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fence != null) candidates.add(fence.group(1)!.trim());
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) candidates.add(text.substring(start, end + 1));
  for (final candidate in candidates) {
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map) return decoded.cast<String, Object?>();
    } on FormatException {
      continue;
    }
  }
  return null;
}

List<String> _strings(Object? raw, {int max = 8, int maxLength = 40}) => [
  if (raw is List)
    for (final item in raw)
      if (item is String && item.trim().isNotEmpty)
        item.trim().length > maxLength
            ? item.trim().substring(0, maxLength)
            : item.trim(),
].take(max).toList();

/// 智能填写的建议。只认用户已有的标签与心情选项；新标签单独列出，由用户
/// 点了才新建。
@immutable
class AiSuggestion {
  const AiSuggestion({
    this.title,
    this.tags = const <String>[],
    this.newTags = const <String>[],
    this.mood,
  });

  final String? title;

  /// 用户已有的标签名（按已有标签过滤后）。
  final List<String> tags;

  /// 建议新建的标签名（已有的不在其中）。
  final List<String> newTags;

  /// 用户心情选项里的一项。
  final String? mood;

  bool get isEmpty =>
      (title?.isEmpty ?? true) &&
      tags.isEmpty &&
      newTags.isEmpty &&
      mood == null;

  /// 解析模型输出：[existingTags] 与 [moods] 用于过滤；名称比较忽略首尾
  /// 空白与 `#` 前缀。
  static AiSuggestion parse(
    String raw, {
    required List<String> existingTags,
    required List<String> moods,
  }) {
    final json = aiExtractJsonObject(raw);
    if (json == null) return const AiSuggestion();
    String clean(String value) =>
        value.trim().replaceFirst(RegExp(r'^#+'), '').trim();
    final byName = {for (final tag in existingTags) clean(tag): tag};
    final tags = <String>[];
    final created = <String>[];
    for (final name in [
      ..._strings(json['tags']),
      ..._strings(json['newTags']),
    ]) {
      final key = clean(name);
      if (key.isEmpty) continue;
      final existing = byName[key];
      if (existing != null) {
        if (!tags.contains(existing) && tags.length < 3) tags.add(existing);
      } else if (!created.contains(key) &&
          created.length < 2 &&
          key.length <= 12) {
        created.add(key);
      }
    }
    final rawTitle = json['title'];
    var title = rawTitle is String ? rawTitle.trim() : null;
    if (title != null) {
      title = title.replaceAll(RegExp(r'^[《「"“]+|[》」"”]+$'), '').trim();
      if (title.length > 60) title = title.substring(0, 60);
      if (title.isEmpty) title = null;
    }
    final rawMood = json['mood'];
    final mood = rawMood is String && moods.contains(rawMood.trim())
        ? rawMood.trim()
        : null;
    return AiSuggestion(title: title, tags: tags, newTags: created, mood: mood);
  }
}
