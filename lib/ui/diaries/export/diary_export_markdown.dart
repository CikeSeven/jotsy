import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../../core/database/code_block_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import 'diary_export_blocks.dart';
import 'diary_export_book.dart';
import 'diary_export_entry.dart';
import 'diary_export_format.dart';
import 'diary_export_media.dart';
import 'diary_export_naming.dart';

/// Markdown 写出器：每篇一个 `.md`，媒体放进 `media/` 并以相对路径引用。
///
/// 输出：只有一篇且没有媒体时为单个 `.md`；否则为需要打包的文件列表
/// （各篇 `.md` + `media/`）。每篇开头是 YAML front matter（title / created /
/// updated / tags / location 等），Jotsy 与 Obsidian 的 Markdown 导入都认这些
/// 字段；标题只写在 front matter 里，正文不再重复一级标题，避免导回后
/// 正文开头多出一行标题。
///
/// 正文按块写出：每个文本行一段（段间空一行，保留原来的分行），列表、
/// 待办、引用、代码块用标准语法；找不到的图片直接略过，未打包的录音、
/// 视频、附件写成一行名称。标注写成以图标开头的引用（`> 💡 文字`），折叠
/// 列表展开写成 `▸ 标题` 加照常跟在后面的子块，表格写成 GFM 管道表格，
/// 上下标写成 `<sup>` / `<sub>`；字号与对齐没有 Markdown 写法，略过。
///
/// 导出成书（[write] 的 `book` 不为 null）时全书写进一个 `<书名>.md`（有
/// 媒体时同样打包 `media/`）：开头是扉页（`# 书名`、封面、简介、统计行与
/// 导出日期）与 `## 目录`（链接到各章、各篇的锚点），每章 `# 章节名`，每篇
/// `## 标题` 后接日期与信息行，正文标题顺延两级（最深到 `######`）。锚点写成
/// 标题里的 `<a id="…"></a>`：CommonMark 不给标题自动生成稳定的 id（中文与
/// 重名标题尤其不可靠），显式锚点在 GitHub、Typora 等渲染 HTML 的阅读器里
/// 都能跳转。成书不再写每篇的 YAML front matter（一个文件只能有一份），
/// 需要按篇导回 Jotsy 时关掉“书籍结构”。
///
/// 有留言时每篇正文之后是留言区（[_renderComments]）：标题比日记标题低一级
/// （单篇 `##`、成书 `###`），每条留言一个列表项。
class DiaryMarkdownWriter {
  const DiaryMarkdownWriter._();

  static const String mediaDirectory = 'media';

