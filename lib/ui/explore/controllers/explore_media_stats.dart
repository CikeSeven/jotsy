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

  /// 媒体画廊一批候选日记里的图片（带所在日记与发表时间），批内按来源
  /// 去重、保持日记与正文顺序；批与批之间的去重由画廊控制器负责。正文
  /// 合计较大时在 worker 里解码，画廊建索引期间滚动与捏合不被挤占。
  static Future<List<ExploreMediaItem>> galleryItems(
    List<DiaryMediaContent> rows,
  ) {
    var units = 0;
    for (final row in rows) {
      units += row.content.length;
      if (units >= 64 * 1024) {
        return compute(_galleryItems, rows, debugLabel: 'explore.gallery');
      }
    }
    return SynchronousFuture(_galleryItems(rows));
  }

  static Future<Map<String, int>> photoCounts(List<DiaryMediaContent> rows) =>
      rows.isEmpty
      ? SynchronousFuture(const <String, int>{})
      : compute(_countPhotos, rows, debugLabel: 'explore.photos');
}

List<ExploreMediaItem> _recentMedia((List<DiaryMediaContent>, int) input) =>
    ExploreMediaStats.recent(input.$1, limit: input.$2);

List<ExploreMediaItem> _galleryItems(List<DiaryMediaContent> rows) {
  const extractor = ExploreContentExtractor();
  final seen = <String>{};
  return List<ExploreMediaItem>.unmodifiable(<ExploreMediaItem>[
    for (final row in rows)
      for (final source in extractor.resolveMediaSourcesFrom(
        cover: row.cover,
        content: row.content,
      ))
        if (seen.add(source))
          ExploreMediaItem(
            source: source,
            diaryId: row.diaryId,
            date: row.createdAt,
          ),
  ]);
}

Map<String, int> _countPhotos(List<DiaryMediaContent> rows) {
  const extractor = ExploreContentExtractor();
  return Map<String, int>.unmodifiable(<String, int>{
    for (final row in rows)
      row.diaryId: extractor
          .resolveMediaSourcesFrom(cover: row.cover, content: row.content)
          .length,
  });
}
