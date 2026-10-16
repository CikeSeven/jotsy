import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/content_codec.dart';
import 'diary_share_options.dart';
import 'diary_share_target.dart';

/// 一篇日记中可供分享的素材，从详情解析一次，随选项变化反复组装文字。
///
/// 输入：标题、正文 Delta（ops 列表）、封面、metadata.context 中的心情/天气/
/// 地点、标签名与发表时间；输出：[composeText] 生成的纯文本与 [images]。
/// 无副作用，不读取文件：图片是否还在磁盘上由分享控制器在发送前确认。
@immutable
class DiaryShareContent {
  const DiaryShareContent({
    required this.title,
    required this.body,
    required this.images,
    required this.tagNames,
    required this.createdAt,
    this.moodEmoji,
    this.weather,
    this.location,
  });

  /// 从日记详情解析（正文经 [decodeDiaryContentToDocument]，兼容旧版格式）。
  factory DiaryShareContent.fromDetail(DiaryWithTags detail) {
    final diary = detail.diary;
    return DiaryShareContent.parse(
      title: diary.title,
      deltaOps: decodeDiaryContentToDocument(diary.content).toDelta().toJson(),
      cover: diary.cover,
      metadata: diary.metadata,
      tagNames: detail.tags.map((Tag tag) => tag.name).toList(),
      createdAt: diary.createdAt,
    );
  }

  /// 从日记字段解析。[deltaOps] 取自 `Document.toDelta().toJson()`，旧版
  /// 正文已由 `decodeDiaryContentToDocument` 转成 Delta，这里只认 Delta。
  factory DiaryShareContent.parse({
    required String title,
    required List<dynamic> deltaOps,
    required String? cover,
    required String metadata,
    required List<String> tagNames,
    required DateTime createdAt,
  }) {
    final body = DiaryShareBodyFormatter.format(deltaOps);
    final images = <String>[];
    void addImage(String? source) {
      final normalized = source?.trim();
      if (normalized != null &&
          normalized.isNotEmpty &&
          !images.contains(normalized)) {
        images.add(normalized);
      }
    }

    // 封面排在最前：它是这篇日记的“头图”，多数平台第一张图即封面。
    addImage(cover);
    for (final source in body.images) {
      addImage(source);
    }
    final context = _decodeContext(metadata);
    return DiaryShareContent(
      title: title.trim(),
      body: body.text,
      images: List<String>.unmodifiable(images),
      tagNames: List<String>.unmodifiable(
        tagNames
            .map((String name) => name.trim())
            .where((String name) => name.isNotEmpty),
      ),
      createdAt: createdAt,
      moodEmoji: _nonEmpty(context['moodEmoji']),
      weather: _nonEmpty(context['weather']),
      location: _nonEmpty(context['location']),
    );
  }

  final String title;

  /// 正文纯文本：保留列表符号与换行，去掉行内格式与媒体嵌入。
  final String body;

  /// 封面与正文图片，按出现顺序去重。
  final List<String> images;
  final List<String> tagNames;
  final DateTime createdAt;
  final String? moodEmoji;
  final String? weather;
  final String? location;

  bool get hasMoodWeather => moodEmoji != null || weather != null;

  /// 按 [options] 组装分享文字；所有部分都被关闭或为空时返回空字符串。
  ///
  /// 版式：标题、正文各占一段，末段为“日期 · 天气 · 地点 · 心情”一行与
  /// 标签一行。日期文案由调用方按界面语言格式化后传入。
  String composeText(
    DiaryShareOptions options, {
    required String dateLabel,
    DiaryShareTagStyle tagStyle = DiaryShareTagStyle.hashtag,
  }) {
    final sections = <String>[
      if (options.includeTitle && title.isNotEmpty) title,
      if (options.includeBody && body.isNotEmpty) body,
    ];
    final metaParts = <String>[
      if (options.includeDate && dateLabel.trim().isNotEmpty) dateLabel.trim(),
      if (options.includeMoodWeather && weather != null) weather!,
      if (options.includeLocation && location != null) location!,
      if (options.includeMoodWeather && moodEmoji != null) moodEmoji!,
    ];
    final footer = <String>[
      if (metaParts.isNotEmpty) metaParts.join(' · '),
      if (options.includeTags && tagNames.isNotEmpty)
        tagNames.map(tagStyle.format).join(' '),
    ];
    if (footer.isNotEmpty) {
      sections.add(footer.join('\n'));
    }
    return sections.join('\n\n');
  }