  static Future<DiaryExportOutput> write(
    List<DiaryExportEntry> entries, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    DiaryExportBookLayout? book,
    String documentStem = 'Jotsy',
  }) async {
    // 先确定要打包的媒体与包内路径，正文再按来源取路径。
    final mediaPaths = <String, String>{};
    final mediaFiles = <DiaryExportBundleFile>[];
    final takenNames = <String>{};

    Future<void> collect(String source, {required bool isImage}) async {
      if (mediaPaths.containsKey(source)) {
        return;
      }
      // 录音、视频、附件的远程地址保留为链接，不下载进导出包。
      final file = await media.resolve(source, allowDownload: isImage);
      if (file == null) {
        return;
      }
      final index = (mediaPaths.length + 1).toString().padLeft(4, '0');
      final original = DiaryExportNaming.sanitize(
        p.basenameWithoutExtension(file.file?.path ?? ''),
        maxLength: 32,
      );
      final name = DiaryExportNaming.unique(
        takenNames,
        isImage || original.isEmpty
            ? '$index${file.extension}'
            : '${index}_$original${file.extension}',
      );
      final path = '$mediaDirectory/$name';
      mediaPaths[source] = path;
      mediaFiles.add(
        file.file != null
            ? DiaryExportBundleFile.file(path, file.file!)
            : DiaryExportBundleFile.bytes(path, file.bytes!),
      );
    }

    if (options.includeMedia) {
      if (book?.coverPath != null) {
        await collect(book!.coverPath!, isImage: true);
      }
      for (final entry in entries) {
        final images = entry.imageSources;
        for (final source in <String>[...images, ...entry.attachmentSources]) {
          await collect(source, isImage: images.contains(source));
        }
      }
    }

    if (book != null) {
      final text = renderBook(
        book,
        includeMeta: options.includeMeta,
        labels: labels,
        mediaPathOf: (String source) => mediaPaths[source],
      );
      final bytes = utf8.encode(text);
      if (mediaFiles.isEmpty) {
        return DiaryExportOutput.single(bytes);
      }
      return DiaryExportOutput.bundle(<DiaryExportBundleFile>[
        DiaryExportBundleFile.bytes('$documentStem.md', bytes),
        ...mediaFiles,
      ]);
    }

    final documents = <DiaryExportBundleFile>[];
    final takenDocs = <String>{};
    for (final entry in entries) {
      final text = renderEntry(
        entry,
        includeMeta: options.includeMeta,
        labels: labels,
        mediaPathOf: (String source) => mediaPaths[source],
      );
      final name = DiaryExportNaming.unique(
        takenDocs,
        '${DiaryExportNaming.entryStem(entry)}.md',
      );
      documents.add(DiaryExportBundleFile.bytes(name, utf8.encode(text)));
    }
    if (documents.length == 1 && mediaFiles.isEmpty) {
      return DiaryExportOutput.single(documents.single.bytes!);
    }
    return DiaryExportOutput.bundle(<DiaryExportBundleFile>[
      ...documents,
      ...mediaFiles,
    ]);
  }

  /// 单篇 Markdown 文本；[mediaPathOf] 返回已打包媒体的相对路径。
  static String renderEntry(
    DiaryExportEntry entry, {
    required bool includeMeta,
    required DiaryExportLabels labels,
    required String? Function(String source) mediaPathOf,
  }) {
    final out = StringBuffer()
      ..writeln('---')
      ..writeln('title: ${_yaml(labels.titleOf(entry))}')
      ..writeln('created: ${_iso(entry.createdAt)}')
      ..writeln('updated: ${_iso(entry.updatedAt)}');
    if (includeMeta) {
      final context = entry.context;
      if (entry.tagNames.isNotEmpty) {
        out.writeln('tags: [${entry.tagNames.map(_yaml).join(', ')}]');
      }
      if (context.moodEmoji != null) {
        out.writeln('mood: ${_yaml(context.moodEmoji!)}');
      }
      if (context.energyLevel != null) {
        out.writeln('energy: ${context.energyLevel}');
      }
      if (context.weather != null) {
        out.writeln('weather: ${_yaml(context.weather!)}');
      }
      if (context.location != null) {
        out.writeln('location: ${_yaml(context.location!)}');
      }
    }
    out.writeln('---');

    final body = <String>[];
    final cover = entry.cover == null ? null : mediaPathOf(entry.cover!);
    if (cover != null) {
      body.add('![](${_destination(cover)})');
    }
    body.addAll(_renderBlocks(entry, labels: labels, mediaPathOf: mediaPathOf));
    // 单篇的标题只在 front matter 里，相当于一级，留言区用二级。
    body.addAll(_renderComments(entry, labels: labels, level: 2));
    if (body.isNotEmpty) {
      out
        ..writeln()
        ..writeln(body.join('\n\n'));
    }
    return out.toString();
  }

  /// 成书的整份 Markdown（见类注释）；[mediaPathOf] 返回已打包媒体的相对路径。
  static String renderBook(
    DiaryExportBookLayout book, {
    required bool includeMeta,
    required DiaryExportLabels labels,
    required String? Function(String source) mediaPathOf,
  }) {
    final sections = <String>['# ${_escape(book.title)}'];
    final cover = book.coverPath == null ? null : mediaPathOf(book.coverPath!);
    if (cover != null) {
      sections.add('![](${_destination(cover)})');
    }
    for (final line in <String?>[
      book.description,
      book.summaryLine,
      book.exportedLine,
    ]) {
      if (line != null && line.isNotEmpty) {
        sections.add(_escapeLineStart(_escape(line)));
      }
    }

    final contents = <String>[];
    final indent = book.hasChapterHeadings ? '    ' : '';
    for (final section in book.sections) {
      if (section.title != null) {
        contents.add('- [${_escape(section.title!)}](#${section.anchor})');
      }
      for (final entry in section.entries) {
        final label =
            '${labels.formatDate(entry.createdAt.toLocal())}  '
            '${labels.titleOf(entry)}';
        contents.add('$indent- [${_escape(label)}](#${book.anchorOf(entry)})');
      }
    }
    sections
      ..add('## ${_escape(book.contentsTitle)}')
      ..add(contents.join('\n'));

    for (final section in book.sections) {
      if (section.title != null) {
        sections.add(
          '# <a id="${section.anchor}"></a>${_escape(section.title!)}',
        );
      }
      for (final entry in section.entries) {
        sections.add(
          '## <a id="${book.anchorOf(entry)}"></a>'
          '${_escape(labels.titleOf(entry))}',
        );
        final meta = <String>[
          labels.formatDateTime(entry.createdAt.toLocal()),
          if (includeMeta) labels.metaLine(entry),
        ].where((String line) => line.isNotEmpty).join(' · ');
        sections.add(_escapeLineStart(_escape(meta)));
        if (includeMeta && entry.tagNames.isNotEmpty) {
          // `#标签` 后面没有空格，不会被当成标题；Obsidian 等会认作标签。
          sections.add(entry.tagNames.map((t) => '#${_escape(t)}').join(' '));
        }
        final entryCover = entry.cover == null
            ? null
            : mediaPathOf(entry.cover!);
        if (entryCover != null) {
          sections.add('![](${_destination(entryCover)})');
        }
        sections.addAll(
          _renderBlocks(
            entry,
            labels: labels,
            mediaPathOf: mediaPathOf,
            headingOffset: 2,
          ),
        );
        sections.addAll(_renderComments(entry, labels: labels, level: 3));
      }
    }
    return '${sections.join('\n\n')}\n';
  }

  /// 留言区：[level] 级标题 + 每条留言一个列表项。说明行（斜体）在前，
  /// 心情与文字随后；留言里的每一行各成一段（与正文的分行写法一致，不靠
  /// 行尾空格或反斜杠换行，各种阅读器都显示为分开的行）。没有留言时为空。
  static List<String> _renderComments(
    DiaryExportEntry entry, {
    required DiaryExportLabels labels,
    required int level,
  }) {
    if (entry.comments.isEmpty) {
      return const <String>[];
    }
    final items = <String>[
      for (final comment in entry.comments)
        <String>[
          '- *${_escape(labels.commentMetaLine(entry, comment))}*',
          for (final line in labels.commentText(comment).split('\n'))
            if (line.trim().isNotEmpty)
              // 续行缩进两格，仍属于这一项。
              '  ${_escapeLineStart(_escape(line.trimRight()))}',
        ].join('\n\n'),
    ];
    return <String>[
      '${'#' * level} ${_escape(labels.commentsHeading)}',
      items.join('\n\n'),
    ];
  }

  /// 每组相邻的同类块（列表、引用、代码）合成一段，段与段之间空一行。
  /// [headingOffset] 为成书时正文标题顺延的级数（最深到六级）。
  static List<String> _renderBlocks(
    DiaryExportEntry entry, {
    required DiaryExportLabels labels,
    required String? Function(String source) mediaPathOf,
    int headingOffset = 0,
  }) {
    final sections = <String>[];
    final group = <String>[];
    String? groupKind;
    // 代码组的语言：相邻代码行只在语言相同时并成一个围栏，语言不同的
    // 两段各写一个围栏，保留各自的语言标记。
    String? groupLanguage;

    void flush() {
      if (group.isEmpty) {
        return;
      }
      sections.add(
        groupKind == 'code'
            ? _codeFence(group.join('\n'), groupLanguage)
            : group.join('\n'),
      );
      group.clear();
      groupKind = null;
      groupLanguage = null;
    }

    void addTo(String kind, String line, {String? language}) {
      if (groupKind != kind || groupLanguage != language) {
        flush();
        groupKind = kind;
        groupLanguage = language;
      }
      group.add(line);
    }

    for (final block in entry.blocks) {
      switch (block.kind) {
        case ExportBlockKind.paragraph:
          flush();
          final text = _inlines(block.inlines);
          // 空行只用来分段，段间本就空一行，不再额外写出。
          if (text.trim().isNotEmpty) {
            sections.add(_escapeLineStart(text));
          }
        case ExportBlockKind.callout:
          // 标注写成以图标开头的引用；相邻的两个标注各成一段（中间空一
          // 行），不并成一个引用。
          flush();
          final icon = block.calloutIcon ?? kDiaryCalloutDefaultIcon;
          sections.add('> $icon ${_inlines(block.inlines)}'.trimRight());
        case ExportBlockKind.toggle:
          // Markdown 没有折叠写法（`<details>` 里的 Markdown 多数阅读器不
          // 解析）：导出时一律展开，标题前加 `▸ `，子块照常跟在后面。
          flush();
          sections.add('▸ ${_inlines(block.inlines)}'.trimRight());
        case ExportBlockKind.table:
          flush();
          sections.add(_table(block));
        case ExportBlockKind.heading:
          flush();
          final level = (block.level + headingOffset).clamp(1, 6);
          sections.add('${'#' * level} ${_inlines(block.inlines)}');
        case ExportBlockKind.bullet ||
            ExportBlockKind.ordered ||
            ExportBlockKind.checked ||
            ExportBlockKind.unchecked:
          final marker = switch (block.kind) {
            ExportBlockKind.ordered => '${block.ordinal}.',
            ExportBlockKind.checked => '- [x]',
            ExportBlockKind.unchecked => '- [ ]',
            _ => '-',
          };
          addTo(
            'list',
            '${'    ' * block.indent}$marker ${_inlines(block.inlines)}',
          );
        case ExportBlockKind.quote:
          addTo('quote', '> ${_inlines(block.inlines)}');
        case ExportBlockKind.code:
          addTo('code', block.plainText, language: block.codeLanguage);
        case ExportBlockKind.image:
          flush();
          if (block.source == entry.cover) {
            break;
          }
          final path = mediaPathOf(block.source!);
          if (path != null) {
            sections.add('![](${_destination(path)})');
          } else if (_isRemote(block.source!)) {
            sections.add('![](${_destination(block.source!)})');
          }
        case ExportBlockKind.divider:
          flush();
          sections.add('---');
        case ExportBlockKind.media:
          flush();
          final path = mediaPathOf(block.source!);
          final label = labels.mediaLine(block);
          sections.add(
            path != null
                ? '[${_escape(label)}](${_destination(path)})'
                : _isRemote(block.source!)
                ? '[${_escape(label)}](${_destination(block.source!)})'
                : _escape(label),
          );
      }
    }
    flush();
    return sections;
  }

  static String _inlines(List<ExportInline> runs) {
    final out = StringBuffer();
    for (final run in runs) {
      if (run.code) {
        out.write(_code(run.text));
        continue;
      }
      var text = _escape(run.text);
      // 标记必须贴着文字，首尾空白移到标记外，否则 `** 粗体**` 不生效。
      final leading = RegExp(r'^\s*').stringMatch(text)!;
      final trailing = RegExp(
        r'\s*$',
      ).stringMatch(text.substring(leading.length))!;
      var core = text.substring(leading.length, text.length - trailing.length);
      if (core.isNotEmpty) {
        if (run.bold) core = '**$core**';
        if (run.italic) core = '*$core*';
        if (run.strike) core = '~~$core~~';
        if (run.underline) core = '<u>$core</u>';
        // 上下标没有 Markdown 写法，用 HTML 标签（主流阅读器都认）。
        core = switch (run.script) {
          ExportScript.superscript => '<sup>$core</sup>',
          ExportScript.subscript => '<sub>$core</sub>',
          null => core,
        };
        if (run.link != null) core = '[$core](${_destination(run.link!)})';
      }
      text = '$leading$core$trailing';
      out.write(text);
    }
    return out.toString();
  }

  /// GFM 管道表格。没有表头行时先写一行空表头，否则第一行数据会被当成
  /// 表头加粗；格子里的 `|` 写成 `\|`（GFM 先按 `|` 切格，行内代码里也要
  /// 转义），一格里的几段以 `<br>` 相连（表格行不能真的换行）。
  static String _table(ExportBlock block) {
    String cell(List<ExportInline> runs) => <String>[
      for (final paragraph in ExportBlock.tableCellParagraphs(runs))
        _inlines(paragraph).trim(),
    ].join('<br>').replaceAll('|', r'\|');
    String row(Iterable<String> cells) => '| ${cells.join(' | ')} |';

    final rows = <List<String>>[
      for (final cells in block.tableRows)
        <String>[for (final runs in cells) cell(runs)],
    ];
    final columns = rows.isEmpty ? 0 : rows.first.length;
    final header = block.tableHeaderRow && rows.isNotEmpty
        ? rows.removeAt(0)
        : List<String>.filled(columns, '');
    return <String>[
      row(header),
      row(List<String>.filled(columns, '---')),
      for (final cells in rows) row(cells),
    ].join('\n');
  }

  /// 围栏代码块：信息串为语言 id，纯文本写 `text`，未指定不写；围栏长度
  /// 取代码里最长的连续反引号 + 1（至少三个），代码含 ``` 时也不会提前闭合。
  static String _codeFence(String code, String? language) {
    var longest = 0;
    for (final match in RegExp('`+').allMatches(code)) {
      final length = match.end - match.start;
      if (length > longest) {
        longest = length;
      }
    }
    final fence = '`' * (longest + 1 < 3 ? 3 : longest + 1);
    final info = switch (language) {
      null => '',
      kCodeBlockPlain => 'text',
      _ => language,
    };
    return '$fence$info\n$code\n$fence';
  }

  static String _code(String text) {
    final fence = text.contains('`') ? '``' : '`';
    return '$fence$text$fence';
  }

  /// 只转义会被误读为标记的字符，日期中的 `-`、句末的 `!` 保持原样。
  static String _escape(String text) =>
      text.replaceAllMapped(RegExp(r'[\\`*_\[\]<>]'), (m) => '\\${m[0]}');

  /// 行首的 `#`、`-`、`+`、`1.` 会被当成标题或列表。
  static String _escapeLineStart(String text) => text.replaceFirstMapped(
    RegExp(r'^(\s*)(#|[-+](?=\s)|\d+(?=[.)]\s))'),
    (m) => '${m[1]}\\${m[2]}',
  );

  /// 链接与图片地址：空格与括号会截断地址，统一编码。
  static String _destination(String path) =>
      Uri.encodeFull(path).replaceAll('(', '%28').replaceAll(')', '%29');

  static bool _isRemote(String source) =>
      source.startsWith('http://') || source.startsWith('https://');

  static String _yaml(String value) =>
      '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  /// 本地时间的 ISO 8601（不带时区），导入端按本地时间理解。
  static String _iso(DateTime value) =>
      value.toLocal().toIso8601String().split('.').first;
}
