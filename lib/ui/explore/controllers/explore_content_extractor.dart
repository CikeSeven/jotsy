import 'dart:convert';

import '../../../core/database/app_database.dart';

/// 探索页内容提取器。
///
/// 职责边界：
/// - 解析 metadata.context；
/// - 提供摘要文案与媒体资源提取；
/// - 不参与任何统计聚合逻辑。
class ExploreContentExtractor {
  const ExploreContentExtractor();

  Map<String, dynamic>? parseContext(String metadata) {
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final context = decoded['context'];
      if (context is! Map<String, dynamic>) {
        return null;
      }
      return context;
    } catch (_) {
      return null;
    }
  }

  String summaryFromText(
    String contentText, {
    String emptyFallback = 'Recorded an entry',
  }) {
    final text = contentText.replaceAll('\n', ' ').trim();
    if (text.isNotEmpty) {
      return text;
    }
    return emptyFallback;
  }

  String summaryText(
    Diary diary, {
    String emptyFallback = 'Recorded an entry',
  }) {
    return summaryFromText(diary.contentText, emptyFallback: emptyFallback);
  }

  String? resolveOverviewMediaSource(ExploreDiaryOverview overview) {
    final cover = overview.cover?.trim();
    if (cover != null && cover.isNotEmpty) {
      return cover;
    }
    return null;
  }

  /// 封面优先，随后按正文顺序收集全部图片；同一来源只保留一次。
  List<String> resolveMediaSources(Diary diary) {
    final sources = <String>{};
    final cover = diary.cover?.trim();
    if (cover != null && cover.isNotEmpty) {
      sources.add(cover);
    }
    final raw = diary.content.trim();
    if (raw.isNotEmpty) {
      try {
        _collectImagesFromNode(jsonDecode(raw), sources);
      } on FormatException {
        // 旧记录可能保存纯文本或损坏的 JSON，正文解析失败仍保留独立封面。
      }
    }
    return sources.toList(growable: false);
  }

  void _collectImagesFromNode(Object? node, Set<String> sources) {
    if (node is List) {
      for (final item in node) {
        _collectImagesFromNode(item, sources);
      }
      return;
    }
    if (node is! Map) {
      return;
    }

    final insert = node['insert'];
    if (insert is Map) {
      final image = insert['image'];
      if (image is String && image.trim().isNotEmpty) {
        sources.add(image.trim());
      }
    }

    if (node['type'] == 'image') {
      final attributes = node['attributes'];
      if (attributes is Map) {
        final url = attributes['url'];
        if (url is String && url.trim().isNotEmpty) {
          sources.add(url.trim());
        }
      }
    }

    // 同时兼容 Quill Delta 和旧版 AppFlowy 的嵌套图片节点。
    _collectImagesFromNode(node['children'], sources);
    _collectImagesFromNode(node['root'], sources);
  }
}
