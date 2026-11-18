// 日记正文 → 智能体看到的“正文 Markdown”：读日记（`read_diaries`、对话固定
// 的那篇）、改正文（`edit_diary`）与新建（`create_diary`）共用这一套写法，
// 模型读到什么就照什么改（修改见 `ai_diary_markdown_edit.dart`）。纯函数。
//
// 写法与模板 Markdown 逐字相同（`ai_template_markdown.dart`：一行一个块，
// 子块多缩进两格，标题、列表、待办、引用、提示块、折叠块、代码块、表格、
// 行内格式与块属性都写得出来，读写对称），另加日记才有的内容：
// - 图片单独一行写“[图片 n]”：编号与 `view_images` 相同，即按正文顺序去重
//   的来源（`AiVisionImages.sourcesOf`）；旧版多键嵌入里的几张写在同一行；
// - 视频、录音、附件、日记链接卡片、思维导图与认不出的块各写一行“[视频 1]”
//   “[附件 1: 名称]”这样的标记：按种类各自编号，冒号后是给模型看的说明
//   （文件名、卡片标题、导图的文字）。
// 标记只代表原来的块：改正文时原样留着就是留着，删掉这一行就是删掉，挪到
// 别处就是挪过去；改动标记里的字或编号不会生成新的媒体。
//
// 输出按“行”组织（一个块，不含子块）：每行记下原来的块、缩进层级与写出的
// 文字（代码块、表格占几行），修改时据此只重读改到的行，其余原样保留。
// 正文里的软换行（编辑器不会产生，只可能来自异常数据）写成空格，免得一个块
// 跨行。

import '../../../core/database/app_database.dart';
import '../../../core/database/audio_embed_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_media.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_blocks_walk.dart';
import '../../../core/database/file_embed_codec.dart';
import '../../../core/database/mind_map/mind_map_blocks.dart';
import '../../../l10n/app_localizations.dart';
import 'ai_template_markdown.dart';

/// 正文 Markdown 的一行（一个块，不含子块）。
class AiDiaryMarkdownRow {
  const AiDiaryMarkdownRow({
    required this.node,
    required this.depth,
    required this.text,
    this.mark,
  });

  /// 原来的块（表格连同格子；其余块的子块另成行）。
  final Map<String, Object?> node;

  /// 缩进层级（顶层为 0）。
  final int depth;

  /// 写出的文字，含缩进；代码块与表格的几行以 `\n` 相连。
  final String text;

  /// 只写成标记的块（媒体等）：标记本身，不含缩进。
  final String? mark;
}

/// 一篇正文写成的 Markdown：逐行的块与整段文字（各行以 `\n` 相连）。
class AiDiaryMarkdown {
  AiDiaryMarkdown._(this.rows, this.marks)
    : text = rows.map((row) => row.text).join('\n'),
      starts = _starts(rows);

  /// 至少一行：空正文为一个空段落。
  final List<AiDiaryMarkdownRow> rows;
  final AiDiaryMarks marks;
  final String text;

  /// 每行在 [text] 里的起点。
  final List<int> starts;

  static List<int> _starts(List<AiDiaryMarkdownRow> rows) {
    final starts = <int>[];
    var offset = 0;
    for (final row in rows) {
      starts.add(offset);
      offset += row.text.length + 1;
    }
    return starts;
  }
}

/// 标记的写法（按提示词语言）与识别。
class AiDiaryMarks {
  AiDiaryMarks(this.l10n)
    : _photos = _photosPattern(l10n),
      _embed = RegExp(
        '^\\[(?:${[for (final kind in _kinds) RegExp.escape(l10n.aiPromptDiaryEmbedKind(kind))].join('|')}) \\d+(?:: .*)?\\]\$',
      );

  final AppLocalizations l10n;
  final RegExp _photos;
  final RegExp _embed;

  static const List<String> _kinds = <String>[
    'video',
    'audio',
    'file',
    'link',
    'mindmap',
    'other',
  ];

  /// “[图片 n]”的写法（同 `view_images` 的编号）。
  String photo(int number) => l10n.aiPromptDiaryImage(number);

