import 'dart:convert';
import 'dart:ui' show Color;

import '../../../core/database/code_block_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../models/diary_callout_tone.dart';
import '../models/diary_code_block/diary_code_theme.dart';
import '../models/diary_text_colors.dart';
import 'diary_export_blocks.dart';
import 'diary_export_book.dart';
import 'diary_export_code.dart';
import 'diary_export_entry.dart';
import 'diary_export_format.dart';
import 'diary_export_media.dart';

/// HTML 写出器：所有日记写进一个网页。
///
/// - 单篇：图片以 data URI 内嵌，单个文件在手机浏览器里也能直接打开；
/// - 多篇且带图片：打包成 `index.html` + `media/`，图片按原文件流式写入，
///   批量导出几百张照片也不会整份读进内存（base64 还会再胀大三分之一）。
/// 录音、视频、附件写成一行名称（体积大，不适合内嵌）。只收浏览器能
/// 显示的图片格式（读文件头识别），HEIC 等略过。样式内联，跟随系统亮色 /
/// 暗色；正文标题从 h2 起，h1 留给日记标题。
///
/// 导出成书（`book` 不为 null）时，页面开头是扉页（封面、书名、简介、统计行
/// 与导出日期）与目录 `<nav>`（章节与各篇链接到锚点），每章是带
/// `<h1 id="chapter-n">` 的 `<section>`，每篇 `<article id="entry-n">` 的标题
/// 降为 h2、正文标题顺延到 h3 起；打印时扉页、目录与每章各自另起一页。封面
/// 与日记图片走同一条媒体链路（单篇内嵌、多篇打包），不写设备路径。
///
/// 给了代码配色（[DiaryExportCodeTheme]）且正文里有代码块时，记号写成
/// `<span class="hl-角色">`，颜色是 CSS 变量：浅色模式用纸面配色，深色模式
/// 换成深色那套（固定明暗时只有一套）；代码块的底色与正文字色同样取配色。
///
/// 正文的文字色与背景色写成内联 `style`，按原值带透明度写出：半透明背景
/// 叠在卡片上，与应用里叠在纸面上一样；亮暗模式都不换色，也与应用一致。
/// 代码里设过文字色的片段保留原色、不取记号色。
///
/// 有留言的日记在正文之后多一个 `<section class="comments">`（见
/// [_writeComments]），样式只在有留言时写出。
///
/// 标注写成 `<div class="callout callout-档位">`（图标 + 正文），折叠列表写成
/// 默认展开的 `<details open>`（后面缩进更深的块都收进去），表格写成
/// `<table>`（首行为表头时放进 `<thead>`），上下标写成 `<sup>` / `<sub>`，
/// 行内字号写成以 em 计的 `font-size`；这几样块的样式（[_blocksCss]）只在
/// 正文里有标注、折叠列表或表格时写出。
class DiaryHtmlWriter {
  const DiaryHtmlWriter._();

  static const String bundledPageName = 'index.html';

