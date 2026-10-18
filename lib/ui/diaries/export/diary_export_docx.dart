import 'dart:convert';

import 'diary_export_blocks.dart';
import 'diary_export_entry.dart';
import 'diary_export_format.dart';
import 'diary_export_media.dart';

/// Word（.docx）写出器：不依赖第三方库，直接生成 WordprocessingML 包。
///
/// 结构：每篇日记以“标题 + 日期行 + 信息行 + 标签行”开头，第二篇起另起
/// 一页；正文块映射为段落样式（标题、引用、代码），列表用带悬挂缩进的
/// 前缀符号（Word 的自动编号需要额外的 numbering 部件，前缀在任何编辑器
/// 里都显示一致）；图片按原比例缩放到版心宽度内嵌入，Word 不支持的格式
/// （WebP、HEIC）写成一行“[图片]”。
///
/// 产物是交给控制器打包的文件列表（容器扩展名 `.docx`）：图片按原文件
/// 流式写入，识别尺寸只读文件头，导出几百张照片也不会整份读进内存。
///
/// 注意：Word 严格校验 `w:pPr` / `w:rPr` 子元素的顺序，顺序错了会提示
/// “无法读取的内容”，下面拼接属性时都按 schema 顺序写出。
class DiaryDocxWriter {
  const DiaryDocxWriter._();

  /// A4 纸、四边 2.54cm 页边距时的版心宽度（EMU）；图片最大高度留出页眉。
  static const int _maxImageWidthEmu = 5731510;
  static const int _maxImageHeightEmu = 7315200;

  /// 按 96 DPI 把像素换算成 EMU（1 英寸 = 914400 EMU）。
  static const int _emuPerPixel = 9525;

  static Future<DiaryExportOutput> write(
    List<DiaryExportEntry> entries, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required String documentTitle,
    required String languageTag,
    DateTime? now,
  }) async {
    final builder = _DocxBuilder();
    for (var i = 0; i < entries.length; i++) {
      await _writeEntry(
        builder,
        entries[i],
        pageBreakBefore: i > 0,
        options: options,
        labels: labels,
        media: media,
      );
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
        text('word/styles.xml', _styles(languageTag)),
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

  static Future<void> _writeEntry(
    _DocxBuilder b,
    DiaryExportEntry entry, {
    required bool pageBreakBefore,
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
  }) async {
    b.paragraph(
      style: 'Title',
      pageBreakBefore: pageBreakBefore,
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

    Future<bool> image(String source) async {
      if (!options.includeMedia) {
        return false;
      }
      final file = await media.resolve(source);
      final info = file == null ? null : await media.imageInfoOf(source);
      if (file == null || info == null || info.mimeType == 'image/webp') {
        return false;
      }
      b.imageParagraph(file, info);
      return true;
    }

    if (entry.cover != null) {
      await image(entry.cover!);
    }
    for (final block in entry.blocks) {
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
          b.paragraph(
            style: 'CodeBlock',
            runs: <String>[b.run(block.plainText)],
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
  static String _styles(String languageTag) {
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
        '<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/>'
        '<w:lang w:val="${_xml(languageTag)}" w:eastAsia="${_xml(languageTag)}"/></w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="360" w:lineRule="auto"/></w:pPr></w:pPrDefault>'
        '</w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
        '${style('Title', 'Title', pPr: '<w:keepNext/><w:spacing w:after="60"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="40"/><w:szCs w:val="40"/>')}'
        '${style('DiaryMeta', 'Diary Meta', pPr: '<w:spacing w:after="60"/>', rPr: '<w:color w:val="6B7280"/><w:sz w:val="20"/><w:szCs w:val="20"/>')}'
        '${style('Heading1', 'heading 1', pPr: '<w:keepNext/><w:spacing w:before="240" w:after="120"/><w:outlineLvl w:val="0"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="32"/><w:szCs w:val="32"/>')}'
        '${style('Heading2', 'heading 2', pPr: '<w:keepNext/><w:spacing w:before="200" w:after="100"/><w:outlineLvl w:val="1"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="28"/><w:szCs w:val="28"/>')}'
        '${style('Heading3', 'heading 3', pPr: '<w:keepNext/><w:spacing w:before="160" w:after="80"/><w:outlineLvl w:val="2"/>', rPr: '<w:b/><w:bCs/><w:sz w:val="24"/><w:szCs w:val="24"/>')}'
        '${style('Quote', 'Quote', pPr: '<w:pBdr><w:left w:val="single" w:sz="18" w:space="8" w:color="C7CCD1"/></w:pBdr><w:ind w:left="360"/>', rPr: '<w:i/><w:iCs/><w:color w:val="5F6368"/>')}'
        '${style('Divider', 'Divider', pPr: '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="C7CCD1"/></w:pBdr>')}'
        '${style('CodeBlock', 'Code Block', pPr: '<w:shd w:val="clear" w:color="auto" w:fill="F1F3F4"/><w:spacing w:after="0" w:line="276" w:lineRule="auto"/>', rPr: '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/><w:sz w:val="20"/><w:szCs w:val="20"/>')}'
        '${style('InlineCode', 'Inline Code', type: 'character', rPr: '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/><w:shd w:val="clear" w:color="auto" w:fill="F1F3F4"/>')}'
        '${style('Hyperlink', 'Hyperlink', type: 'character', rPr: '<w:color w:val="1E6586"/><w:u w:val="single"/>')}'
        '</w:styles>';
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

  String _nextRelationshipId() => 'rId${_relationships.length + 2}';

  String run(
    String text, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strike = false,
    String? characterStyle,
  }) {
    final rPr = StringBuffer();
    // CT_RPr 顺序：rStyle → b → i → strike → u。
    if (characterStyle != null) {
      rPr.write('<w:rStyle w:val="$characterStyle"/>');
    }
    if (bold) rPr.write('<w:b/><w:bCs/>');
    if (italic) rPr.write('<w:i/><w:iCs/>');
    if (strike) rPr.write('<w:strike/>');
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
    _body.write(
      '<w:p>${pPr.isEmpty ? '' : '<w:pPr>$pPr</w:pPr>'}${runs.join()}</w:p>',
    );
  }

  void imageParagraph(DiaryExportMediaFile media, ExportImageInfo info) {
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
      DiaryDocxWriter._maxImageHeightEmu / cy,
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

/// XML 文本转义，并去掉 XML 1.0 不允许的控制字符（正文里偶见的 \u0000
/// 之类会让 Word 拒绝打开整个文件）。
String _xml(String value) => value
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\uFFFE\uFFFF]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