  /// 其他媒体与块的标记：“[视频 1]”“[附件 1: 名称]”。
  String embed(String kind, int number, [String? info]) {
    final name = l10n.aiPromptDiaryEmbedKind(kind);
    final detail = info?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    return detail.isEmpty ? '[$name $number]' : '[$name $number: $detail]';
  }

  /// 一行（去掉缩进后）是不是标记的样子：一个或几个以空格相连的图片标记
  /// （旧版多键嵌入），或其他标记。
  bool looksLikeMark(String line) {
    final text = line.trim();
    return _embed.hasMatch(text) || _photos.hasMatch(text);
  }

  /// 由“[图片 1]”的写法反推出识别用的正则（编号换成 `\d+`），认一个或几个
  /// 以空格相连的图片标记。
  static RegExp _photosPattern(AppLocalizations l10n) {
    const probe = 918273;
    final sample = l10n.aiPromptDiaryImage(probe);
    final at = sample.indexOf('$probe');
    final one = at < 0
        ? r'\[\S+ \d+\]'
        : '${RegExp.escape(sample.substring(0, at))}\\d+'
              '${RegExp.escape(sample.substring(at + '$probe'.length))}';
    return RegExp('^$one(?: $one)*\$');
  }
}

/// 把一篇正文（块文档）写成正文 Markdown。
AiDiaryMarkdown aiDiaryMarkdown(
  Map<String, Object?> document,
  AppLocalizations l10n,
) {
  final marks = AiDiaryMarks(l10n);
  // 图片编号：正文顺序去重的来源，与 AiVisionImages.sourcesOf 同一口径。
  final photoNumbers = <String, int>{};
  for (final media in diaryBlocksMedia(document)) {
    final path = media.path;
    if (media.kind == DiaryBlockMediaKind.image && path != null) {
      photoNumbers.putIfAbsent(path, () => photoNumbers.length + 1);
    }
  }
  final counters = <String, int>{};
  String embed(String kind, [String? info]) {
    final number = (counters[kind] ?? 0) + 1;
    counters[kind] = number;
    return marks.embed(kind, number, info);
  }

  String? markOf(Map<String, Object?> node) {
    final type = node[kDiaryBlockTypeKey];
    if (type is String &&
        (kDiaryTextBlockTypes.contains(type) ||
            type == kDiaryBlockDivider ||
            type == kDiaryBlockTable)) {
      return null;
    }
    final data = diaryBlockData(node);
    final photos = [
      for (final media in diaryNodeMedia(node))
        if (media.kind == DiaryBlockMediaKind.image)
          if (photoNumbers[media.path] case final number?) marks.photo(number),
    ];
    if (photos.isNotEmpty) return photos.join(' ');
    return switch (type) {
      kDiaryBlockVideo => embed('video'),
      kDiaryBlockAudio => embed(
        'audio',
        DiaryAudioAttachment.tryDecode(data)?.name,
      ),
      kDiaryBlockAttachment => embed(
        'file',
        DiaryFileAttachment.tryDecode(data)?.name,
      ),
      kDiaryBlockLinkCard => embed(
        'link',
        data[kDiaryLinkCardTitleKey] as String?,
      ),
      kDiaryBlockMindMap => embed('mindmap', _mindMapSummary(data)),
      _ => embed('other'),
    };
  }

  final rows = <AiDiaryMarkdownRow>[];
  void visit(List<Map<String, Object?>> nodes, int depth) {
    var number = 0;
    for (final node in nodes) {
      final type = node[kDiaryBlockTypeKey];
      number = type == kDiaryBlockNumberedList ? number + 1 : 0;
      final mark = markOf(node);
      rows.add(
        AiDiaryMarkdownRow(
          node: node,
          depth: depth,
          text: mark != null
              ? '${'  ' * depth}$mark'
              : aiTemplateBlockLines(
                  _renderable(node),
                  depth: depth,
                  number: number,
                ).join('\n'),
          mark: mark,
        ),
      );
      // 格子是表格的结构，不另成行。
      if (type == kDiaryBlockTable) continue;
      visit(diaryBlockChildren(node), depth + 1);
    }
  }

  final root = diaryBlocksRoot(document);
  if (root != null) visit(diaryBlockChildren(root), 0);
  if (rows.isEmpty) {
    rows.add(
      const AiDiaryMarkdownRow(
        node: <String, Object?>{
          kDiaryBlockTypeKey: kDiaryBlockParagraph,
          kDiaryBlockDataKey: <String, Object?>{
            kDiaryBlockDeltaKey: <Object?>[],
          },
        },
        depth: 0,
        text: '',
      ),
    );
  }
  return AiDiaryMarkdown._(rows, marks);
}