  static Map<String, Object?> _decodeContext(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['context'] is Map) {
        return (decoded['context'] as Map).cast<String, Object?>();
      }
    } catch (_) {
      // metadata 损坏时按“无上下文”分享，不影响标题与正文。
    }
    return const <String, Object?>{};
  }

  static String? _nonEmpty(Object? raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}

/// 正文 Delta → 适合贴进社交应用的纯文本。
///
/// 社交应用的发布框不渲染 Markdown，`**粗体**` 之类的标记会原样露出来，
/// 所以只保留读得懂的结构：列表用 `•` / `1.` / `☐` / `☑` 前缀、引用用
/// `> `、缩进两格一级；链接文字与地址不同时在后面附上地址。图片收集到
/// [DiaryShareBody.images]，录音、视频、附件这类发不出去的嵌入直接略过，
/// 只含嵌入的行整行去掉，避免正文里出现大段空行。
class DiaryShareBodyFormatter {
  const DiaryShareBodyFormatter._();

  static DiaryShareBody format(List<dynamic> rawOps) {
    final lines = <String>[];
    final images = <String>[];
    final line = StringBuffer();
    var lineHasEmbed = false;
    final orderedCounters = <int, int>{};

    void flushLine(Map<String, dynamic> attrs) {
      final text = line.toString();
      line.clear();
      final embedOnly = lineHasEmbed && text.trim().isEmpty;
      lineHasEmbed = false;
      if (embedOnly) {
        return;
      }
      final listType = attrs['list']?.toString();
      final indent = attrs['indent'] is num
          ? (attrs['indent'] as num).toInt().clamp(0, 8)
          : 0;
      if (listType != 'ordered') {
        orderedCounters.clear();
      } else {
        // 回到上一级时，更深层级的编号重新开始。
        orderedCounters.removeWhere((int level, _) => level > indent);
      }
      final prefix = switch (listType) {
        'bullet' => '• ',
        'ordered' =>
          '${orderedCounters[indent] = (orderedCounters[indent] ?? 0) + 1}. ',
        'checked' => '☑ ',
        'unchecked' => '☐ ',
        _ => attrs['blockquote'] == true ? '> ' : '',
      };
      lines.add(
        text.isEmpty && prefix.isEmpty ? '' : '${'  ' * indent}$prefix$text',
      );
    }

    for (final rawOp in rawOps) {
      if (rawOp is! Map) {
        continue;
      }
      final attrs = rawOp['attributes'] is Map
          ? (rawOp['attributes'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{};
      final insert = rawOp['insert'];
      if (insert is String) {
        final parts = insert.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (parts[i].isNotEmpty) {
            line.write(_inlineText(parts[i], attrs));
          }
          if (i < parts.length - 1) {
            flushLine(attrs);
          }
        }
      } else if (insert is Map) {
        lineHasEmbed = true;
        final image = insert['image'];
        if (image is String && image.trim().isNotEmpty) {
          images.add(image.trim());
        }
      }
    }
    if (line.isNotEmpty) {
      flushLine(const <String, dynamic>{});
    }
    return DiaryShareBody(text: _collapseBlankLines(lines), images: images);
  }

  static String _inlineText(String text, Map<String, dynamic> attrs) {
    final link = attrs['link'];
    if (link is String) {
      final url = link.trim();
      if (url.isNotEmpty && url != text.trim()) {
        return '$text ($url)';
      }
    }
    return text;
  }

  /// 连续空行压成一行，并去掉首尾空行与每行行尾空白。
  static String _collapseBlankLines(List<String> lines) {
    final out = <String>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty && (out.isEmpty || out.last.isEmpty)) {
        continue;
      }
      out.add(line);
    }
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out.join('\n');
  }
}

@immutable
class DiaryShareBody {
  const DiaryShareBody({required this.text, required this.images});

  final String text;

  /// 正文图片，按出现顺序（未去重，由 [DiaryShareContent] 统一去重）。
  final List<String> images;
}
