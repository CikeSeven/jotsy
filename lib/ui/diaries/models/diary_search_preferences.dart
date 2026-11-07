import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 搜索结果的排序：最近更新（默认）、最新发表、最早发表。
enum DiarySearchSort {
  updatedDesc(DiarySortMode.updatedDesc),
  createdDesc(DiarySortMode.createdDesc),
  createdAsc(DiarySortMode.createdAsc);

  const DiarySearchSort(this.mode);

  final DiarySortMode mode;

  static DiarySearchSort fromName(Object? name) =>
      values.asNameMap()[name] ?? updatedDesc;
}

/// 搜索页的本机偏好：最近搜索与结果排序，存在设置键
/// `app.search.preferences`（单个 JSON 对象，不随备份、不参与同步）。
///
/// 格式：`{"recent":["樱花","京都 雨"],"sort":"createdDesc"}`。逐字段容错：
/// 坏 JSON 或不是对象时为默认值；`recent` 只取非空字符串、去重并截到
/// [maxRecent] 条；认不出的 `sort` 按默认排序。
@immutable
class DiarySearchPreferences {
  DiarySearchPreferences({
    List<String> recent = const <String>[],
    this.sort = DiarySearchSort.updatedDesc,
  }) : recent = List<String>.unmodifiable(_normalizeRecent(recent));

  /// 最多记住的最近搜索条数。
  static const int maxRecent = 10;

  /// 单条最近搜索的最大长度（按码点，超出部分不记）：记的是搜索词，不是正文。
  static const int maxEntryLength = 100;

  static final DiarySearchPreferences defaults = DiarySearchPreferences();

  /// 新的在前。
  final List<String> recent;
  final DiarySearchSort sort;

  /// 记下一次搜索：已有的（不分大小写）移到最前，超出 [maxRecent] 的丢掉。
  /// 空白串原样返回。
  DiarySearchPreferences remember(String keyword) {
    final normalized = keyword.trim();
    if (normalized.isEmpty) return this;
    final lower = normalized.toLowerCase();
    return DiarySearchPreferences(
      recent: <String>[
        normalized,
        for (final entry in recent)
          if (entry.toLowerCase() != lower) entry,
      ],
      sort: sort,
    );
  }

  DiarySearchPreferences forget(String keyword) => DiarySearchPreferences(
    recent: <String>[
      for (final entry in recent)
        if (entry != keyword) entry,
    ],
    sort: sort,
  );

  DiarySearchPreferences clearRecent() =>
      DiarySearchPreferences(recent: const <String>[], sort: sort);

  DiarySearchPreferences withSort(DiarySearchSort value) =>
      DiarySearchPreferences(recent: recent, sort: value);

  static DiarySearchPreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    final Object? node;
    try {
      node = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (node is! Map) return defaults;
    final rawRecent = node['recent'];
    return DiarySearchPreferences(
      recent: <String>[
        if (rawRecent is List)
          for (final entry in rawRecent)
            if (entry is String) entry,
      ],
      sort: DiarySearchSort.fromName(node['sort']),
    );
  }

  String encode() =>
      jsonEncode(<String, Object?>{'recent': recent, 'sort': sort.name});

  static List<String> _normalizeRecent(List<String> source) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in source) {
      var entry = raw.trim();
      if (entry.isEmpty) continue;
      if (entry.runes.length > maxEntryLength) {
        entry = String.fromCharCodes(entry.runes.take(maxEntryLength)).trim();
      }
      if (!seen.add(entry.toLowerCase())) continue;
      result.add(entry);
      if (result.length == maxRecent) break;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiarySearchPreferences &&
          other.sort == sort &&
          listEquals(other.recent, recent);

  @override
  int get hashCode => Object.hash(sort, Object.hashAll(recent));
}