/// 发给智能体的一篇日记的正文：正文 Markdown（没有块文档原文时为纯文本）。
String aiDiaryMarkdownText(AppLocalizations l10n, AiContextDiary diary) {
  final content = diary.contentJson;
  if (content == null) return diary.contentText;
  return aiDiaryMarkdown(
    aiDiaryDocument(content, diary.contentText),
    l10n,
  ).text;
}

/// 智能体读写的那份正文：存储原文解码成块文档。原文是空的、纯文本镜像却
/// 有字时（异常数据）按镜像建文档，读到的与改的都是用户看得到的那些字。
Map<String, Object?> aiDiaryDocument(String content, String contentText) =>
    content.trim().isEmpty && contentText.trim().isNotEmpty
    ? diaryBlocksFromPlainText(contentText)
    : decodeStoredDiaryBlocks(content);

/// 导图标记里的说明：各主题的文字以“ / ”相连，过长时截断。
String _mindMapSummary(Map<String, Object?> data) {
  final text = mindMapBlockPlainText(
    data,
  ).split('\n').where((line) => line.trim().isNotEmpty).join(' / ');
  return text.length > 400 ? '${text.substring(0, 400)}…' : text;
}

/// 写出前整理一个块（只用于写出，保留下来的仍是原来的块）：文字块（代码块
/// 除外）与表格格子里的换行换成空格，不是字符串的链接地址去掉，不是 1–6
/// 的标题级别收进范围（都是异常数据，写法里写不出）。不需要整理时原样返回。
Map<String, Object?> _renderable(Map<String, Object?> node) {
  final type = node[kDiaryBlockTypeKey];
  if (type == kDiaryBlockTable) {
    final cells = diaryBlockChildren(node);
    final odd = cells.any(
      (cell) => diaryBlockChildren(
        cell,
      ).any((paragraph) => !identical(_renderable(paragraph), paragraph)),
    );
    if (!odd) return node;
    return <String, Object?>{
      ...node,
      kDiaryBlockChildrenKey: [
        for (final cell in cells)
          <String, Object?>{
            ...cell,
            kDiaryBlockChildrenKey: [
              for (final paragraph in diaryBlockChildren(cell))
                _renderable(paragraph),
            ],
          },
      ],
    };
  }
  if (type is! String || !kDiaryTextBlockTypes.contains(type)) return node;
  final data = diaryBlockData(node);
  final level = data[kDiaryBlockLevelKey];
  final badLevel = level != null && (level is! num || level < 1 || level > 6);
  final delta = diaryBlockDelta(node);
  bool odd(Map<String, Object?> op) =>
      (type != kDiaryBlockCode && (op['insert']! as String).contains('\n')) ||
      (op['attributes'] is Map &&
          (op['attributes']! as Map)[kDiaryInlineHref] != null &&
          (op['attributes']! as Map)[kDiaryInlineHref] is! String);
  if (!badLevel && !delta.any(odd)) return node;
  return <String, Object?>{
    ...node,
    kDiaryBlockDataKey: <String, Object?>{
      ...data,
      if (badLevel)
        kDiaryBlockLevelKey: level is num ? level.clamp(1, 6).toInt() : 1,
      kDiaryBlockDeltaKey: [
        for (final op in delta)
          if (!odd(op))
            op
          else
            <String, Object?>{
              'insert': type == kDiaryBlockCode
                  ? op['insert']
                  : (op['insert']! as String).replaceAll('\n', ' '),
              if (op['attributes'] case final Map attributes)
                'attributes': <String, Object?>{
                  for (final entry in attributes.entries)
                    if (entry.key != kDiaryInlineHref || entry.value is String)
                      '${entry.key}': entry.value,
                },
            },
      ],
    },
  };
}
