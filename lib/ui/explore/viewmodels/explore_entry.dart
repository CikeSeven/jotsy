import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../utils/text_stats.dart';

/// 探索页聚合用的一篇日记：概览里的字段先解析好，各卡片的聚合器只读这些
/// 标量，不再各自解析 metadata JSON。
///
/// 时间一律是本地时间；[day] 为当天本地零点（日期构造，不加 24 小时）。
@immutable
class ExploreEntry {
  const ExploreEntry({
    required this.source,
    required this.created,
    required this.day,
    required this.words,
    this.mood,
    this.energy,
    this.weather,
    this.weatherIconCode,
    this.location,
    this.capsuleLockedAt,
  });

  /// 解析概览：metadata 损坏时这些字段为空，不影响篇数与字数。
  factory ExploreEntry.parse(ExploreDiaryOverview overview) {
    final created = overview.createdAt.toLocal();
    Map<Object?, Object?>? root;
    try {
      final decoded = jsonDecode(overview.metadata);
      if (decoded is Map) root = decoded;
    } catch (_) {
      // 损坏的 metadata：只少了心情、天气等附加信息。
    }
    final context = root?['context'];
    final contextMap = context is Map ? context : null;
    final capsule = root?['capsule'];
    final lockedAt = capsule is Map
        ? DateTime.tryParse('${capsule['lockedAt']}')?.toLocal()
        : null;
    return ExploreEntry(
      source: overview,
      created: created,
      day: DateTime(created.year, created.month, created.day),
      words: DiaryWordCounts.of(
        diaryId: overview.diaryId,
        updatedAt: overview.updatedAt,
        text: overview.contentText,
      ),
      mood: _text(contextMap?['moodEmoji']),
      energy: switch (contextMap?['energyLevel']) {
        final num value when value.isFinite => value.toDouble(),
        final String value => double.tryParse(value),
        _ => null,
      },
      weather: _text(contextMap?['weather']),
      weatherIconCode: _text(contextMap?['weatherIconCode']),
      location: _text(contextMap?['location']),
      capsuleLockedAt: lockedAt,
    );
  }

  final ExploreDiaryOverview source;
  final DateTime created;
  final DateTime day;
  final int words;
  final String? mood;
  final double? energy;
  final String? weather;
  final String? weatherIconCode;
  final String? location;

  /// 时间胶囊的封存时间；不是胶囊时为 null。胶囊的发表时间（[created]）就是
  /// 解封时间（概览只含已解封的胶囊）。
  final DateTime? capsuleLockedAt;

  String get diaryId => source.diaryId;
  String get title => source.title;
  DateTime get updatedAt => source.updatedAt;
  List<Tag> get tags => source.tags;

  /// 显式封面（概览不带正文，正文图片不在这里）。
  String? get cover => _text(source.cover);

  /// 本地日期的整数键（yyyymmdd），按天分桶时比 DateTime 便宜。
  int get dayKey => exploreDayKey(day);

  /// 换成同一篇的新概览（标签改名等不改 updatedAt 的变化），解析结果沿用。
  ExploreEntry withSource(ExploreDiaryOverview overview) => ExploreEntry(
    source: overview,
    created: created,
    day: day,
    words: words,
    mood: mood,
    energy: energy,
    weather: weather,
    weatherIconCode: weatherIconCode,
    location: location,
    capsuleLockedAt: capsuleLockedAt,
  );

  static String? _text(Object? raw) {
    if (raw == null) return null;
    final text = '$raw'.trim();
    return text.isEmpty ? null : text;
  }
}

/// 本地日期 → yyyymmdd。
int exploreDayKey(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

/// 一次概览流推送对应的全部条目（顺序同概览：更新时间新 → 旧）。
@immutable
class ExploreEntryIndex {
  ExploreEntryIndex(List<ExploreEntry> entries)
    : entries = List<ExploreEntry>.unmodifiable(entries);

  final List<ExploreEntry> entries;

  bool get isEmpty => entries.isEmpty;
}

/// 条目缓存：同一篇日记（id、更新时间、发表时间与 metadata 都没变）只解析
/// 一次。
///
/// 由探索页（与编辑页预览）各自持有，不做全局缓存；每次建索引后只保留本次
/// 仍在的日记，删除的日记随之释放。
class ExploreEntryCache {
  Map<String, ExploreEntry> _entries = <String, ExploreEntry>{};

  ExploreEntryIndex index(List<ExploreDiaryOverview> overviews) {
    final next = <String, ExploreEntry>{};
    final list = <ExploreEntry>[];
    for (final overview in overviews) {
      final cached = _entries[overview.diaryId];
      final ExploreEntry entry;
      if (cached != null &&
          cached.source.updatedAt == overview.updatedAt &&
          cached.source.createdAt == overview.createdAt &&
          cached.source.metadata == overview.metadata &&
          cached.source.contentText == overview.contentText) {
        entry = identical(cached.source, overview)
            ? cached
            : cached.withSource(overview);
      } else {
        entry = ExploreEntry.parse(overview);
      }
      next[overview.diaryId] = entry;
      list.add(entry);
    }
    _entries = next;
    return ExploreEntryIndex(list);
  }
}
