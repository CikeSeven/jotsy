import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../../../core/database/audio_embed_codec.dart';
import '../../../core/database/code_block_codec.dart';
import '../../../core/database/divider_embed_codec.dart';
import '../../../core/database/file_embed_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_blocks_table.dart';
import '../../../core/database/diary_blocks/diary_blocks_walk.dart';
import '../../../core/database/diary_blocks/diary_list_style.dart';
import '../models/diary_text_colors.dart';

part 'diary_export_native_blocks.dart';

/// 正文的块级中间表示，供 PDF / Markdown / HTML / Word / 纯文本写出器共用。
///
/// 为什么不让每个写出器各自遍历正文：块文档的嵌套、列表序号与样式、代码
/// 块的行，以及历史 Delta 里挂在换行符上的行级属性，各写一遍既重复也容易
/// 在边界（只含嵌入的行、跨缩进的编号）上各自出错。这里统一解析一次：
/// - 每个文本行成为一个 [ExportBlock]，带块类型、缩进与按段计数的序号；
/// - 图片单独成块（[ExportBlockKind.image]），录音 / 视频 / 附件成块
///   （[ExportBlockKind.media]），由写出器决定内嵌还是只写名称；分隔线成块
///   （[ExportBlockKind.divider]）；
/// - 标注（[ExportBlockKind.callout]）带图标与底色档位，折叠列表
///   （[ExportBlockKind.toggle]）的子块照常以更深的缩进跟在后面，表格
///   （[ExportBlockKind.table]）整个是一块（[ExportBlock.tableRows]）；
/// - 行内只保留可迁移的样式：粗体、斜体、下划线、删除线、行内代码、链接、
///   上下标，以及字号、文字色与背景色（没有对应写法的格式照常略过）。
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
  callout,
  toggle,
  table,
}

