import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 分享日记时组装进文字与附件的内容开关。
///
/// 以单个 JSON 设置键保存（`app.settings.diary_share_options`），随备份导出；
/// 解析逐字段容错：缺失或类型不符的字段回落默认值，旧版本或手改过的备份
/// 不会让分享面板打不开。
///
/// 地点默认关闭：分享出去的内容会离开本机，精确到街道的位置不应在用户
/// 没留意时一并发出；其余信息默认带上，与预览页看到的内容一致。
@immutable
class DiaryShareOptions {
  const DiaryShareOptions({
    this.includeTitle = true,
    this.includeBody = true,
    this.includeDate = true,
    this.includeMoodWeather = true,
    this.includeLocation = false,
    this.includeTags = true,
    this.includeImages = true,
  });

  static const DiaryShareOptions defaults = DiaryShareOptions();

  final bool includeTitle;
  final bool includeBody;
  final bool includeDate;

  /// 心情与天气（同属“当时的状态”，一起开关）。
  final bool includeMoodWeather;
  final bool includeLocation;
  final bool includeTags;

  /// 是否附带图片；具体哪几张由分享面板逐张勾选，不持久化。
  final bool includeImages;

  /// 从设置原文解析；null、非 JSON 或非对象时返回默认值。
  factory DiaryShareOptions.fromRaw(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return defaults;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(normalized);
    } on FormatException {
      return defaults;
    }
    if (decoded is! Map) {
      return defaults;
    }
    bool read(String key, bool fallback) {
      final value = decoded is Map ? decoded[key] : null;
      return value is bool ? value : fallback;
    }

    return DiaryShareOptions(
      includeTitle: read('title', defaults.includeTitle),
      includeBody: read('body', defaults.includeBody),
      includeDate: read('date', defaults.includeDate),
      includeMoodWeather: read('moodWeather', defaults.includeMoodWeather),
      includeLocation: read('location', defaults.includeLocation),
      includeTags: read('tags', defaults.includeTags),
      includeImages: read('images', defaults.includeImages),
    );
  }

  String toRaw() => jsonEncode(<String, bool>{
    'title': includeTitle,
    'body': includeBody,
    'date': includeDate,
    'moodWeather': includeMoodWeather,
    'location': includeLocation,
    'tags': includeTags,
    'images': includeImages,
  });

  DiaryShareOptions copyWith({
    bool? includeTitle,
    bool? includeBody,
    bool? includeDate,
    bool? includeMoodWeather,
    bool? includeLocation,
    bool? includeTags,
    bool? includeImages,
  }) {
    return DiaryShareOptions(
      includeTitle: includeTitle ?? this.includeTitle,
      includeBody: includeBody ?? this.includeBody,
      includeDate: includeDate ?? this.includeDate,
      includeMoodWeather: includeMoodWeather ?? this.includeMoodWeather,
      includeLocation: includeLocation ?? this.includeLocation,
      includeTags: includeTags ?? this.includeTags,
      includeImages: includeImages ?? this.includeImages,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryShareOptions &&
        other.includeTitle == includeTitle &&
        other.includeBody == includeBody &&
        other.includeDate == includeDate &&
        other.includeMoodWeather == includeMoodWeather &&
        other.includeLocation == includeLocation &&
        other.includeTags == includeTags &&
        other.includeImages == includeImages;
  }

  @override
  int get hashCode => Object.hash(
    includeTitle,
    includeBody,
    includeDate,
    includeMoodWeather,
    includeLocation,
    includeTags,
    includeImages,
  );
}
