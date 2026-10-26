import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_to_delta.dart';
import '../export/diary_export_blocks.dart';
import '../export/diary_export_plain_text.dart';
import 'diary_context_info.dart';
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
      deltaOps: diaryBlocksToQuillOps(decodeStoredDiaryBlocks(diary.content)),
      cover: diary.cover,
      metadata: diary.metadata,
      tagNames: detail.tags.map((Tag tag) => tag.name).toList(),
      createdAt: diary.createdAt,
      blockDocument: decodeStoredDiaryBlocks(diary.content),
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
    Map<String, Object?>? blockDocument,
  }) {
    final body = blockDocument == null
        ? DiaryShareBodyFormatter.format(deltaOps)
        : DiaryShareBodyFormatter.fromBlocks(
            ExportBlockParser.parseDocument(blockDocument),
          );
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
    final context = DiaryContextInfo.parse(metadata);
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
      moodEmoji: context.moodEmoji,
      weather: context.weather,
      location: context.location,
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
}

/// 正文 Delta → 适合贴进社交应用的纯文本与图片列表。
///
/// 解析经 [ExportBlockParser]、文字经 [ExportPlainText]（与 TXT 导出同一套
/// 规则）；录音、视频、附件这类发不出去的嵌入直接略过。
class DiaryShareBodyFormatter {
  const DiaryShareBodyFormatter._();

  static DiaryShareBody format(List<dynamic> rawOps) {
    final blocks = ExportBlockParser.parse(rawOps);
    return fromBlocks(blocks);
  }

  static DiaryShareBody fromBlocks(List<ExportBlock> blocks) {
    return DiaryShareBody(
      text: ExportPlainText.render(blocks),
      images: <String>[
        for (final block in blocks)
          if (block.kind == ExportBlockKind.image) block.source!,
      ],
    );
  }
}

@immutable
class DiaryShareBody {
  const DiaryShareBody({required this.text, required this.images});

  final String text;

  /// 正文图片，按出现顺序（未去重，由 [DiaryShareContent] 统一去重）。
  final List<String> images;
}