/// 行内上标 / 下标（块文档行内属性 [kDiaryInlineScript]）。
enum ExportScript { superscript, subscript }

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
    this.color,
    this.background,
    this.size,
    this.script,
  });

  factory ExportInline.fromAttributes(String text, Map<String, dynamic> attrs) {
    final link = attrs['href'] ?? attrs['link'];
    final url = link is String ? link.trim() : '';
    Color? color(Object? value) =>
        value is String ? parseDiaryColorValue(value) : null;
    final background = color(attrs['bg_color'] ?? attrs['background']);
    final size = attrs['size'];
    return ExportInline(
      text,
      bold: attrs['bold'] == true,
      italic: attrs['italic'] == true,
      underline: attrs['underline'] == true,
      strike: attrs['strikethrough'] == true || attrs['strike'] == true,
      code: attrs['code'] == true,
      link: url.isEmpty ? null : url,
      color: color(attrs['font_color'] ?? attrs['color']),
      background: background == null || background.a == 0 ? null : background,
      size: size is String || size is num ? size.toString() : null,
      script: switch (attrs[kDiaryInlineScript]) {
        kDiaryScriptSuper => ExportScript.superscript,
        kDiaryScriptSub => ExportScript.subscript,
        _ => null,
      },
    );
  }

  /// 表格格子里两段之间的换行（见 [ExportBlock.tableRows]）。
  static const ExportInline lineBreak = ExportInline('\n');

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool code;

  /// 去掉首尾空白后的链接地址；没有链接为 null。
  final String? link;

  /// 文字色与背景色，保留透明度：不支持透明度的格式（Word）由写出器经
  /// [flattenDiaryColors] 叠到纸面上。没设、读不懂（只认 `#RRGGBB` /
  /// `#AARRGGBB`）或完全透明的背景为 null。
  final Color? color;
  final Color? background;

  /// Quill 行内字号：small / large / huge 或数字；由支持字号的写出器解析。
  final String? size;

  /// 上标 / 下标；普通文字为 null。
  final ExportScript? script;

  /// 是否为格子里的段间换行（[lineBreak]）。
  bool get isLineBreak => text == '\n';

  /// 改文字或颜色、补斜体后的副本（PDF 准备正文时压平颜色、给代码着色用）；
  /// 没给的项保持原样。
  ExportInline copyWith({
    String? text,
    Color? color,
    Color? background,
    bool? italic,
  }) => ExportInline(
    text ?? this.text,
    bold: bold,
    italic: italic ?? this.italic,
    underline: underline,
    strike: strike,
    code: code,
    link: link,
    color: color ?? this.color,
    background: background ?? this.background,
    size: size,
    script: script,
  );
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
    this.codeLanguage,
    this.orderedStyle,
    this.bulletStyle,
    this.calloutIcon,
    this.calloutTone,
    this.tableRows = const <List<List<ExportInline>>>[],
    this.tableHeaderRow = false,
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

  /// 代码块明确指定的语言：已知 highlight.js id 或 [kCodeBlockPlain]；
  /// 未指定（`code-block: true`）或非代码块为 null。写出器按它给围栏 /
  /// `<code>` 标语言，并在语言变化处把相邻代码行分成两段。
  final String? codeLanguage;

  /// 有序 / 无序列表实际显示的样式（`diary_list_style.dart`，已按层级补全），
  /// 与编辑器一致；历史 Delta（[ExportBlockParser.parse]）没有样式，为 null。
  final DiaryOrderedListStyle? orderedStyle;
  final DiaryBulletListStyle? bulletStyle;

  /// 标注的图标（emoji，缺省为 [kDiaryCalloutDefaultIcon]）与底色档位
  /// （[kDiaryCalloutTones] 之一，认不出的已归为 [kDiaryCalloutToneDefault]）；
  /// 其他块为 null。
  final String? calloutIcon;
  final String? calloutTone;

  /// 表格的格子文字：`tableRows[行][列]` 是一格的行内片段。一格里有几段时，
  /// 段与段之间是一个 [ExportInline.lineBreak]（文字恰为 `\n`、不带格式的
  /// 片段），其余片段不含换行；空格子为空列表。只有表格块有，行列数与
  /// 编辑器里一致。
  final List<List<List<ExportInline>>> tableRows;

  /// 表格首行是否为表头；其他块为 false。
  final bool tableHeaderRow;

  /// 纯文本、PDF、Word 写在行首的列表标记（不含其后的空白）：有序为按样式
  /// 排出的序号（如 `a.`、`一、`、`①`），无序为样式的字符；没有样式时为
  /// `1.` 与 `•`。其他块为空串。
  String get listMarker => switch (kind) {
    ExportBlockKind.ordered =>
      (orderedStyle ?? DiaryOrderedListStyle.decimal).label(ordinal),
    ExportBlockKind.bullet => (bulletStyle ?? DiaryBulletListStyle.disc).glyph,
    _ => '',
  };

  /// 块的文字（不含列表标记与标注图标）；表格为每行一行、格间 ` | `
  /// （与 [fallbackLines] 同一口径）。
  String get plainText => kind == ExportBlockKind.table
      ? fallbackLines.map(_joinText).join('\n')
      : _joinText(inlines);

  static String _joinText(List<ExportInline> runs) =>
      runs.map((ExportInline run) => run.text).join();

  /// 还没有专门写法的块（标注、折叠列表、表格）退化成的普通段落文字，每项
  /// 一段：标注以图标开头、折叠列表以 `▸ ` 开头；表格每行一段，格与格之间
  /// ` | `，一格里的几段以空格相连（空段略过，整行都空时为空段）。其他块
  /// 就是 [inlines] 一段。各写出器给这三种块补上专门写法之前都按它写，
  /// 内容不丢。
  List<List<ExportInline>> get fallbackLines => switch (kind) {
    ExportBlockKind.callout => <List<ExportInline>>[
      <ExportInline>[
        ExportInline('${calloutIcon ?? kDiaryCalloutDefaultIcon} '),
        ...inlines,
      ],
    ],
    ExportBlockKind.toggle => <List<ExportInline>>[
      <ExportInline>[const ExportInline('▸ '), ...inlines],
    ],
    ExportBlockKind.table => <List<ExportInline>>[
      for (final row in tableRows) _fallbackRow(row),
    ],
    _ => <List<ExportInline>>[inlines],
  };

  static List<ExportInline> _fallbackRow(List<List<ExportInline>> row) {
    final cells = <List<ExportInline>>[
      for (final cell in row) _fallbackCell(cell),
    ];
    if (cells.every((List<ExportInline> cell) => cell.isEmpty)) {
      return const <ExportInline>[];
    }
    return <ExportInline>[
      for (final (index, cell) in cells.indexed) ...<ExportInline>[
        if (index > 0) const ExportInline(' | '),
        ...cell,
      ],
    ];
  }

  /// 一格的几段以空格相连，空段略过。
  static List<ExportInline> _fallbackCell(List<ExportInline> cell) {
    final paragraphs = <List<ExportInline>>[<ExportInline>[]];
    for (final run in cell) {
      if (run.isLineBreak) {
        paragraphs.add(<ExportInline>[]);
      } else {
        paragraphs.last.add(run);
      }
    }
    final kept = paragraphs.where(
      (List<ExportInline> runs) => _joinText(runs).trim().isNotEmpty,
    );
    return <ExportInline>[
      for (final (index, runs) in kept.indexed) ...<ExportInline>[
        if (index > 0) const ExportInline(' '),
        ...runs,
      ],
    ];
  }

  /// 同缩进、同对齐的普通段落，文字换成 [inlines]（写出器把块退化为段落时
  /// 用，如 [fallbackLines]、PDF 的媒体说明行）。
  ExportBlock paragraphWith(List<ExportInline> inlines) => ExportBlock._(
    kind: ExportBlockKind.paragraph,
    inlines: List<ExportInline>.unmodifiable(inlines),
    indent: indent,
    align: align,
  );

  /// 换掉行内片段或来源后的副本，其余不变（PDF 准备正文时用）。
  ExportBlock copyWith({List<ExportInline>? inlines, String? source}) =>
      ExportBlock._(
        kind: kind,
        inlines: inlines == null
            ? this.inlines
            : List<ExportInline>.unmodifiable(inlines),
        level: level,
        indent: indent,
        ordinal: ordinal,
        align: align,
        source: source ?? this.source,
        mediaKind: mediaKind,
        mediaName: mediaName,
        mediaDuration: mediaDuration,
        codeLanguage: codeLanguage,
        orderedStyle: orderedStyle,
        bulletStyle: bulletStyle,
        calloutIcon: calloutIcon,
        calloutTone: calloutTone,
        tableRows: tableRows,
        tableHeaderRow: tableHeaderRow,
      );

  bool get isListItem =>
      kind == ExportBlockKind.bullet ||
      kind == ExportBlockKind.ordered ||
      kind == ExportBlockKind.checked ||
      kind == ExportBlockKind.unchecked;
}

