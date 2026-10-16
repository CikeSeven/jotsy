import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../utils/text_stats.dart';
import 'diary_card_media_summary.dart';

/// 预览页的派生展示数据：metadata.context 里的心情、精力、地点与天气，看图页
/// 的图片来源，以及字数统计与媒体数量（惰性计算）。
///
/// 图片来源的顺序：显式封面在前，其后是正文中的全部图片（不去重，看图页
/// 打开时再去重）。预览页封面与正文图片共用这一组来源，点按任一张都能进入
/// 看图页左右切换；头图取第一张（显式封面，否则正文第一张图）。
///
/// 为什么记忆化：正文可能很长，整段 jsonDecode 只在封面、正文或 metadata
/// 变化时重做（见 [resolve]）。入口数据渲染首帧后，详情查询往往在路由滑入
/// 途中返回同一份正文，此时直接复用上一次的结果，避免转场半途多出一次长
/// 任务；加载遮罩等局部重建也不再重新解析。无副作用。
@immutable
class DiaryPreviewViewData {
  DiaryPreviewViewData._(
    this._content,
    this._contentText,
    this._cover,
    this._metadata, {
    required this.images,
    this.moodEmoji,
    this.energyLevel,
    this.location,
    this.weather,
    this.weatherIconCode,
  });

  /// 解析 [diary]；与 [previous] 的来源相同时直接返回 [previous]。
  static DiaryPreviewViewData resolve(
    Diary diary, {
    DiaryPreviewViewData? previous,
  }) {
    if (previous != null &&
        previous._content == diary.content &&
        previous._contentText == diary.contentText &&
        previous._cover == diary.cover &&
        previous._metadata == diary.metadata) {
      return previous;
    }
    final context = _decodeContext(diary.metadata);
    final energyRaw = context?['energyLevel'];
    return DiaryPreviewViewData._(
      diary.content,
      diary.contentText,
      diary.cover,
      diary.metadata,
      images: List<String>.unmodifiable(<String>[
        if (diary.cover?.trim() case final cover? when cover.isNotEmpty) cover,
        ..._extractImageSources(diary.content),
      ]),
      moodEmoji: _nonEmpty(context?['moodEmoji']),
      energyLevel: switch (energyRaw) {
        num value => value.toDouble(),
        String value => double.tryParse(value),
        _ => null,
      },
      location: _nonEmpty(context?['location']),
      weather: _nonEmpty(context?['weather']),
      weatherIconCode: _nonEmpty(context?['weatherIconCode']),
    );
  }

  final String _content;
  final String _contentText;
  final String? _cover;
  final String _metadata;

  /// 正文字数统计（口径见 [TextStats]）；只在显示字数或打开明细时计算。
  late final TextStats textStats = TextStats.of(_contentText);

  /// 正文媒体数量（字数明细面板用）。
  late final DiaryCardMediaSummary media = DiaryCardMediaSummary.scan(_content);

  /// 看图页的图片来源（显式封面在前，其后是正文图片）。
  final List<String> images;

  final String? moodEmoji;

  /// 原始精力值（未归一化，由展示组件按需处理）。
  final double? energyLevel;
  final String? location;
  final String? weather;
  final String? weatherIconCode;

  /// 头图来源：显式封面，否则正文第一张图；都没有时为 null。
  String? get coverSource => images.firstOrNull;

  static Map<String, dynamic>? _decodeContext(String metadata) {
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final context = decoded['context'];
      return context is Map<String, dynamic> ? context : null;
    } catch (_) {
      return null;
    }
  }

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// 正文（Quill Delta，或旧版 AppFlowy 文档）中的全部图片来源；正文损坏时
  /// 按“没有图片”处理。
  static List<String> _extractImageSources(String contentJson) {
    final normalized = contentJson.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    try {
      final sources = <String>[];
      _collectImages(jsonDecode(normalized), sources);
      return sources;
    } catch (_) {
      return const <String>[];
    }
  }

  static void _collectImages(Object? node, List<String> sources) {
    if (node is List) {
      for (final item in node) {
        _collectImages(item, sources);
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
    final root = node['root'];
    if (root != null) {
      _collectImages(root, sources);
    }
    final children = node['children'];
    if (children != null) {
      _collectImages(children, sources);
    }
  }
}
