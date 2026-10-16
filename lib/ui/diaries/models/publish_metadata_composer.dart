import 'dart:convert';

import 'package:node_diary/ui/diaries/models/diary_location.dart';

/// 发布页 metadata 组装器。
///
/// 约束：
/// - 最终输出必须是 JSON 对象字符串；
/// - 交互输入为空时不写入对应字段，减少噪音数据。
class PublishMetadataComposer {
  const PublishMetadataComposer._();

  /// 本组装器每次都会重写的顶层键；`capsule` 只在本次写了胶囊时重写。
  static const Set<String> _ownedKeys = <String>{
    'schemaVersion',
    'generatedAt',
    'stats',
    'tagIds',
    'hasCover',
    'device',
    'context',
  };

  /// 组装发布时的 metadata。
  ///
  /// 约定输出结构：
  /// - 顶层基础信息：schemaVersion/generatedAt/stats/tagIds/hasCover/device；
  /// - context：位置、天气、情绪、精力等可选上下文；
  /// - geo：仅在自动定位成功且有经纬度时写入。
  ///
  /// [preserve] 是日记原有的 metadata：编辑已发布日记时，面板改动只重写
  /// 本组装器负责的字段，原有的胶囊（`capsule`）、导入来源（`import`）等
  /// 别处写入的顶层块原样保留，不随一次改心情被丢掉。
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
    DiaryLocationPrecision locationPrecision = DiaryLocationPrecision.township,
    String? weather,
    String? weatherIconCode,
    String? moodEmoji,
    double? energyLevel,
    DateTime? capsuleLockedAt,
    DateTime? capsuleUnlockAt,
    String? capsulePrecision,
    Map<String, Object?>? preserve,
  }) {
    final normalizedLocation = _normalizeOptionalText(location);
    final normalizedWeather = _normalizeOptionalText(weather);
    final normalizedWeatherIconCode = _normalizeOptionalText(weatherIconCode);
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

    if (capsuleLockedAt != null && capsuleUnlockAt != null) {
      metadata['capsule'] = <String, Object?>{
        'lockedAt': capsuleLockedAt.toIso8601String(),
        'unlockAt': capsuleUnlockAt.toIso8601String(),
        'precision': _normalizeOptionalText(capsulePrecision) ?? 'date',
      };
    }

    final context = <String, Object?>{
      if (normalizedLocation != null) 'location': normalizedLocation,
      if (normalizedLocation != null ||
          locationFromAuto ||
          locationPrecision != DiaryLocationPrecision.township)
        'locationPrecision': locationPrecision.name,
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
      if (normalizedWeatherIconCode != null)
        'weatherIconCode': normalizedWeatherIconCode,
      if (normalizedMoodEmoji != null) 'moodEmoji': normalizedMoodEmoji,
      if (energyLevel != null)
        'energyLevel': _normalizeEnergyLevel(energyLevel),
    };
    if (context.isNotEmpty) {
      metadata['context'] = context;
    }

    if (preserve != null) {
      for (final entry in preserve.entries) {
        if (!_ownedKeys.contains(entry.key)) {
          metadata.putIfAbsent(entry.key, () => entry.value);
        }
      }
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
            (entry.value is! String ||
                (entry.value as String).trim().isNotEmpty))
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