  static Future<DiaryExportOutput> write(
    List<DiaryExportEntry> entries, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required String documentTitle,
    required String languageTag,
    List<String> fontFamilies = const <String>[],
    DiaryExportBookLayout? book,
    DiaryExportCodeTheme? code,
  }) async {
    final bundle = entries.length > 1;
    // 没有代码块时不写高亮样式，页面与原来一样。
    final codeTheme =
        code != null &&
            entries.any(
              (DiaryExportEntry entry) => entry.blocks.any(
                (ExportBlock block) => block.kind == ExportBlockKind.code,
              ),
            )
        ? code
        : null;
    // 没有标注、折叠列表与表格时不写它们的样式。
    final hasRichBlocks = entries.any(
      (DiaryExportEntry entry) => entry.blocks.any(
        (ExportBlock block) =>
            block.kind == ExportBlockKind.callout ||
            block.kind == ExportBlockKind.toggle ||
            block.kind == ExportBlockKind.table,
      ),
    );
    // 同理，没有留言时不写留言区样式。
    final hasComments = entries.any(
      (DiaryExportEntry entry) => entry.comments.isNotEmpty,
    );
    // 来源 → img 的 src（data URI，或打包时的相对路径）。
    final images = <String, String>{};
    final mediaFiles = <DiaryExportBundleFile>[];

    Future<void> collect(String source) async {
      if (images.containsKey(source)) {
        return;
      }
      final file = await media.resolve(source);
      // 读不出格式（如 HEIC）的图片浏览器多半也显示不了，略过。
      final info = file == null ? null : await media.imageInfoOf(source);
      if (file == null || info == null) {
        return;
      }
      if (bundle) {
        final index = (mediaFiles.length + 1).toString().padLeft(4, '0');
        final path = 'media/$index${info.extension}';
        images[source] = path;
        mediaFiles.add(
          file.file != null
              ? DiaryExportBundleFile.file(path, file.file!)
              : DiaryExportBundleFile.bytes(path, file.bytes!),
        );
      } else {
        final bytes = await media.bytesOf(source);
        if (bytes != null) {
          images[source] =
              'data:${info.mimeType};base64,${base64Encode(bytes)}';
        }
      }
    }

    if (options.includeMedia) {
      if (book?.coverPath != null) {
        await collect(book!.coverPath!);
      }
      for (final entry in entries) {
        for (final source in entry.imageSources) {
          await collect(source);
        }
      }
    }

    final out = StringBuffer()
      ..write('<!DOCTYPE html>\n<html lang="${_attr(languageTag)}">\n<head>\n')
      ..write('<meta charset="utf-8">\n')
      ..write(
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n',
      )
      ..write('<meta name="generator" content="Jotsy">\n')
      ..write('<title>${_text(documentTitle)}</title>\n')
      ..write(
        '<style>$_css${codeTheme == null ? '' : _codeCss(codeTheme)}'
        '${_fontCss(fontFamilies)}'
        '${book == null ? '' : _bookCss}'
        '${hasRichBlocks ? _blocksCss() : ''}'
        '${hasComments ? _commentsCss : ''}</style>\n',
      )
      ..write('</head>\n<body>\n<main>\n');
    if (book != null) {
      _writeBook(
        out,
        book,
        options: options,
        labels: labels,
        images: images,
        code: codeTheme,
      );
    } else {
      for (final entry in entries) {
        _writeEntry(
          out,
          entry,
          options: options,
          labels: labels,
          images: images,
          code: codeTheme,
        );
      }
    }
    out
      ..write('<footer>${_text(labels.exportedBy)}</footer>\n')
      ..write('</main>\n</body>\n</html>\n');
    final page = utf8.encode(out.toString());
    if (mediaFiles.isEmpty) {
      return DiaryExportOutput.single(page);
    }
    return DiaryExportOutput.bundle(<DiaryExportBundleFile>[
      DiaryExportBundleFile.bytes(bundledPageName, page),
      ...mediaFiles,
    ]);
  }

  static void _writeBook(
    StringBuffer out,
    DiaryExportBookLayout book, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required Map<String, String> images,
    DiaryExportCodeTheme? code,
  }) {
    out.write('<section class="book-title">\n');
    final cover = book.coverPath == null ? null : images[book.coverPath!];
    if (cover != null) {
      out.write(
        '<figure class="book-cover"><img src="${_attr(cover)}" alt=""></figure>\n',
      );
    }
    out.write('<h1>${_text(book.title)}</h1>\n');
    if (book.description != null) {
      out.write(
        '<p class="book-description">${_text(book.description!)}</p>\n',
      );
    }
    if (book.summaryLine.isNotEmpty) {
      out.write('<p class="meta">${_text(book.summaryLine)}</p>\n');
    }
    out
      ..write('<p class="meta">${_text(book.exportedLine)}</p>\n')
      ..write('</section>\n')
      ..write('<nav class="toc">\n<h2>${_text(book.contentsTitle)}</h2>\n');

    void writeEntryLinks(List<DiaryExportEntry> entries) {
      out.write('<ol class="toc-entries">');
      for (final entry in entries) {
        final created = entry.createdAt.toLocal();
        out.write(
          '<li><a href="#${book.anchorOf(entry)}">'
          '<time datetime="${_attr(created.toIso8601String())}">'
          '${_text(labels.formatDate(created))}</time> '
          '${_text(labels.titleOf(entry))}</a></li>',
        );
      }
      out.write('</ol>\n');
    }

    if (book.hasChapterHeadings) {
      out.write('<ol class="toc-chapters">\n');
      for (final section in book.sections) {
        out.write(
          '<li><a href="#${section.anchor}">${_text(section.title!)}</a>',
        );
        writeEntryLinks(section.entries);
        out.write('</li>\n');
      }
      out.write('</ol>\n');
    } else {
      for (final section in book.sections) {
        writeEntryLinks(section.entries);
      }
    }
    out.write('</nav>\n');

    for (final section in book.sections) {
      final title = section.title;
      out.write('<section class="chapter">\n');
      if (title != null) {
        out.write(
          '<h1 class="chapter-title" id="${section.anchor}">'
          '${_text(title)}</h1>\n',
        );
      }
      for (final entry in section.entries) {
        _writeEntry(
          out,
          entry,
          options: options,
          labels: labels,
          images: images,
          code: code,
          anchor: book.anchorOf(entry),
          titleLevel: 2,
        );
      }
      out.write('</section>\n');
    }
  }

  /// 一篇日记；成书时带锚点 [anchor]，标题降为 h[titleLevel]，正文标题顺延。
  static void _writeEntry(
    StringBuffer out,
    DiaryExportEntry entry, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required Map<String, String> images,
    DiaryExportCodeTheme? code,
    String? anchor,
    int titleLevel = 1,
  }) {
    out
      ..write(anchor == null ? '<article>\n' : '<article id="$anchor">\n')
      ..write('<header>\n')
      ..write('<h$titleLevel>${_text(labels.titleOf(entry))}</h$titleLevel>\n')
      ..write(
        '<p class="meta"><time datetime="${_attr(entry.createdAt.toLocal().toIso8601String())}">'
        '${_text(labels.formatDateTime(entry.createdAt.toLocal()))}</time></p>\n',
      );
    if (options.includeMeta) {
      final meta = labels.metaLine(entry);
      if (meta.isNotEmpty) {
        out.write('<p class="meta">${_text(meta)}</p>\n');
      }
      if (entry.tagNames.isNotEmpty) {
        out.write('<ul class="tags">');
        for (final tag in entry.tagNames) {
          out.write('<li>#${_text(tag)}</li>');
        }
        out.write('</ul>\n');
      }
    }
    out.write('</header>\n');
    final cover = entry.cover == null ? null : images[entry.cover!];
    if (cover != null) {
      out.write(
        '<figure class="cover"><img src="${_attr(cover)}" alt=""></figure>\n',
      );
    }
    _writeBlocks(
      out,
      entry,
      labels: labels,
      images: images,
      code: code,
      headingOffset: titleLevel,
    );
    _writeComments(out, entry, labels: labels, level: titleLevel + 1);
    out.write('</article>\n');
  }

  /// 留言区（没有留言时不写）：标题比日记标题低一级，每条留言为一行说明
  /// 加心情与文字；文字按原样换行（`pre-wrap`），不必把换行改写成 `<br>`。
  static void _writeComments(
    StringBuffer out,
    DiaryExportEntry entry, {
    required DiaryExportLabels labels,
    required int level,
  }) {
    if (entry.comments.isEmpty) {
      return;
    }
    out.write(
      '<section class="comments">\n'
      '<h$level>${_text(labels.commentsHeading)}</h$level>\n',
    );
    for (final comment in entry.comments) {
      out.write(
        '<div class="comment">'
        '<p class="meta">${_text(labels.commentMetaLine(entry, comment))}</p>'
        '<p class="comment-text">${_text(labels.commentText(comment))}</p>'
        '</div>\n',
      );
    }
    out.write('</section>\n');
  }

  /// [headingOffset] 是日记标题的级别：正文标题从下一级起。超过 h6 的
  /// 级别（成书时正文标题顺延）仍写 `<h6>`，但带 `h-level-N` 类名与
  /// `aria-level`，样式上比真正的 h6 再弱一级，不与它混成同一级。
  static void _writeBlocks(
    StringBuffer out,
    DiaryExportEntry entry, {
    required DiaryExportLabels labels,
    required Map<String, String> images,
    DiaryExportCodeTheme? code,
    int headingOffset = 1,
  }) {
    _writeRange(
      out,
      entry,
      0,
      entry.blocks.length,
      labels: labels,
      images: images,
      codeRuns: code?.highlightBlocks(entry.blocks),
      headingOffset: headingOffset,
    );
  }

  /// 写出 `entry.blocks[start, end)`。折叠列表把它后面缩进更深的块（它的
  /// 子块）收进自己的 `<details>`，递归写出；列表、引用与代码的分组不越过
  /// [end]，不会从折叠列表里跑出去。[codeRuns] 按整篇的下标给出。
  static void _writeRange(
    StringBuffer out,
    DiaryExportEntry entry,
    int start,
    int end, {
    required DiaryExportLabels labels,
    required Map<String, String> images,
    required List<List<DiaryExportCodeRun>?>? codeRuns,
    required int headingOffset,
  }) {
    final blocks = entry.blocks;
    var i = start;
    while (i < end) {
      final block = blocks[i];
      if (block.isListItem) {
        final next = _runEnd(blocks, i, end, (ExportBlock b) => b.isListItem);
        _writeList(out, blocks.sublist(i, next));
        i = next;
        continue;
      }
      if (block.kind == ExportBlockKind.quote) {
        final next = _runEnd(
          blocks,
          i,
          end,
          (ExportBlock b) => b.kind == ExportBlockKind.quote,
        );
        out.write('<blockquote>');
        for (final line in blocks.sublist(i, next)) {
          out.write('<p${_align(line)}>${_inlines(line.inlines)}</p>');
        }
        out.write('</blockquote>\n');
        i = next;
        continue;
      }
      if (block.kind == ExportBlockKind.code) {
        final next = _runEnd(
          blocks,
          i,
          end,
          // 语言不同的相邻代码行各成一个 <pre>，保留各自的语言 class。
          (ExportBlock b) =>
              b.kind == ExportBlockKind.code &&
              b.codeLanguage == block.codeLanguage,
        );
        // highlightBlocks 与这里按同样的口径（语言相同的相邻代码行）分块着色。
        final html = <String>[
          for (var j = i; j < next; j++)
            codeRuns == null
                ? _text(blocks[j].plainText)
                : codeRuns[j]!.map(_codeRun).join(),
        ].join('\n');
        // 沿用 highlight.js / Prism 的 `language-*` 约定；纯文本写
        // `language-plaintext`，未指定不写 class（交给阅读端自动识别）。
        final language = switch (block.codeLanguage) {
          null => null,
          kCodeBlockPlain => 'plaintext',
          final id => id,
        };
        final classAttr = language == null ? '' : ' class="language-$language"';
        out.write('<pre><code$classAttr>$html</code></pre>\n');
        i = next;
        continue;
      }
      if (block.kind == ExportBlockKind.toggle) {
        // 导出的页面不保存折叠状态：一律展开，读者仍可点标题收起。
        final close = _runEnd(
          blocks,
          i + 1,
          end,
          (ExportBlock b) => b.indent > block.indent,
        );
        out.write(
          '<details open><summary${_align(block)}>'
          '${_inlines(block.inlines)}</summary>\n',
        );
        _writeRange(
          out,
          entry,
          i + 1,
          close,
          labels: labels,
          images: images,
          codeRuns: codeRuns,
          headingOffset: headingOffset,
        );
        out.write('</details>\n');
        i = close;
        continue;
      }
      switch (block.kind) {
        case ExportBlockKind.heading:
          final level = block.level + headingOffset;
          final html = _inlines(block.inlines);
          out.write(
            level <= 6
                ? '<h$level${_align(block)}>$html</h$level>\n'
                : '<h6 class="h-level-$level" aria-level="$level"'
                      '${_align(block)}>$html</h6>\n',
          );
        case ExportBlockKind.image:
          final data = images[block.source!];
          if (data != null && block.source != entry.cover) {
            out.write(
              '<figure><img src="${_attr(data)}" alt="" loading="lazy"></figure>\n',
            );
          }
        case ExportBlockKind.media:
          out.write(
            '<p class="attachment">${_text(labels.mediaLine(block))}</p>\n',
          );
        case ExportBlockKind.divider:
          out.write('<hr>\n');
        case ExportBlockKind.callout:
          final tone = DiaryCalloutTone.fromId(block.calloutTone);
          out.write(
            '<div class="callout callout-${tone.id}">'
            '<span class="callout-icon">'
            '${_text(block.calloutIcon ?? kDiaryCalloutDefaultIcon)}</span>'
            '<div class="callout-body"${_align(block)}>'
            '${_inlines(block.inlines)}</div></div>\n',
          );
        case ExportBlockKind.table:
          _writeTable(out, block);
        default:
          final html = _inlines(block.inlines);
          out.write(
            html.trim().isEmpty
                ? '<p class="blank"></p>\n'
                : '<p${_align(block)}>$html</p>\n',
          );
      }
      i++;
    }
  }

  /// 表格铺满内容宽度；首行为表头时放进 `<thead>`、用 `<th>`。一格里的
  /// 几段以 `<br>` 相连。
  static void _writeTable(StringBuffer out, ExportBlock block) {
    String cell(String tag, List<ExportInline> runs) {
      final paragraphs = ExportBlock.tableCellParagraphs(runs).map(_inlines);
      return '<$tag>${paragraphs.join('<br>')}</$tag>';
    }

    String row(String tag, List<List<ExportInline>> cells) =>
        '<tr>${cells.map((List<ExportInline> runs) => cell(tag, runs)).join()}</tr>';

    final rows = block.tableRows;
    final header = block.tableHeaderRow && rows.isNotEmpty;
    out.write('<table>');
    if (header) {
      out.write('<thead>${row('th', rows.first)}</thead>');
    }
    out.write('<tbody>');
    for (final cells in rows.skip(header ? 1 : 0)) {
      out.write(row('td', cells));
    }
    out.write('</tbody></table>\n');
  }

  static int _runEnd(
    List<ExportBlock> blocks,
    int start,
    int limit,
    bool Function(ExportBlock block) test,
  ) {
    var end = start;
    while (end < limit && test(blocks[end])) {
      end++;
    }
    return end;
  }

  /// 把一段连续的列表项写成嵌套的 ul / ol：缩进加深时在上一项里开子列表，
  /// 回退时关闭；同一层级换了列表类型（有序 ↔ 无序 / 待办）时另起一个列表。
  static void _writeList(StringBuffer out, List<ExportBlock> items) {
    final stack = <({String tag, int indent})>[];
    var itemOpen = false;
    String tagOf(ExportBlock b) =>
        b.kind == ExportBlockKind.ordered ? 'ol' : 'ul';

    for (final item in items) {
      final tag = tagOf(item);
      while (stack.isNotEmpty && stack.last.indent > item.indent) {
        out.write('</li></${stack.removeLast().tag}>');
        itemOpen = true;
      }
      if (stack.isNotEmpty &&
          stack.last.indent == item.indent &&
          stack.last.tag != tag) {
        out.write('</li></${stack.removeLast().tag}>');
        itemOpen = false;
      }
      if (stack.isEmpty || stack.last.indent < item.indent) {
        final start = item.kind == ExportBlockKind.ordered && item.ordinal > 1
            ? ' start="${item.ordinal}"'
            : '';
        out.write('<$tag$start>');
        stack.add((tag: tag, indent: item.indent));
      } else if (itemOpen) {
        out.write('</li>');
      }
      final task = switch (item.kind) {
        ExportBlockKind.checked =>
          ' class="task"><input type="checkbox" disabled checked',
        ExportBlockKind.unchecked =>
          ' class="task"><input type="checkbox" disabled',
        _ => null,
      };
      // 列表样式按项写类名（见 _css 的 li.ls-*）：无序项与待办共用一个 ul，
      // 一个 ul 里可能有几段样式不同的列表。
      final styleId = item.orderedStyle?.id ?? item.bulletStyle?.id;
      out.write(
        task == null
            ? '<li${styleId == null ? '' : ' class="ls-$styleId"'}'
                  '${_align(item)}>${_inlines(item.inlines)}'
            : '<li$task${_align(item)}> ${_inlines(item.inlines)}',
      );
      itemOpen = true;
    }
    while (stack.isNotEmpty) {
      out.write('</li></${stack.removeLast().tag}>');
    }
    out.write('\n');
  }

  static String _align(ExportBlock block) => switch (block.align) {
    ExportAlign.center => ' style="text-align:center"',
    ExportAlign.end => ' style="text-align:right"',
    ExportAlign.justify => ' style="text-align:justify"',
    ExportAlign.start => '',
  };

  static String _inlines(List<ExportInline> runs) {
    final out = StringBuffer();
    for (final run in runs) {
      var html = _text(run.text);
      final colors = _colorStyle(run.color, run.background);
      // 颜色写在下划线 / 删除线外层，线与文字同色（与应用一致）；写在链接
      // 里层，盖过链接色。行内代码直接写在 <code> 上，否则代码自带的底色
      // 会盖住用户的背景色。
      if (run.code) {
        html = colors == null
            ? '<code>$html</code>'
            : '<code style="$colors">$html</code>';
      }
      if (run.bold) html = '<strong>$html</strong>';
      if (run.italic) html = '<em>$html</em>';
      if (run.underline) html = '<u>$html</u>';
      if (run.strike) html = '<s>$html</s>';
      // 字号以 em 计，跟着所在块（标题、表格）的字号缩放，与应用里相对
      // 正文的倍数一致；与颜色写在同一个 span 上。
      final scale = run.sizeScale;
      final style = <String>[
        if (colors != null && !run.code) colors,
        if (scale != null) 'font-size:${_em(scale)}',
      ].join(';');
      if (style.isNotEmpty) {
        html = '<span style="$style">$html</span>';
      }
      html = switch (run.script) {
        ExportScript.superscript => '<sup>$html</sup>',
        ExportScript.subscript => '<sub>$html</sub>',
        null => html,
      };
      final link = run.link;
      if (link != null && _isSafeLink(link)) {
        html = '<a href="${_attr(link)}">$html</a>';
      }
      out.write(html);
    }
    return out.toString();
  }

  /// 倍数写成 em，去掉多余的零（如 1.25em、1.5em、0.85em）。
  static String _em(double scale) =>
      '${scale.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}em';

  /// 只保留 http(s)、mailto、tel 链接：导出页可能在任意浏览器里打开，
  /// `javascript:` 之类的地址不能变成可点的链接。
  static bool _isSafeLink(String link) {
    final scheme = Uri.tryParse(link)?.scheme.toLowerCase();
    return scheme == 'http' ||
        scheme == 'https' ||
        scheme == 'mailto' ||
        scheme == 'tel';
  }

  /// 记号的 class 与用户颜色写在同一个 span 上：内联样式优先于 class，
  /// 设过文字色的片段保留原色，注释的斜体照旧。
  static String _codeRun(DiaryExportCodeRun run) {
    final role = run.role;
    final colors = _colorStyle(run.color, run.background);
    final text = _text(run.text);
    final attributes =
        '${role == null ? '' : ' class="hl-${role.name}"'}'
        '${colors == null ? '' : ' style="$colors"'}';
    return attributes.isEmpty ? text : '<span$attributes>$text</span>';
  }

  /// 文字色与背景色的内联样式；都没设时为 null。
  static String? _colorStyle(Color? color, Color? background) {
    if (color == null && background == null) {
      return null;
    }
    return <String>[
      if (color != null) 'color:${_cssColor(color)}',
      if (background != null) 'background-color:${_cssColor(background)}',
    ].join(';');
  }

  /// 不透明写 `#RRGGBB`，半透明写 `rgba()`（比 `#RRGGBBAA` 兼容更旧的
  /// 浏览器；Jotsy 导入网页时两种都认）。
  static String _cssColor(Color color) {
    final argb = color.toARGB32();
    final alpha = argb >>> 24;
    if (alpha == 0xFF) {
      return diaryColorRgbHex(color);
    }
    return 'rgba(${(argb >> 16) & 0xFF},${(argb >> 8) & 0xFF},${argb & 0xFF},'
        '${(alpha / 255).toStringAsFixed(3)})';
  }

  /// 代码高亮的样式：配色写成 CSS 变量，深色模式换成 [DiaryExportCodeTheme.night]
  /// （与纸面同一套时不写）；记号按角色的 class 取色，注释斜体。写在基础
  /// 样式之后，覆盖 `pre` 的默认底色。
  static String _codeCss(DiaryExportCodeTheme code) {
    String variables(DiaryCodePalette palette) => <String>[
      '--code-bg:${diaryColorRgbHex(palette.background)}',
      '--code-fg:${diaryColorRgbHex(palette.foreground)}',
      for (final role in DiaryCodeTokenRole.values)
        '--hl-${role.name}:${diaryColorRgbHex(palette.tokens[role]!)}',
    ].join(';');
    final out = StringBuffer(':root{${variables(code.paper)}}\n');
    if (!identical(code.night, code.paper)) {
      out.write(
        '@media (prefers-color-scheme:dark){:root{${variables(code.night)}}}\n',
      );
    }
    out.write('pre{background:var(--code-bg);color:var(--code-fg)}\n');
    for (final role in DiaryCodeTokenRole.values) {
      out.write('.hl-${role.name}{color:var(--hl-${role.name})}');
    }
    if (code.italicFor(DiaryCodeTokenRole.comment)) {
      out.write('.hl-comment{font-style:italic}');
    }
    return (out..write('\n')).toString();
  }

  /// 用户选了导入字体时把它的字族名排在字体栈最前（不内嵌字体文件：中文
  /// 字体动辄十几 MB），装有这款字体的设备按它显示，其余照旧。
  static String _fontCss(List<String> fontFamilies) {
    if (fontFamilies.isEmpty) {
      return '';
    }
    return 'body{font-family:${fontFamilies.map(_cssString).join(',')},'
        '$_fontStack}\n';
  }

  /// 写成 CSS 字符串。字族名来自用户导入的字体文件，引号、反斜杠、尖括号、
  /// `&` 与控制字符一律转成十六进制转义，不能借名称闭合 `<style>`。
  static String _cssString(String value) {
    final out = StringBuffer('"');
    for (final rune in value.runes) {
      if (rune < 0x20 || rune == 0x7F || '"\\<>&'.runes.contains(rune)) {
        out.write('\\${rune.toRadixString(16)} ');
      } else {
        out.writeCharCode(rune);
      }
    }
    return (out..write('"')).toString();
  }

  static String _text(String value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(value);

  static String _attr(String value) =>
      const HtmlEscape(HtmlEscapeMode.attribute).convert(value);

  static const String _fontStack =
      '-apple-system,BlinkMacSystemFont,"HarmonyOS Sans SC","PingFang SC",'
      '"Microsoft YaHei","Noto Sans CJK SC",sans-serif';

  static const String _css =
      '''
:root{color-scheme:light dark;--bg:#f6fafe;--card:#ffffff;--text:#1a1c1e;--muted:#5f6368;--line:#d9dee4;--accent:#1e6586;--chip:#e3f0f7}
@media (prefers-color-scheme:dark){:root{--bg:#111318;--card:#1a1c20;--text:#e3e2e6;--muted:#a8acb3;--line:#33373d;--accent:#8ccff1;--chip:#20323c}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:16px/1.75 $_fontStack}
main{max-width:760px;margin:0 auto;padding:24px 16px 48px}
article{background:var(--card);border:0.8px solid var(--line);border-radius:24px;padding:24px;margin:0 0 24px;overflow-wrap:anywhere}
article>header h1{margin:0 0 4px;font-size:24px;line-height:1.35}
.meta{margin:0;color:var(--muted);font-size:14px}
.tags{list-style:none;margin:8px 0 0;padding:0;display:flex;flex-wrap:wrap;gap:6px}
.tags li{background:var(--chip);color:var(--accent);border-radius:12px;padding:0 10px;font-size:13px;font-weight:600}
article>header{margin-bottom:16px}
p{margin:0}
p.blank{height:1em}
h2,h3,h4,h5,h6{margin:16px 0 4px;line-height:1.4}
h6.h-level-7{color:var(--muted)}
h6.h-level-8{color:var(--muted);font-weight:500}
figure{margin:12px 0}
hr{margin:16px 0;border:0;border-top:1px solid var(--line)}
img{display:block;max-width:100%;height:auto;border-radius:16px}
.cover img{width:100%}
blockquote{margin:8px 0;padding:4px 0 4px 14px;border-left:3px solid var(--line);color:var(--muted)}
pre{margin:8px 0;padding:12px 14px;background:var(--bg);border-radius:12px;overflow:auto;font-size:14px;line-height:1.6}
code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
p code,li code{background:var(--bg);border-radius:6px;padding:1px 5px}
ul,ol{margin:4px 0;padding-left:1.6em}
li.task{list-style:none;margin-left:-1.4em}
li.ls-decimal{list-style-type:decimal}
li.ls-paren{list-style-type:jotsy-paren}
li.ls-circled{list-style-type:jotsy-circled}
li.ls-cjk{list-style-type:simp-chinese-informal}
li.ls-lower-alpha{list-style-type:lower-alpha}
li.ls-upper-alpha{list-style-type:upper-alpha}
li.ls-lower-roman{list-style-type:lower-roman}
li.ls-upper-roman{list-style-type:upper-roman}
li.ls-disc{list-style-type:disc}
li.ls-circle{list-style-type:circle}
li.ls-square{list-style-type:square}
li.ls-diamond{list-style-type:"◆  "}
li.ls-star{list-style-type:"★  "}
li.ls-arrow{list-style-type:"→  "}
li.ls-dash{list-style-type:"–  "}
@counter-style jotsy-paren{system:extends decimal;prefix:"(";suffix:") "}
@counter-style jotsy-circled{system:fixed;symbols:"①" "②" "③" "④" "⑤" "⑥" "⑦" "⑧" "⑨" "⑩";suffix:" "}
a{color:var(--accent)}
.attachment{color:var(--muted);font-size:14px;margin:4px 0}
footer{color:var(--muted);font-size:12px;text-align:center}
@media print{body{background:#fff}article{border:none;padding:0;break-inside:auto;page-break-after:always}footer{display:none}}
''';

  /// 标注、折叠列表与表格的样式（只在正文里有这几种块时写出）。标注的
  /// 底色与色条取 [DiaryCalloutTone] 的纸面配色；深色模式下把强调色按
  /// [kDiaryCalloutDarkTint] 叠在卡片上（与应用的深色主题同一口径），浅色字
  /// 在上面仍然看得清。
  static String _blocksCss() {
    final light = StringBuffer();
    final dark = StringBuffer();
    for (final tone in DiaryCalloutTone.values) {
      light.write(
        '.callout-${tone.id}{background:${_cssColor(tone.paperBackground)};'
        'border-left-color:${_cssColor(tone.paperAccent)}}\n',
      );
      final tint = tone.darkAccent.withValues(alpha: kDiaryCalloutDarkTint);
      dark.write(
        '.callout-${tone.id}{background:${_cssColor(tint)};'
        'border-left-color:${_cssColor(tone.darkAccent)}}',
      );
    }
    return '.callout{display:flex;gap:10px;margin:8px 0;padding:10px 14px;'
        'border-left:3px solid;border-radius:6px}\n'
        '.callout-icon{flex:none}\n'
        '.callout-body{flex:1;min-width:0}\n'
        'details{margin:4px 0}\n'
        'details>summary{cursor:pointer}\n'
        'details>:not(summary){margin-left:1.4em}\n'
        'table{width:100%;border-collapse:collapse;margin:8px 0}\n'
        'th,td{border:1px solid var(--line);padding:6px 10px;'
        'text-align:start;vertical-align:top}\n'
        'th{background:var(--bg);font-weight:600}\n'
        'td code,th code{background:var(--bg);border-radius:6px;'
        'padding:1px 5px}\n'
        '$light@media (prefers-color-scheme:dark){$dark}\n';
  }

  /// 成书附加的样式（只在成书时写出，普通导出的页面保持原样）。
  static const String _bookCss = '''
.book-title{text-align:center;padding:48px 8px 56px}
.book-title h1{margin:0 0 12px;font-size:34px;line-height:1.3}
.book-cover{margin:0 auto 32px;max-width:420px}
.book-cover img{width:100%}
.book-description{margin:0 auto 16px;max-width:520px;color:var(--muted);font-size:17px}
.book-title .meta{margin:4px 0}
.toc{background:var(--card);border:0.8px solid var(--line);border-radius:24px;padding:24px;margin:0 0 32px}
.toc h2{margin:0 0 12px;font-size:22px}
.toc ol{list-style:none;margin:0;padding:0}
.toc-chapters>li{margin:0 0 12px;font-weight:600}
.toc-chapters .toc-entries{margin:4px 0 0 1.2em;font-weight:400}
.toc-entries li{margin:2px 0}
.toc a{text-decoration:none}
.toc time{color:var(--muted);font-size:14px;margin-right:6px}
.chapter-title{margin:40px 0 20px;font-size:30px;line-height:1.3}
article>header h2{margin:0 0 4px;font-size:24px;line-height:1.35}
@media print{.book-title,.toc{page-break-after:always}.toc{border:none;padding:0}.chapter{break-before:page}}
''';

  /// 留言区的样式（只在有留言时写出，没有留言的页面保持原样）：以一条
  /// 细线与正文隔开，标题与说明行用次要色，文字保留原来的换行。
  static const String _commentsCss = '''
.comments{margin-top:20px;padding-top:12px;border-top:1px solid var(--line)}
.comments>h2,.comments>h3{margin:0 0 8px;font-size:16px;line-height:1.4;color:var(--muted)}
.comment{margin:0 0 12px}
.comment:last-child{margin-bottom:0}
.comment-text{white-space:pre-wrap}
''';
}
