import 'package:flutter/foundation.dart';

import '../../../core/database/audio_embed_codec.dart';
import '../../../core/database/divider_embed_codec.dart';
import '../../../core/database/file_embed_codec.dart';

/// 正文 Delta 的块级中间表示，供 Markdown / HTML / Word / 纯文本写出器共用。
///
/// 为什么不让每个写出器各自遍历 Delta：行级属性（列表、标题、引用、对齐）
/// 挂在换行符上，嵌入与行内样式又散落在文本片段里，各写一遍既重复也容易
/// 在边界（只含嵌入的行、跨缩进的编号）上各自出错。这里统一解析一次：
/// - 每个文本行成为一个 [ExportBlock]，带块类型、缩进与按段计数的序号；
/// - 图片单独成块（[ExportBlockKind.image]），录音 / 视频 / 附件成块
///   （[ExportBlockKind.media]），由写出器决定内嵌还是只写名称；分隔线成块
///   （[ExportBlockKind.divider]）；
/// - 行内只保留可迁移的样式：粗体、斜体、下划线、删除线、行内代码、链接。
/// 纯函数，无 IO。
enum ExportBlockKind {
  paragraph,
  heading,
  bullet,
  ordered,
  checked,
  unchecked,
  quote,
  code,
  image,
  media,
  divider,
}

enum ExportMediaKind { audio, video, file }

enum ExportAlign { start, center, end, justify }

@immutable
class ExportInline {
  const ExportInline(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.code = false,
    this.link,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool code;

  /// 去掉首尾空白后的链接地址；没有链接为 null。
  final String? link;
}

@immutable
class ExportBlock {
  const ExportBlock._({
    required this.kind,
    this.inlines = const <ExportInline>[],
    this.level = 0,
    this.indent = 0,
    this.ordinal = 0,
    this.align = ExportAlign.start,
    this.source,
    this.mediaKind,
    this.mediaName,
    this.mediaDuration,
  });

  final ExportBlockKind kind;
  final List<ExportInline> inlines;

  /// 标题级别 1~6；其他块为 0。
  final int level;

  /// 列表与段落缩进级别（0 起）。
  final int indent;

  /// 有序列表在同一缩进层级内的序号（1 起），其他块为 0。
  final int ordinal;
  final ExportAlign align;

  /// 图片 / 媒体的原始来源（本地路径、http(s) 或 data URI）。
  final String? source;
  final ExportMediaKind? mediaKind;

  /// 媒体显示名称（附件原文件名、录音名），不含设备路径。
  final String? mediaName;
  final Duration? mediaDuration;

  String get plainText => inlines.map((ExportInline run) => run.text).join();

  bool get isListItem =>
      kind == ExportBlockKind.bullet ||
      kind == ExportBlockKind.ordered ||
      kind == ExportBlockKind.checked ||
      kind == ExportBlockKind.unchecked;
}

/// 解析 Delta ops 为块列表。
class ExportBlockParser {
  const ExportBlockParser._();