/// 解析正文为块列表。
class ExportBlockParser {
  const ExportBlockParser._();

  /// 当前正文（块文档）直接读树，所有导出格式与分享都走这里。
  static List<ExportBlock> parseDocument(Map<String, Object?> document) =>
      _parseNativeBlocks(document);

  /// 历史 Delta 的 op 列表（没有块文档的旧调用与以平铺正文写的测试）；
  /// 没有标注、折叠列表与表格，也没有列表样式。
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
          codeLanguage: kind == ExportBlockKind.code
              ? codeBlockExplicitLanguage(attrs['code-block'])
              : null,
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
            line.add(ExportInline.fromAttributes(parts[i], attrs));
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

  /// 一个 Quill 嵌入（历史 Delta，或块文档里原样保留的未知嵌入
  /// [kDiaryBlockUnknownEmbed]）对应的块；[indent] / [align] 为它所在的行。
  static ExportBlock? _embed(
    Map<dynamic, dynamic> insert, {
    int indent = 0,
    ExportAlign align = ExportAlign.start,
  }) {
    final image = insert['image'];
    if (image is String && image.trim().isNotEmpty) {
      return ExportBlock._(
        kind: ExportBlockKind.image,
        source: image.trim(),
        indent: indent,
        align: align,
      );
    }
    final audio = DiaryAudioAttachment.tryDecode(insert[diaryAudioEmbedType]);
    if (audio != null) {
      return ExportBlock._(
        kind: ExportBlockKind.media,
        source: audio.path,
        mediaKind: ExportMediaKind.audio,
        mediaName: audio.name,
        mediaDuration: audio.duration,
        indent: indent,
        align: align,
      );
    }
    final video = DiaryFileAttachment.tryDecode(insert['video']);
    if (video != null) {
      return ExportBlock._(
        kind: ExportBlockKind.media,
        source: video.path,
        mediaKind: ExportMediaKind.video,
        mediaName: video.displayName,
        indent: indent,
        align: align,
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
          indent: indent,
          align: align,
        );
      }
    }
    if (insert.containsKey(diaryDividerEmbedType)) {
      return ExportBlock._(
        kind: ExportBlockKind.divider,
        indent: indent,
        align: align,
      );
    }
    // 其他未知嵌入没有可迁移的内容，直接略过。
    return null;
  }
}
