import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/content_codec.dart';
import '../../../utils/text_stats.dart';
import '../models/diary_context_info.dart';
import 'diary_export_blocks.dart';

/// 一篇待导出日记的全部素材，从详情解析一次，各写出器只读不改。
///
/// [deltaOps] 保留给 PDF（经 flutter_quill_to_pdf 渲染，样式更全），其余
/// 格式统一读 [blocks]。旧版正文由 [decodeDiaryContentToDocument] 转成 Delta。
@immutable
class DiaryExportEntry {
  const DiaryExportEntry({
    required this.diaryId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.deltaOps,
    required this.blocks,
    required this.wordCount,
    this.tagNames = const <String>[],
    this.cover,
    this.context = const DiaryContextInfo(),
  });

  factory DiaryExportEntry.fromDetail(DiaryWithTags detail) {
    final diary = detail.diary;
    return DiaryExportEntry.parse(
      diaryId: diary.diaryId,
      title: diary.title,
      createdAt: diary.createdAt,
      updatedAt: diary.updatedAt,
      deltaOps: decodeDiaryContentToDocument(diary.content).toDelta().toJson(),
      wordCount: DiaryWordCounts.of(
        diaryId: diary.diaryId,
        updatedAt: diary.updatedAt,
        text: diary.contentText,
      ),
      tagNames: detail.tags.map((Tag tag) => tag.name).toList(),
      cover: diary.cover,
      metadata: diary.metadata,
    );
  }

  factory DiaryExportEntry.parse({
    required String diaryId,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    required List<dynamic> deltaOps,
    int? wordCount,
    List<String> tagNames = const <String>[],
    String? cover,
    String metadata = '{}',
  }) {
    final blocks = ExportBlockParser.parse(deltaOps);
    final normalizedCover = cover?.trim();
    return DiaryExportEntry(
      diaryId: diaryId,
      title: title.trim(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      deltaOps: List<dynamic>.unmodifiable(deltaOps),
      blocks: blocks,
      wordCount:
          wordCount ??
          TextStats.countWords(
            blocks.map((ExportBlock block) => block.plainText).join('\n'),
          ),
      tagNames: List<String>.unmodifiable(
        tagNames
            .map((String name) => name.trim())
            .where((String name) => name.isNotEmpty),
      ),
      cover: normalizedCover == null || normalizedCover.isEmpty
          ? null
          : normalizedCover,
      context: DiaryContextInfo.parse(metadata),
    );
  }

  final String diaryId;

  /// 去掉首尾空白的标题，可能为空（写出器回落“无标题”）。
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<dynamic> deltaOps;
  final List<ExportBlock> blocks;

  /// 正文字数（经 [TextStats]，与卡片、日历、探索页与预览页同一口径）。
  final int wordCount;
  final List<String> tagNames;
  final String? cover;
  final DiaryContextInfo context;

  /// 封面与正文图片，按出现顺序去重；封面在最前。
  List<String> get imageSources {
    final sources = <String>[?cover];
    for (final block in blocks) {
      if (block.kind == ExportBlockKind.image &&
          !sources.contains(block.source)) {
        sources.add(block.source!);
      }
    }
    return sources;
  }

  /// 录音、视频与附件的来源。
  Iterable<String> get attachmentSources => blocks
      .where((ExportBlock block) => block.kind == ExportBlockKind.media)
      .map((ExportBlock block) => block.source!);
}

/// 写出器需要的界面文案与日期格式，由调用方按当前语言构造。
///
/// 写出器是纯函数，不依赖 BuildContext；把文案集中成一个对象传入，测试
/// 可以直接构造固定文案验证版式。
@immutable
class DiaryExportLabels {
  const DiaryExportLabels({
    required this.untitled,
    required this.mood,
    required this.energy,
    required this.weather,
    required this.location,
    required this.tags,
    required this.date,
    required this.time,
    required this.title,
    required this.content,
    required this.wordCount,
    required this.updated,
    required this.image,
    required this.audio,
    required this.video,
    required this.attachment,
    required this.formatDateTime,
    required this.formatDate,
    required this.exportedBy,
  });

  final String untitled;
  final String mood;
  final String energy;
  final String weather;
  final String location;
  final String tags;
  final String date;
  final String time;
  final String title;
  final String content;
  final String wordCount;
  final String updated;
  final String image;
  final String audio;
  final String video;
  final String attachment;

  /// 日记抬头用的完整日期时间（含星期），如“2026年4月3日 星期五 09:00”。
  final String Function(DateTime value) formatDateTime;

  /// 只含日期的短格式，用于合集标题的起止日期。
  final String Function(DateTime value) formatDate;

  /// HTML 页脚与 Word 文档属性中的“由 Jotsy 导出”。
  final String exportedBy;

  String titleOf(DiaryExportEntry entry) =>
      entry.title.isEmpty ? untitled : entry.title;

  /// 嵌入块的一行文字说明（纯文本、PDF、Word 中不能内嵌媒体时使用）。
  String mediaLine(ExportBlock block) {
    final name = block.mediaName?.trim();
    return switch (block.mediaKind) {
      ExportMediaKind.audio =>
        '[$audio${_join(name, _duration(block.mediaDuration))}]',
      ExportMediaKind.video => '[$video${_join(name, null)}]',
      ExportMediaKind.file => '[$attachment${_join(name, null)}]',
      null => '[$image]',
    };
  }

  static String _join(String? name, String? extra) {
    final parts = <String>[if (name != null && name.isNotEmpty) name, ?extra];
    return parts.isEmpty ? '' : ' ${parts.join(' · ')}';
  }

  static String? _duration(Duration? value) {
    if (value == null || value <= Duration.zero) {
      return null;
    }
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 一篇日记的信息行：“天气 · 地点 · 心情 · 精力 n/5”，没有时为空。
  /// [includeMood] 为 false 时省略心情（PDF 字体不含 emoji，会画成方框）。
  String metaLine(DiaryExportEntry entry, {bool includeMood = true}) {
    final context = entry.context;
    return <String>[
      ?context.weather,
      ?context.location,
      if (includeMood && context.moodEmoji != null) context.moodEmoji!,
      if (context.energyLevel != null) '$energy ${context.energyLevel}/5',
    ].join(' · ');
  }
}
