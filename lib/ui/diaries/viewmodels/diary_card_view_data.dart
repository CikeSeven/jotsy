import 'dart:collection';
import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../utils/text_stats.dart';
import 'diary_card_media_summary.dart';

/// 日记卡片 / 日历时间线条目共用的派生展示数据。
///
/// 输入：[Diary] 实体；输出：metadata.context 中的心情、天气、地点、精力，
/// 单行化并截断的摘要文本、正文字数（惰性计算），预览封面（显式封面优先，否则取正文
/// 第一张图），以及按需惰性扫描的媒体概况（拼贴图片与媒体角标）。
///
/// 为什么缓存：列表滚动、日历选日/翻月、筛选过渡都会高频重建卡片，若每次
/// build 都 `jsonDecode` metadata、并在无封面时解析整段 Quill Delta，开销会
/// 落在滚动与翻页动画的帧里。日记内容只会随 updatedAt 变化，因此以
/// `(diaryId, updatedAt)` 为键做固定容量 LRU 缓存；无副作用。
class DiaryCardViewData {
  DiaryCardViewData._(
    this._explicitCover,
    this._contentJson,
    this._contentText, {
    required this.moodEmoji,
    required this.weather,
    required this.weatherIconCode,
    required this.location,
    required this.energyLevel,
    required this.previewText,
  });

  /// 解析（或从缓存取回）指定日记的展示数据。
  factory DiaryCardViewData.of(Diary diary) {
    final key = '${diary.diaryId}_${diary.updatedAt.microsecondsSinceEpoch}';
    final cached = _cache.remove(key);
    if (cached != null) {
      // 重新插入到末尾，维持“最近使用”顺序。
      _cache[key] = cached;
      return cached;
    }
    final data = DiaryCardViewData._parse(diary);
    _cache[key] = data;
    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return data;
  }

  factory DiaryCardViewData._parse(Diary diary) {
    final context = _decodeContext(diary.metadata);
    return DiaryCardViewData._(
      diary.cover,
      diary.content,
      diary.contentText,
      moodEmoji: _nonEmptyString(context['moodEmoji']),
      weather: _nonEmptyString(context['weather']),
      weatherIconCode: _nonEmptyString(context['weatherIconCode']),
      location: _nonEmptyString(context['location']),
      energyLevel: switch (context['energyLevel']) {
        num value => value.toDouble(),
        String value => double.tryParse(value),
        _ => null,
      },
      previewText: _buildPreviewText(diary.contentText),
    );
  }

  /// 卡片最多展示 2~4 行摘要；超长正文截断后再交给 Text，避免每次排版都
  /// 测量整篇纯文本。
  static const int previewTextMaxLength = 240;
  static const int _maxEntries = 600;
  static final LinkedHashMap<String, DiaryCardViewData> _cache =
      LinkedHashMap<String, DiaryCardViewData>();

  final String? moodEmoji;
  final String? weather;
  final String? weatherIconCode;
  final String? location;

  /// 原始精力值（未做 1~5 归一化，由展示组件按需处理）。
  final double? energyLevel;

  /// 单行化、去首尾空白并截断后的正文摘要；可能为空字符串。
  final String previewText;

  final String? _explicitCover;
  final String _contentJson;
  final String _contentText;

  /// 正文字数（口径见 [TextStats]）。懒计算：只有显示字数角标的样式才会
  /// 扫描整段纯文本。
  late final int wordCount = TextStats.countWords(_contentText);

  /// 预览封面：显式封面字段优先，否则取正文 Delta 中第一张图片。
  /// 懒计算：未解封胶囊等不展示封面的场景不必解析整段正文。
  late final String? previewCover = _resolvePreviewCover();

  /// 正文媒体概况（图片、录音、视频、附件）。懒计算：只有开启多图拼贴或
  /// 媒体角标的样式才会扫描整段正文。
  late final DiaryCardMediaSummary media = DiaryCardMediaSummary.scan(
    _contentJson,
  );

  /// 多图拼贴使用的图片：预览封面在前，再接正文中其余的图片，最多三张。
  late final List<String> collageImages = _resolveCollageImages();

  List<String> _resolveCollageImages() {
    final cover = previewCover;
    if (cover == null) {
      return const <String>[];
    }
    final images = <String>[cover];
    for (final image in media.images) {
      if (images.length >= 3) {
        break;
      }
      if (!images.contains(image)) {
        images.add(image);
      }
    }
    return List<String>.unmodifiable(images);
  }

  String? _resolvePreviewCover() {
    final explicit = _explicitCover?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return firstImageInContent(_contentJson);
  }

  /// 正文 Delta（或旧版 AppFlowy 文档）中的第一张图片；无图或正文损坏时为
  /// null。日历照片样式复用这一取图规则，与列表封面口径一致。
  static String? firstImageInContent(String contentJson) {
    final normalized = contentJson.trim();
    if (normalized.isEmpty) {
      return null;
    }
    try {
      return _findFirstImage(jsonDecode(normalized));
    } catch (_) {
      return null;
    }
  }

  /// 测试用：清空缓存，避免用例之间相互影响。
  static void debugClearCache() => _cache.clear();

  static Map<String, Object?> _decodeContext(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final context = decoded['context'];
        if (context is Map<String, dynamic>) {
          return context;
        }
      }
    } catch (_) {
      // metadata 损坏时按“无上下文信息”展示，不影响卡片其余内容。
    }
    return const <String, Object?>{};
  }

  static String? _nonEmptyString(Object? raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _buildPreviewText(String contentText) {
    final head = contentText.length > previewTextMaxLength
        ? contentText.substring(0, previewTextMaxLength)
        : contentText;
    return head.replaceAll('\n', ' ').trim();
  }

  /// 递归扫描 Delta 节点，兼容 list/map 嵌套与 image embed 写法。
  static String? _findFirstImage(Object? node) {
    if (node is List) {
      for (final item in node) {
        final image = _findFirstImage(item);
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
    for (final childKey in const <String>['root', 'children']) {
      final child = node[childKey];
      if (child != null) {
        final image = _findFirstImage(child);
        if (image != null) {
          return image;
        }
      }
    }
    return null;
  }
}
