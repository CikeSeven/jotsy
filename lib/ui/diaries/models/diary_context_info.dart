import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 日记 metadata.context 中的心情、天气、地点与精力（分享与导出共用）。
///
/// metadata 损坏或字段类型不符时按“没有该信息”处理，不影响标题与正文。
@immutable
class DiaryContextInfo {
  const DiaryContextInfo({
    this.moodEmoji,
    this.weather,
    this.location,
    this.energyLevel,
  });

  factory DiaryContextInfo.parse(String metadata) {
    Map<String, Object?> context = const <String, Object?>{};
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is Map && decoded['context'] is Map) {
        context = (decoded['context'] as Map).cast<String, Object?>();
      }
    } catch (_) {
      // 见类注释：按“无上下文”处理。
    }
    final energy = switch (context['energyLevel']) {
      num value => value.toDouble(),
      String value => double.tryParse(value),
      _ => null,
    };
    return DiaryContextInfo(
      moodEmoji: _nonEmpty(context['moodEmoji']),
      weather: _nonEmpty(context['weather']),
      location: _nonEmpty(context['location']),
      // 精力为 1~5 档，四舍五入后越界的值视为无效。
      energyLevel: energy == null || !energy.isFinite
          ? null
          : switch (energy.round()) {
              final int level when level >= 1 && level <= 5 => level,
              _ => null,
            },
    );
  }

  final String? moodEmoji;
  final String? weather;
  final String? location;

  /// 精力档位 1~5。
  final int? energyLevel;

  static String? _nonEmpty(Object? raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}
