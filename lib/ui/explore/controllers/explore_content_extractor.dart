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

  /// 媒体来源优先级：
  /// 1) 封面；
  /// 2) 正文 Delta 第一张图片。
  String? resolveMediaSource(Diary diary) {
    final cover = diary.cover?.trim();
    if (cover != null && cover.isNotEmpty) {
      return cover;
    }
    return _extractFirstImageFromContent(diary.content);
  }

  String? _extractFirstImageFromContent(String contentJson) {
    final raw = contentJson.trim();
    if (raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return _extractImageFromNode(decoded);
    } catch (_) {
      return null;
    }
  }

  String? _extractImageFromNode(Object? node) {
    if (node is List) {
      for (final item in node) {
        final image = _extractImageFromNode(item);
        if (image != null) {
          return image;
        }
      }
      return null;
    }
    if (node is! Map) {
      return null;
    }

    final insert = node['insert'];
    if (insert is Map) {
      final image = insert['image'];
      if (image is String && image.trim().isNotEmpty) {
        return image.trim();
      }
    }

    if (node['type'] == 'image') {
      final attributes = node['attributes'];
      if (attributes is Map) {
        final url = attributes['url'];
        if (url is String && url.trim().isNotEmpty) {
          return url.trim();
        }
      }
    }

    final children = node['children'];
    if (children != null) {
      final image = _extractImageFromNode(children);
      if (image != null) {
        return image;
      }
    }
    final root = node['root'];
    if (root != null) {
      final image = _extractImageFromNode(root);
      if (image != null) {
        return image;
      }
    }
    return null;
  }
}
