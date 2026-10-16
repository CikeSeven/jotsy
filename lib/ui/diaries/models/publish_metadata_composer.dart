import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/json_object_map.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/utils/optional_text.dart';

/// 日记 metadata 的组装与解析。
///
/// 约束：
/// - 最终输出必须是 JSON 对象字符串；
/// - 交互输入为空时不写入对应字段，减少噪音数据；
/// - [composeDraft] 与 [parse] 互为逆运算（面板管的字段写进去、原样读回来）。
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
    final normalizedLocation = normalizeOptionalText(location);
    final normalizedWeather = normalizeOptionalText(weather);
    final normalizedWeatherIconCode = normalizeOptionalText(weatherIconCode);
    final normalizedMoodEmoji = normalizeOptionalText(moodEmoji);

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
        'precision': normalizeOptionalText(capsulePrecision) ?? 'date',
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

  /// 由面板草稿组装 metadata。
  ///
  /// [capsuleLockedAt] 非空且草稿带胶囊时写入 capsule 块（发布时 = 封存时刻）；
  /// [preserve] 见 [compose]。
  static String composeDraft({
    required DiaryMetaDraft draft,
    required String contentText,
    required DateTime generatedAt,
    Map<String, Object?>? deviceInfo,
    DateTime? capsuleLockedAt,
    Map<String, Object?>? preserve,
  }) {
    final schedule = draft.capsule;
    return compose(
      contentText: contentText,
      selectedTagIds: draft.tagIds,
      hasCover: normalizeOptionalText(draft.cover) != null,
      deviceInfo: deviceInfo ?? currentDeviceInfo(),
      generatedAt: generatedAt,
      location: draft.location,
      locationAddressComponent: draft.locationAddressComponent,
      locationLatitude: draft.locationLatitude,
      locationLongitude: draft.locationLongitude,
      locationFromAuto: draft.locationFromAuto,
      locationPrecision: draft.locationPrecision,
      weather: draft.weather,
      weatherIconCode: draft.weatherIconCode,
      moodEmoji: draft.moodEmoji,
      energyLevel: draft.energyLevel,
      capsuleLockedAt: schedule == null ? null : capsuleLockedAt,
      capsuleUnlockAt: schedule?.normalizedUnlockAt,
      capsulePrecision: schedule == null
          ? null
          : TimeCapsuleSchedule.encodePrecision(schedule.precision),
      preserve: preserve,
    );
  }

  /// 从已存 metadata 读回面板管的上下文字段（context 与 geo）。
  ///
  /// 封面、标签是日记表的列，胶囊由数据库列驱动，都不从这里读。结构不合法
  /// 或缺少 context 时返回空草稿，不阻断编辑。旧版本把精力存成字符串，同样
  /// 兼容；越界值限制到 1~5。
  static DiaryMetaDraft parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      final context = decoded is Map ? decoded['context'] : null;
      if (context is! Map) {
        return const DiaryMetaDraft();
      }
      final energy = switch (context['energyLevel']) {
        final num value => value.toDouble(),
        final String value => double.tryParse(value),
        _ => null,
      };
      final geo = context['geo'];
      return DiaryMetaDraft(
        location: normalizeOptionalText(context['location']?.toString()),
        locationPrecision: DiaryLocationPrecision.parse(
          context['locationPrecision'],
        ),
        weather: normalizeOptionalText(context['weather']?.toString()),
        weatherIconCode: normalizeOptionalText(
          context['weatherIconCode']?.toString(),
        ),
        moodEmoji: normalizeOptionalText(context['moodEmoji']?.toString()),
        energyLevel: energy?.clamp(1, 5).toDouble(),
        locationLatitude: geo is Map
            ? (geo['latitude'] as num?)?.toDouble()
            : null,
        locationLongitude: geo is Map
            ? (geo['longitude'] as num?)?.toDouble()
            : null,
        locationFromAuto: geo is Map,
        locationAddressComponent: geo is Map
            ? parseJsonObjectMap(geo['addressComponent'])
            : null,
      );
    } catch (_) {
      return const DiaryMetaDraft();
    }
  }

  /// 写入 metadata.device 的设备上下文。
  static Map<String, Object?> currentDeviceInfo() {
    final dispatcher = PlatformDispatcher.instance;
    return <String, Object?>{
      'platform': defaultTargetPlatform.name,
      'locale': dispatcher.locale.toLanguageTag(),
      'brightness': dispatcher.platformBrightness.name,
    };
  }

  /// 基于空白分词估算词数，作为发布统计字段。
  static int _wordCount(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return 0;
    }
    return normalized.split(RegExp(r'\s+')).length;
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
