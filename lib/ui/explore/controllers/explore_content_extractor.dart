import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_media.dart';

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
  List<String> resolveMediaSources(Diary diary) =>
      resolveMediaSourcesFrom(cover: diary.cover, content: diary.content);

  /// 同 [resolveMediaSources]，输入为封面与正文原文（不必持有整篇日记，
  /// 如日记本统计页只查这两列）。
  List<String> resolveMediaSourcesFrom({
    required String? cover,
    required String content,
  }) {
    final sources = <String>{};
    final trimmedCover = cover?.trim();
    if (trimmedCover != null && trimmedCover.isNotEmpty) {
      sources.add(trimmedCover);
    }
    sources.addAll(extractDiaryImageSources(content));
    return sources.toList(growable: false);
  }
}
