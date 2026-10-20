import 'dart:convert';
import 'dart:ui' show Color;

import '../models/diary_code_block/diary_code_theme.dart';
import '../models/diary_text_colors.dart';
import 'diary_export_blocks.dart';
import 'diary_export_book.dart';
import 'diary_export_code.dart';
import 'diary_export_entry.dart';
import 'diary_export_format.dart';
import 'diary_export_media.dart';

/// Word（.docx）写出器：不依赖第三方库，直接生成 WordprocessingML 包。
///
/// 结构：每篇日记以“标题 + 日期行 + 信息行 + 标签行”开头，第二篇起另起
/// 一页；正文块映射为段落样式（标题、引用、代码），列表用带悬挂缩进的
/// 前缀符号（Word 的自动编号需要额外的 numbering 部件，前缀在任何编辑器
/// 里都显示一致）；图片按原比例缩放到版心宽度内嵌入，Word 不支持的格式
/// （WebP、HEIC）写成一行“[图片]”。给了代码配色（[DiaryExportCodeTheme]）
/// 时代码段落的底色与正文字色取纸面配色，记号按角色写成带颜色的 run。
///
/// 产物是交给控制器打包的文件列表（容器扩展名 `.docx`）：图片按原文件
/// 流式写入，识别尺寸只读文件头，导出几百张照片也不会整份读进内存。
///
/// 导出成书（`book` 不为 null）时：第一页是扉页（封面、书名、简介、统计行与
/// 导出日期），另起一页是目录（章节与“日期  标题”，点按经书签跳到对应
/// 位置；不写页码——Word 的页码要靠目录域在打开后更新，生成时给不出真实
/// 值），每章另起一页、以大纲 1 级的章节标题开头，每篇标题降到大纲 2 级，
/// 正文标题的大纲级别随之顺延（字号不变），Word 的导航窗格按章、篇、小标题
/// 分层。普通导出的样式表与正文保持原样。
///
/// 注意：Word 严格校验 `w:pPr` / `w:rPr` 子元素的顺序，顺序错了会提示
/// “无法读取的内容”，下面拼接属性时都按 schema 顺序写出。
class DiaryDocxWriter {
  const DiaryDocxWriter._();

  /// A4 纸、四边 2.54cm 页边距时的版心宽度（EMU）；图片最大高度留出页眉。
  static const int _maxImageWidthEmu = 5731510;
  static const int _maxImageHeightEmu = 7315200;

  /// 扉页封面的最大高度（约 11.4cm），书名与统计行留在同一页。
  static const int _maxCoverHeightEmu = 4114800;

  /// 按 96 DPI 把像素换算成 EMU（1 英寸 = 914400 EMU）。
  static const int _emuPerPixel = 9525;

