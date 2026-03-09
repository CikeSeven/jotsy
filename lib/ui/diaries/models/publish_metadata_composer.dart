import 'dart:convert';

/// 发布页 metadata 组装器。
///
/// 约束：
/// - 最终输出必须是 JSON 对象字符串；
/// - 交互输入为空时不写入对应字段，减少噪音数据。
class PublishMetadataComposer {
  const PublishMetadataComposer._();

  static String compose({
    required String contentText,
    required Set<int> selectedTagIds,
    required bool hasCover,
    required Map<String, Object?> deviceInfo,
    required DateTime generatedAt,
    String? location,
    double? locationLatitude,
    double? locationLongitude,
    bool locationFromAuto = false,
    String? weather,
    String? moodEmoji,
    int? energyLevel,
  }) {
    final normalizedLocation = _normalizeOptionalText(location);
    final normalizedWeather = _normalizeOptionalText(weather);
    final normalizedMoodEmoji = _normalizeOptionalText(moodEmoji);

    final metadata = <String, Object?>{
      'schemaVersion': 1,
      'generatedAt': generatedAt.toIso8601String(),
      'stats': <String, Object?>{
        'wordCount': _wordCount(contentText),
        'charCount': contentText.trim().length,
      },
      'tagIds': selectedTagIds.toList()..sort(),
      'hasCover': hasCover,
      if (deviceInfo.isNotEmpty) 'device': _filterEmptyMap(deviceInfo),
    };

    final context = <String, Object?>{
      if (normalizedLocation != null) 'location': normalizedLocation,
      if (locationFromAuto &&
          locationLatitude != null &&
          locationLongitude != null)
        'geo': <String, Object?>{
          'source': 'amap_auto',
          'latitude': locationLatitude,
          'longitude': locationLongitude,
        },
      if (normalizedWeather != null) 'weather': normalizedWeather,
      if (normalizedMoodEmoji != null) 'moodEmoji': normalizedMoodEmoji,
      if (energyLevel != null) 'energyLevel': energyLevel.clamp(1, 5),
    };
    if (context.isNotEmpty) {
      metadata['context'] = context;
    }

    return jsonEncode(metadata);
  }

  static String pretty(String jsonRaw) {
    final decoded = jsonDecode(jsonRaw);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  static int _wordCount(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return 0;
    }
    return normalized.split(RegExp(r'\s+')).length;
  }

  static String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static Map<String, Object?> _filterEmptyMap(Map<String, Object?> raw) {
    return <String, Object?>{
      for (final entry in raw.entries)
        if (entry.value != null &&
            (!(entry.value is String) || (entry.value as String).trim().isNotEmpty))
          entry.key: entry.value,
    };
  }
}
