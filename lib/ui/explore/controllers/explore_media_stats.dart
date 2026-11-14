import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../models/explore_view_data.dart';
import 'explore_content_extractor.dart';

/// 探索媒体派生数据：输入已按可见范围过滤的正文，输出图片来源/数量。
/// 不读文件、不持有数据库。全库照片统计在 worker 里兼容解码旧正文，避免
/// 把包含大量图片块的 JSON 解析挤进切页与滚动帧；空库不启动 isolate。
abstract final class ExploreMediaStats {
  static Future<List<ExploreMediaItem>> loadRecent(
    List<DiaryMediaContent> rows, {
    required int limit,
  }) {
    var units = 0;
    for (final row in rows) {
      units += row.content.length;
      if (units >= 64 * 1024) {
        return compute(_recentMedia, (
          rows,
          limit,
        ), debugLabel: 'explore.recentMedia');
      }
    }
    return SynchronousFuture(recent(rows, limit: limit));
  }

  static List<ExploreMediaItem> recent(
    List<DiaryMediaContent> rows, {
    required int limit,
  }) {
    const extractor = ExploreContentExtractor();
    final seen = <String>{};
    final items = <ExploreMediaItem>[];
    for (final row in rows) {
      // 达到显示数量后连下一篇的正文都不解码，尤其避免浪费在长篇日记上。
      if (items.length >= limit) break;
      for (final source in extractor.resolveMediaSourcesFrom(
        cover: row.cover,
        content: row.content,
      )) {
        if (!seen.add(source)) continue;
        items.add(ExploreMediaItem(source: source, diaryId: row.diaryId));
        if (items.length >= limit) break;
      }
    }
    return List<ExploreMediaItem>.unmodifiable(items);
  }

  static Future<Map<String, int>> photoCounts(List<DiaryMediaContent> rows) =>
      rows.isEmpty
      ? SynchronousFuture(const <String, int>{})
      : compute(_countPhotos, rows, debugLabel: 'explore.photos');
}

List<ExploreMediaItem> _recentMedia((List<DiaryMediaContent>, int) input) =>
    ExploreMediaStats.recent(input.$1, limit: input.$2);

Map<String, int> _countPhotos(List<DiaryMediaContent> rows) {
  const extractor = ExploreContentExtractor();
  return Map<String, int>.unmodifiable(<String, int>{
    for (final row in rows)
      row.diaryId: extractor
          .resolveMediaSourcesFrom(cover: row.cover, content: row.content)
          .length,
  });
}
