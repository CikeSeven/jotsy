import 'dart:convert';

/// 发布页 metadata 组装器。
///
/// 约束：
/// - 最终输出必须是 JSON 对象字符串；
/// - 交互输入为空时不写入对应字段，减少噪音数据。
class PublishMetadataComposer {
  const PublishMetadataComposer._();

  /// 组装发布时的 metadata。
  ///
  /// 约定输出结构：
  /// - 顶层基础信息：schemaVersion/generatedAt/stats/tagIds/hasCover/device；
  /// - context：位置、天气、情绪、精力等可选上下文；
  /// - geo：仅在自动定位成功且有经纬度时写入。
  static String compose({
    required String contentText,
    required Set<int> selectedTagIds,
    required bool hasCover,
    required Map<String, Object?> deviceInfo,
    required DateTime generatedAt,
    String? location,
    Map<String, Object?>? locationAddressComponent,
    double? locationLatitude,
    double? locationLongitude,
    bool locationFromAuto = false,
    String? weather,
    String? moodEmoji,
    double? energyLevel,
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
          if (locationAddressComponent != null &&
              locationAddressComponent.isNotEmpty)
            'addressComponent': locationAddressComponent,
        },
      if (normalizedWeather != null) 'weather': normalizedWeather,
      if (normalizedMoodEmoji != null) 'moodEmoji': normalizedMoodEmoji,
      if (energyLevel != null) 'energyLevel': _normalizeEnergyLevel(energyLevel),
    };
    if (context.isNotEmpty) {
      metadata['context'] = context;
    }

    return jsonEncode(metadata);
  }

  /// 以缩进格式输出 JSON，便于调试查看。
  static String pretty(String jsonRaw) {
    final decoded = jsonDecode(jsonRaw);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  /// 基于空白分词估算词数，作为发布统计字段。
  static int _wordCount(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return 0;
    }
    return normalized.split(RegExp(r'\s+')).length;
  }

  /// 可选文本字段标准化：空字符串转 null。
  static String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 过滤掉 map 中无意义的空值键，减少 metadata 噪音。
  static Map<String, Object?> _filterEmptyMap(Map<String, Object?> raw) {
    return <String, Object?>{
      for (final entry in raw.entries)
        if (entry.value != null &&
            (!(entry.value is String) || (entry.value as String).trim().isNotEmpty))
          entry.key: entry.value,
    };
  }

  /// 精力值标准化：
  /// - 连续值限制在 1~5；
  /// - 保留两位小数，避免 metadata 出现过长浮点噪音。
  static double _normalizeEnergyLevel(double value) {
    final clamped = value.clamp(1, 5).toDouble();
    return double.parse(clamped.toStringAsFixed(2));
  }
}