  static List<ExportBlock> parse(List<dynamic> rawOps) {
    final blocks = <ExportBlock>[];
    var line = <ExportInline>[];
    // 同一行里出现过的嵌入：行内只有嵌入时整行不再生成空段落。
    var lineHadEmbed = false;
    final orderedCounters = <int, int>{};

    void flushLine(Map<String, dynamic> attrs) {
      final inlines = line;
      line = <ExportInline>[];
      final embedOnly =
          lineHadEmbed &&
          inlines.every((ExportInline run) => run.text.trim().isEmpty);
      lineHadEmbed = false;
      if (embedOnly) {
        return;
      }
      final indent = attrs['indent'] is num
          ? (attrs['indent'] as num).toInt().clamp(0, 8)
          : 0;
      final listType = attrs['list']?.toString();
      final header = attrs['header'];
      final kind = switch (listType) {
        'bullet' => ExportBlockKind.bullet,
        'ordered' => ExportBlockKind.ordered,
        'checked' => ExportBlockKind.checked,
        'unchecked' => ExportBlockKind.unchecked,
        _ when header is num && header >= 1 => ExportBlockKind.heading,
        _ when attrs['code-block'] != null && attrs['code-block'] != false =>
          ExportBlockKind.code,
        _ when attrs['blockquote'] == true => ExportBlockKind.quote,
        _ => ExportBlockKind.paragraph,
      };
      var ordinal = 0;
      if (kind == ExportBlockKind.ordered) {
        // 回到上一级时，更深层级的编号重新开始。
        orderedCounters.removeWhere((int level, _) => level > indent);
        ordinal = orderedCounters[indent] = (orderedCounters[indent] ?? 0) + 1;
      } else if (kind == ExportBlockKind.bullet ||
          kind == ExportBlockKind.checked ||
          kind == ExportBlockKind.unchecked) {
        // 同级换成别的列表即另起一个列表；更浅层级的编号（嵌套在有序
        // 列表下的无序子项）保留，回到上一级时接着数。
        orderedCounters.removeWhere((int level, _) => level >= indent);
      } else {
        orderedCounters.clear();
      }
      blocks.add(
        ExportBlock._(
          kind: kind,
          inlines: List<ExportInline>.unmodifiable(inlines),
          level: kind == ExportBlockKind.heading
              ? (header as num).toInt().clamp(1, 6)
              : 0,
          indent: indent,
          ordinal: ordinal,
          align: switch (attrs['align']) {
            'center' => ExportAlign.center,
            'right' => ExportAlign.end,
            'justify' => ExportAlign.justify,
            _ => ExportAlign.start,
          },
        ),
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
            line.add(_inline(parts[i], attrs));
          }
          if (i < parts.length - 1) {
            flushLine(attrs);
          }
        }
      } else if (insert is Map) {
        lineHadEmbed = true;
        final embed = _embed(insert);
        if (embed != null) {
          blocks.add(embed);
        }
      }
    }
    if (line.isNotEmpty) {
      flushLine(const <String, dynamic>{});
    }
    return List<ExportBlock>.unmodifiable(blocks);
  }

  static ExportInline _inline(String text, Map<String, dynamic> attrs) {
    final link = attrs['link'];
    final url = link is String ? link.trim() : '';
    return ExportInline(
      text,
      bold: attrs['bold'] == true,
      italic: attrs['italic'] == true,
      underline: attrs['underline'] == true,
      strike: attrs['strike'] == true,
      code: attrs['code'] == true,
      link: url.isEmpty ? null : url,
    );
  }

  static ExportBlock? _embed(Map<dynamic, dynamic> insert) {
    final image = insert['image'];
    if (image is String && image.trim().isNotEmpty) {
      return ExportBlock._(kind: ExportBlockKind.image, source: image.trim());
    }
    final audio = DiaryAudioAttachment.tryDecode(insert[diaryAudioEmbedType]);
    if (audio != null) {
      return ExportBlock._(
        kind: ExportBlockKind.media,
        source: audio.path,
        mediaKind: ExportMediaKind.audio,
        mediaName: audio.name,
        mediaDuration: audio.duration,
      );
    }
    final video = DiaryFileAttachment.tryDecode(insert['video']);
    if (video != null) {
      return ExportBlock._(
        kind: ExportBlockKind.media,
        source: video.path,
        mediaKind: ExportMediaKind.video,
        mediaName: video.displayName,
      );
    }
    for (final type in diaryFileEmbedTypes) {
      final file = DiaryFileAttachment.tryDecode(insert[type]);
      if (file != null) {
        return ExportBlock._(
          kind: ExportBlockKind.media,
          source: file.path,
          mediaKind: ExportMediaKind.file,
          mediaName: file.displayName,
        );
      }
    }
    if (insert.containsKey(diaryDividerEmbedType)) {
      return const ExportBlock._(kind: ExportBlockKind.divider);
    }
    // 其他未知嵌入没有可迁移的内容，直接略过。
    return null;
  }
}