  static Future<DiaryExportOutput> write(
    List<DiaryExportEntry> entries, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required String documentTitle,
    required String languageTag,
    List<String> fontFamilies = const <String>[],
    DateTime? now,
    DiaryExportBookLayout? book,
    DiaryExportCodeTheme? code,
  }) async {
    final builder = _DocxBuilder();
    if (book != null) {
      await _writeBook(
        builder,
        book,
        options: options,
        labels: labels,
        media: media,
        code: code,
      );
    } else {
      for (var i = 0; i < entries.length; i++) {
        await _writeEntry(
          builder,
          entries[i],
          pageBreakBefore: i > 0,
          options: options,
          labels: labels,
          media: media,
          code: code,
        );
      }
    }
    DiaryExportBundleFile text(String path, String content) =>
        DiaryExportBundleFile.bytes(path, utf8.encode(content));
    return DiaryExportOutput.bundle(
      <DiaryExportBundleFile>[
        // [Content_Types].xml 放在最前：部分读取器只按顺序查找它。
        text('[Content_Types].xml', _contentTypes),
        text('_rels/.rels', _packageRels),
        text(
          'docProps/core.xml',
          _coreProps(documentTitle, now ?? DateTime.now()),
        ),
        text('docProps/app.xml', _appProps),
        text(
          'word/styles.xml',
          _styles(
            languageTag,
            fontFamilies: fontFamilies,
            book: book == null
                ? null
                : (chapterHeadings: book.hasChapterHeadings),
            code: code?.paper,
          ),
        ),
        text('word/document.xml', builder.document()),
        text('word/_rels/document.xml.rels', builder.relationships()),
        for (final image in builder.images)
          image.media.file != null
              ? DiaryExportBundleFile.file(
                  'word/media/${image.name}',
                  image.media.file!,
                )
              : DiaryExportBundleFile.bytes(
                  'word/media/${image.name}',
                  image.media.bytes!,
                ),
      ],
      containerExtension: DiaryExportFormat.word.extension,
      containerMimeType: DiaryExportFormat.word.mimeType,
    );
  }

  static Future<void> _writeBook(
    _DocxBuilder b,
    DiaryExportBookLayout book, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    DiaryExportCodeTheme? code,
  }) async {
    final hasCover =
        options.includeMedia &&
        book.coverPath != null &&
        await _image(
          b,
          book.coverPath!,
          media,
          maxHeightEmu: _maxCoverHeightEmu,
        );
    if (!hasCover) {
      // 没有封面时书名往下放，扉页不至于头重脚轻。
      b.paragraph(style: 'BookSpacer', runs: const <String>[]);
    }
    b.paragraph(style: 'BookTitle', runs: <String>[b.run(book.title)]);
    if (book.description != null) {
      b.paragraph(
        style: 'BookDescription',
        runs: <String>[b.run(book.description!)],
      );
    }
    for (final line in <String>[book.summaryLine, book.exportedLine]) {
      if (line.isNotEmpty) {
        b.paragraph(style: 'BookMeta', runs: <String>[b.run(line)]);
      }
    }

    b.paragraph(
      style: 'TocHeading',
      pageBreakBefore: true,
      runs: <String>[b.run(book.contentsTitle)],
    );
    final chapters = book.hasChapterHeadings;
    for (final section in book.sections) {
      if (section.title != null) {
        b.paragraph(
          style: 'TocChapter',
          runs: <String>[
            b.internalLink(_bookmark(section.anchor), b.run(section.title!)),
          ],
        );
      }
      for (final entry in section.entries) {
        final line =
            '${labels.formatDate(entry.createdAt.toLocal())}\t'
            '${labels.titleOf(entry)}';
        b.paragraph(
          style: 'TocEntry',
          indentTwips: chapters ? 420 : null,
          runs: <String>[
            b.internalLink(_bookmark(book.anchorOf(entry)), b.run(line)),
          ],
        );
      }
    }

    for (final section in book.sections) {
      final title = section.title;
      if (title != null) {
        b.paragraph(
          style: 'BookChapter',
          pageBreakBefore: true,
          bookmark: _bookmark(section.anchor),
          runs: <String>[b.run(title)],
        );
      }
      for (var i = 0; i < section.entries.length; i++) {
        final entry = section.entries[i];
        await _writeEntry(
          b,
          entry,
          // 章节标题后的第一篇与标题同页；其余每篇照常另起一页。
          pageBreakBefore: title == null || i > 0,
          options: options,
          labels: labels,
          media: media,
          code: code,
          titleStyle: 'BookEntry',
          bookmark: _bookmark(book.anchorOf(entry)),
        );
      }
    }
  }

  /// Word 书签名只能含字母、数字与下划线。
  static String _bookmark(String anchor) => anchor.replaceAll('-', '_');

  /// 内嵌一张图片；不带图片、找不到或 Word 不支持的格式（WebP）返回 false。
  static Future<bool> _image(
    _DocxBuilder b,
    String source,
    DiaryExportMediaLibrary media, {
    int maxHeightEmu = _maxImageHeightEmu,
  }) async {
    final file = await media.resolve(source);
    final info = file == null ? null : await media.imageInfoOf(source);
    if (file == null || info == null || info.mimeType == 'image/webp') {
      return false;
    }
    b.imageParagraph(file, info, maxHeightEmu: maxHeightEmu);
    return true;
  }

  static Future<void> _writeEntry(
    _DocxBuilder b,
    DiaryExportEntry entry, {
    required bool pageBreakBefore,
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    DiaryExportCodeTheme? code,
    String titleStyle = 'Title',
    String? bookmark,
  }) async {
    b.paragraph(
      style: titleStyle,
      pageBreakBefore: pageBreakBefore,
      bookmark: bookmark,
      runs: <String>[b.run(labels.titleOf(entry))],
    );
    b.paragraph(
      style: 'DiaryMeta',
      runs: <String>[b.run(labels.formatDateTime(entry.createdAt.toLocal()))],
    );
    if (options.includeMeta) {
      final meta = labels.metaLine(entry);
      if (meta.isNotEmpty) {
        b.paragraph(style: 'DiaryMeta', runs: <String>[b.run(meta)]);
      }
      if (entry.tagNames.isNotEmpty) {
        b.paragraph(
          style: 'DiaryMeta',
          runs: <String>[
            b.run(entry.tagNames.map((String t) => '#$t').join('  ')),
          ],
        );
      }
    }

    Future<bool> image(String source) async =>
        options.includeMedia && await _image(b, source, media);

    if (entry.cover != null) {
      await image(entry.cover!);
    }
    final codeRuns = code?.highlightBlocks(entry.blocks);
    for (final (index, block) in entry.blocks.indexed) {
      switch (block.kind) {
        case ExportBlockKind.image:
          if (block.source == entry.cover) {
            break;
          }
          if (!await image(block.source!) && options.includeMedia) {
            b.paragraph(
              style: 'DiaryMeta',
              runs: <String>[b.run(labels.mediaLine(block))],
            );
          }
        case ExportBlockKind.media:
          b.paragraph(
            style: 'DiaryMeta',
            runs: <String>[b.run(labels.mediaLine(block))],
          );
        case ExportBlockKind.divider:
          b.paragraph(style: 'Divider', runs: const <String>[]);
        case ExportBlockKind.heading:
          b.paragraph(
            style: 'Heading${block.level.clamp(1, 3)}',
            align: block.align,
            runs: b.inlines(block.inlines),
          );
        case ExportBlockKind.quote:
          b.paragraph(style: 'Quote', runs: b.inlines(block.inlines));
        case ExportBlockKind.code:
          final runs = codeRuns?[index];
          b.paragraph(
            style: 'CodeBlock',
            runs: runs == null
                ? <String>[b.run(block.plainText)]
                : <String>[
                    for (final run in runs)
                      b.run(
                        run.text,
                        italic: code!.italicFor(run.role),
                        // 无角色的文字用 CodeBlock 样式里的正文字色。
                        color: run.role == null
                            ? null
                            : _hex(code.paper.tokens[run.role]!),
                      ),
                  ],
          );
        case ExportBlockKind.bullet ||
            ExportBlockKind.ordered ||
            ExportBlockKind.checked ||
            ExportBlockKind.unchecked:
          final marker = switch (block.kind) {
            ExportBlockKind.ordered => '${block.ordinal}.',
            ExportBlockKind.checked => '☑',
            ExportBlockKind.unchecked => '☐',
            _ => '•',
          };
          b.paragraph(
            indentTwips: 420 * (block.indent + 1),
            hangingTwips: 420,
            runs: <String>[b.run('$marker\t'), ...b.inlines(block.inlines)],
          );
        case ExportBlockKind.paragraph:
          b.paragraph(
            align: block.align,
            indentTwips: block.indent > 0 ? 420 * block.indent : null,
            runs: b.inlines(block.inlines),
          );
      }
    }
  }

  static String _coreProps(String title, DateTime now) {
    final stamp = '${now.toUtc().toIso8601String().split('.').first}Z';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>${_xml(title)}</dc:title><dc:creator>Jotsy</dc:creator>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$stamp</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">$stamp</dcterms:modified>'
        '</cp:coreProperties>';
  }

  static const String _appProps =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
      '<Application>Jotsy</Application></Properties>';

  static const String _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="png" ContentType="image/png"/>'
      '<Default Extension="jpeg" ContentType="image/jpeg"/>'
      '<Default Extension="gif" ContentType="image/gif"/>'
      '<Default Extension="bmp" ContentType="image/bmp"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
      '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
      '</Types>';

  static const String _packageRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
      '</Relationships>';

  /// 样式表：正文默认 11pt、1.5 倍行距；中文字体交给系统（东亚字体留空
  /// 时 Word 按语言选择默认中文字体，Windows 与 macOS 都能正常显示）。
  ///
  /// 用户选了导入字体时（[fontFamilies] 不为空）默认字体的西文与东亚槽位都
  /// 写它的第一个字族名（英文名优先，跨平台最容易匹配），整份文档跟随；复杂
  /// 文种（阿拉伯文等）槽位留给 Word 默认字体，导入字体多半没有这些字形；
  /// 代码样式仍是 Consolas。字体文件不嵌入，没装这款字体的设备由 Word 换用
  /// 默认字体。
  ///
  /// 成书时（[book] 不为 null）另加扉页、目录、章节与篇标题的样式，正文
  /// 标题的大纲级别顺延到章、篇之下（有章节标题时顺延两级，否则一级）。
  ///
  /// 给了代码配色 [code] 时，代码段落的底色与正文字色取它；没给时为浅灰底、
  /// 默认字色。
  static String _styles(
    String languageTag, {
    required List<String> fontFamilies,
    ({bool chapterHeadings})? book,
    DiaryCodePalette? code,
  }) {
    final font = fontFamilies.isEmpty ? null : _xml(fontFamilies.first);
    final entryLevel = book == null ? 0 : (book.chapterHeadings ? 1 : 0);
    final shift = book == null ? 0 : entryLevel + 1;
    final codeFill = code == null ? 'F1F3F4' : _hex(code.background);
    // 与底色同色的边框只用来留内边距：相邻代码段落的边框相同，Word 把它们
    // 合成一个框，整块代码四周留白，文字不贴着底色边缘。CT_PPr 顺序：
    // pBdr → shd → spacing。
    String codeEdge(String side, int space) =>
        '<w:$side w:val="single" w:sz="4" w:space="$space" w:color="$codeFill"/>';
    final codeBorder =
        '<w:pBdr>${codeEdge('top', 4)}${codeEdge('left', 6)}'
        '${codeEdge('bottom', 4)}${codeEdge('right', 6)}</w:pBdr>';
    // CT_RPr 顺序：rFonts → color → sz。
    final codeColor = code == null
        ? ''
        : '<w:color w:val="${_hex(code.foreground)}"/>';
    String style(
      String id,
      String name, {
      String type = 'paragraph',
      String pPr = '',
      String rPr = '',
      bool basedOnNormal = true,
    }) =>
        '<w:style w:type="$type" w:styleId="$id"><w:name w:val="$name"/>'
        '${type == 'paragraph' && basedOnNormal ? '<w:basedOn w:val="Normal"/>' : ''}'
        '<w:qFormat/>'
        '${pPr.isEmpty ? '' : '<w:pPr>$pPr</w:pPr>'}'
        '${rPr.isEmpty ? '' : '<w:rPr>$rPr</w:rPr>'}</w:style>';

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults><w:rPrDefault><w:rPr>'
        // w:rFonts 必须是 w:rPr 的第一个子元素。
        '${font == null ? '' : '<w:rFonts w:ascii="$font" w:eastAsia="$font" w:hAnsi="$font"/>'}'
        '<w:sz w:val="22"/><w:szCs w:val="22"/>'
        '<w:lang w:val="${_xml(languageTag)}" w:eastAsia="${_xml(languageTag)}"/></w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="360" w:lineRule="auto"/></w:pPr></w:pPrDefault>'
        '</w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
        '${style('Title', 'Title', pPr: '<w:keepNext/><w:spacing w:after="60"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="40"/><w:szCs w:val="40"/>')}'
        '${style('DiaryMeta', 'Diary Meta', pPr: '<w:spacing w:after="60"/>', rPr: '<w:color w:val="6B7280"/><w:sz w:val="20"/><w:szCs w:val="20"/>')}'
        '${style('Heading1', 'heading 1', pPr: '<w:keepNext/><w:spacing w:before="240" w:after="120"/><w:outlineLvl w:val="${0 + shift}"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="32"/><w:szCs w:val="32"/>')}'
        '${style('Heading2', 'heading 2', pPr: '<w:keepNext/><w:spacing w:before="200" w:after="100"/><w:outlineLvl w:val="${1 + shift}"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="28"/><w:szCs w:val="28"/>')}'
        '${style('Heading3', 'heading 3', pPr: '<w:keepNext/><w:spacing w:before="160" w:after="80"/><w:outlineLvl w:val="${2 + shift}"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="24"/><w:szCs w:val="24"/>')}'
        '${style('Quote', 'Quote', pPr: '<w:pBdr><w:left w:val="single" w:sz="18" w:space="8" w:color="C7CCD1"/></w:pBdr><w:ind w:left="360"/>', rPr: '<w:i/><w:iCs/><w:color w:val="5F6368"/>')}'
        '${style('Divider', 'Divider', pPr: '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="C7CCD1"/></w:pBdr>')}'
        '${style('CodeBlock', 'Code Block', pPr: '$codeBorder<w:shd w:val="clear" w:color="auto" w:fill="$codeFill"/><w:spacing w:after="0" w:line="276" w:lineRule="auto"/>', rPr: '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>$codeColor<w:sz w:val="20"/><w:szCs w:val="20"/>')}'
        '${style('InlineCode', 'Inline Code', type: 'character', rPr: '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/><w:shd w:val="clear" w:color="auto" w:fill="F1F3F4"/>')}'
        '${style('Hyperlink', 'Hyperlink', type: 'character', rPr: '<w:color w:val="1E6586"/><w:u w:val="single"/>')}'
        '${book == null ? '' : _bookStyles(style, entryLevel: entryLevel)}'
        '</w:styles>';
  }

  static String _bookStyles(
    String Function(String id, String name, {String pPr, String rPr}) style, {
    required int entryLevel,
  }) {
    return '${style('BookSpacer', 'Book Spacer', pPr: '<w:spacing w:before="2400" w:after="0"/>')}'
        '${style('BookTitle', 'Book Title', pPr: '<w:spacing w:before="480" w:after="240"/><w:jc w:val="center"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="56"/><w:szCs w:val="56"/>')}'
        '${style('BookDescription', 'Book Description', pPr: '<w:spacing w:after="240"/><w:jc w:val="center"/>', rPr: '<w:color w:val="5F6368"/><w:sz w:val="24"/><w:szCs w:val="24"/>')}'
        '${style('BookMeta', 'Book Meta', pPr: '<w:spacing w:after="60"/><w:jc w:val="center"/>', rPr: '<w:color w:val="6B7280"/><w:sz w:val="20"/><w:szCs w:val="20"/>')}'
        '${style('TocHeading', 'Book Contents Heading', pPr: '<w:keepNext/><w:spacing w:after="240"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="36"/><w:szCs w:val="36"/>')}'
        '${style('TocChapter', 'Book Contents Chapter', pPr: '<w:keepNext/><w:spacing w:before="120" w:after="60"/>', rPr: '<w:b/><w:bCs/>')}'
        '${style('TocEntry', 'Book Contents Entry', pPr: '<w:tabs><w:tab w:val="left" w:pos="2400"/></w:tabs><w:spacing w:after="40"/>')}'
        '${style('BookChapter', 'Book Chapter', pPr: '<w:keepNext/><w:spacing w:before="1200" w:after="480"/><w:outlineLvl w:val="0"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="52"/><w:szCs w:val="52"/>')}'
        '${style('BookEntry', 'Book Entry', pPr: '<w:keepNext/><w:spacing w:after="60"/><w:outlineLvl w:val="$entryLevel"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="40"/><w:szCs w:val="40"/>')}';
  }
}

/// 拼接 document.xml 与其关系文件；图片与链接按出现顺序分配关系 id。
class _DocxBuilder {
  final StringBuffer _body = StringBuffer();
  final List<String> _relationships = <String>[];
  final List<({String name, DiaryExportMediaFile media})> images =
      <({String name, DiaryExportMediaFile media})>[];
  final Map<String, String> _linkIds = <String, String>{};
  int _drawingId = 0;
  int _bookmarkId = 0;

  String _nextRelationshipId() => 'rId${_relationships.length + 2}';

  String run(
    String text, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strike = false,
    String? characterStyle,
    String? color,
  }) {
    final rPr = StringBuffer();
    // CT_RPr 顺序：rStyle → b → i → strike → color → u。
    if (characterStyle != null) {
      rPr.write('<w:rStyle w:val="$characterStyle"/>');
    }
    if (bold) rPr.write('<w:b/><w:bCs/>');
    if (italic) rPr.write('<w:i/><w:iCs/>');
    if (strike) rPr.write('<w:strike/>');
    if (color != null) rPr.write('<w:color w:val="$color"/>');
    if (underline) rPr.write('<w:u w:val="single"/>');
    final props = rPr.isEmpty ? '' : '<w:rPr>$rPr</w:rPr>';
    final parts = text.split('\t');
    final content = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) content.write('<w:tab/>');
      if (parts[i].isNotEmpty) {
        content.write('<w:t xml:space="preserve">${_xml(parts[i])}</w:t>');
      }
    }
    return '<w:r>$props$content</w:r>';
  }

  List<String> inlines(List<ExportInline> runs) {
    return <String>[
      for (final inline in runs)
        _withLink(
          inline.link,
          run(
            inline.text,
            bold: inline.bold,
            italic: inline.italic,
            underline: inline.underline && inline.link == null,
            strike: inline.strike,
            characterStyle: inline.link != null
                ? 'Hyperlink'
                : inline.code
                ? 'InlineCode'
                : null,
          ),
        ),
    ];
  }

  /// 文档内链接：跳到名为 [bookmark] 的书签（成书目录用）。
  String internalLink(String bookmark, String run) =>
      '<w:hyperlink w:anchor="${_xml(bookmark)}" w:history="1">$run</w:hyperlink>';

  String _withLink(String? link, String run) {
    final uri = link == null ? null : Uri.tryParse(link);
    if (uri == null || !uri.hasScheme) {
      return run;
    }
    final id = _linkIds[link!] ??= () {
      final id = _nextRelationshipId();
      _relationships.add(
        '<Relationship Id="$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" '
        'Target="${_xml(link)}" TargetMode="External"/>',
      );
      return id;
    }();
    return '<w:hyperlink r:id="$id">$run</w:hyperlink>';
  }

  void paragraph({
    required List<String> runs,
    String? style,
    bool pageBreakBefore = false,
    int? indentTwips,
    int? hangingTwips,
    ExportAlign align = ExportAlign.start,
    String? bookmark,
  }) {
    // CT_PPr 顺序：pStyle → pageBreakBefore → ind → jc。
    final pPr = StringBuffer();
    if (style != null) pPr.write('<w:pStyle w:val="$style"/>');
    if (pageBreakBefore) pPr.write('<w:pageBreakBefore/>');
    if (indentTwips != null) {
      pPr.write(
        '<w:ind w:left="$indentTwips"'
        '${hangingTwips == null ? '' : ' w:hanging="$hangingTwips"'}/>',
      );
    }
    final jc = switch (align) {
      ExportAlign.center => 'center',
      ExportAlign.end => 'right',
      ExportAlign.justify => 'both',
      ExportAlign.start => null,
    };
    if (jc != null) pPr.write('<w:jc w:val="$jc"/>');
    final props = pPr.isEmpty ? '' : '<w:pPr>$pPr</w:pPr>';
    if (bookmark == null) {
      _body.write('<w:p>$props${runs.join()}</w:p>');
      return;
    }
    // 书签包住整段文字：目录链接跳到这一段的开头。
    final id = _bookmarkId++;
    _body.write(
      '<w:p>$props<w:bookmarkStart w:id="$id" w:name="${_xml(bookmark)}"/>'
      '${runs.join()}<w:bookmarkEnd w:id="$id"/></w:p>',
    );
  }

  void imageParagraph(
    DiaryExportMediaFile media,
    ExportImageInfo info, {
    int maxHeightEmu = DiaryDocxWriter._maxImageHeightEmu,
  }) {
    final id = _nextRelationshipId();
    final name =
        'image${images.length + 1}${info.extension == '.jpg' ? '.jpeg' : info.extension}';
    images.add((name: name, media: media));
    _relationships.add(
      '<Relationship Id="$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
      'Target="media/$name"/>',
    );
    var cx = info.width * DiaryDocxWriter._emuPerPixel;
    var cy = info.height * DiaryDocxWriter._emuPerPixel;
    final scale = <double>[
      1,
      DiaryDocxWriter._maxImageWidthEmu / cx,
      maxHeightEmu / cy,
    ].reduce((a, b) => a < b ? a : b);
    cx = (cx * scale).round();
    cy = (cy * scale).round();
    final drawing = ++_drawingId;
    _body.write(
      '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:drawing>'
      '<wp:inline distT="0" distB="0" distL="0" distR="0">'
      '<wp:extent cx="$cx" cy="$cy"/>'
      '<wp:docPr id="$drawing" name="Picture $drawing"/>'
      '<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>'
      '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<pic:pic><pic:nvPicPr><pic:cNvPr id="$drawing" name="$name"/><pic:cNvPicPr/></pic:nvPicPr>'
      '<pic:blipFill><a:blip r:embed="$id"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
      '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
      '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>',
    );
  }

  String document() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<w:body>$_body'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" '
      'w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>'
      '</w:body></w:document>';

  String relationships() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '${_relationships.join()}</Relationships>';
}

/// Word 的颜色值：不带 `#` 的 `RRGGBB`。
String _hex(Color color) => diaryColorRgbHex(color).substring(1);

/// XML 文本转义，并去掉 XML 1.0 不允许的控制字符（正文里偶见的 \u0000
/// 之类会让 Word 拒绝打开整个文件）。
String _xml(String value) => value
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\uFFFE\uFFFF]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
