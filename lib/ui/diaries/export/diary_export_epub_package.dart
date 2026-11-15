import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'diary_export_html_markup.dart';

/// EPUB 3 包的骨架文件：`META-INF/container.xml`、包文档 `content.opf`、
/// 导航文档 `nav.xhtml`、给只认 EPUB 2 的旧阅读器的 `toc.ncx`，以及每个
/// 内容文件的 XHTML 外壳。纯字符串模板，无 IO；所有文字与属性都经
/// [DiaryHtmlMarkup.epub] 转义并去掉 XML 不允许的字符。
///
/// 路径约定：包内容都在 `OEBPS/` 下，[DiaryEpubItem.href] 与
/// [DiaryEpubNavPoint.href] 都相对于它（内容文件在 `text/`，图片在
/// `images/`）。
class DiaryEpubPackage {
  const DiaryEpubPackage._();

  static const DiaryHtmlMarkup _m = DiaryHtmlMarkup.epub;

  /// OCF 规定的第一个文件，内容固定、必须不压缩（见 [DiaryEpubWriter]）。
  static const String mimetype = 'application/epub+zip';

  static const String root = 'OEBPS';

  static const String containerXml =
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<container version="1.0" '
      'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
      '<rootfiles>\n'
      '<rootfile full-path="$root/content.opf" '
      'media-type="application/oebps-package+xml"/>\n'
      '</rootfiles>\n'
      '</container>\n';

  /// 包的唯一标识：`urn:uuid:`（按 RFC 4122 第 5 版的位排布，取导出时刻与
  /// 篇目的 SHA-1）。同一批日记每次导出都是一本新书：阅读器按标识判断
  /// “同一本书”，相同的标识可能让再次导入的新版本被当成已有而忽略；同样
  /// 的输入得到同样的标识，测试可以断言。
  static String identifierFor(Iterable<String> diaryIds, DateTime exportedAt) {
    final digest = sha1.convert(
      utf8.encode(
        <String>[
          'jotsy-epub',
          exportedAt.toUtc().toIso8601String(),
          ...diaryIds,
        ].join('\n'),
      ),
    );
    final bytes = digest.bytes.sublist(0, 16);
    bytes[6] = (bytes[6] & 0x0F) | 0x50;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'urn:uuid:${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// `dcterms:modified` 要求的写法：UTC，精确到秒，以 `Z` 结尾。
  static String timestamp(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
        '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:'
        '${two(utc.second)}Z';
  }

  /// 一个内容文件：XHTML 外壳加 [body]（已转义好的片段）。[title] 为空时
  /// 用 `Jotsy`（XHTML 的 `<title>` 不能为空）；样式表 [stylesheet] 相对
  /// 于这个文件。
  static String page({
    required String language,
    required String title,
    required String body,
    String stylesheet = '../style.css',
  }) {
    final heading = title.trim().isEmpty ? 'Jotsy' : title;
    return '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!DOCTYPE html>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml" '
        'xmlns:epub="http://www.idpf.org/2007/ops" '
        'lang="${_m.attr(language)}" xml:lang="${_m.attr(language)}">\n'
        '<head>\n'
        '<meta charset="utf-8"/>\n'
        '<title>${_m.text(heading)}</title>\n'
        '<link rel="stylesheet" type="text/css" href="$stylesheet"/>\n'
        '</head>\n'
        '<body>\n$body</body>\n'
        '</html>\n';
  }

  /// 导航文档：`<nav epub:type="toc">`，[heading] 为目录的标题（没有时不写）。
  /// 有章节时（[chapters]）外层列表是章、里层是篇；否则是一层篇目。
  static String nav({
    required String language,
    required String title,
    required String? heading,
    required List<DiaryEpubNavPoint> points,
    required bool chapters,
  }) {
    final out = StringBuffer('<nav epub:type="toc" id="toc" class="toc">\n');
    if (heading != null && heading.trim().isNotEmpty) {
      out.write('<h1>${_m.text(heading)}</h1>\n');
    }
    _writeNavList(
      out,
      points,
      className: chapters ? 'toc-chapters' : 'toc-entries',
    );
    out.write('</nav>\n');
    return page(
      language: language,
      title: title,
      body: out.toString(),
      stylesheet: 'style.css',
    );
  }

  static void _writeNavList(
    StringBuffer out,
    List<DiaryEpubNavPoint> points, {
    required String className,
  }) {
    out.write('<ol class="$className">\n');
    for (final point in points) {
      out.write('<li><a href="${_m.attr(point.href)}">');
      if (point.date != null) {
        out.write('<span class="toc-date">${_m.text(point.date!)}</span> ');
      }
      out.write('${_m.text(point.label)}</a>');
      if (point.children.isNotEmpty) {
        out.write('\n');
        _writeNavList(out, point.children, className: 'toc-entries');
      }
      out.write('</li>\n');
    }
    out.write('</ol>\n');
  }

  /// EPUB 2 的目录（`toc.ncx`）：EPUB 3 阅读器读导航文档，只认 EPUB 2 的
  /// 旧阅读器读这份。`playOrder` 按出现顺序编号，每个目标只出现一次（章节
  /// 与它的第一篇指向同一文件的不同锚点）。
  static String ncx({
    required String identifier,
    required String language,
    required String title,
    required List<DiaryEpubNavPoint> points,
  }) {
    final depth = points.any((DiaryEpubNavPoint p) => p.children.isNotEmpty)
        ? 2
        : 1;
    final out = StringBuffer()
      ..write('<?xml version="1.0" encoding="utf-8"?>\n')
      ..write(
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" '
        'xml:lang="${_m.attr(language)}">\n',
      )
      ..write('<head>\n')
      ..write('<meta name="dtb:uid" content="${_m.attr(identifier)}"/>\n')
      ..write('<meta name="dtb:depth" content="$depth"/>\n')
      ..write('<meta name="dtb:totalPageCount" content="0"/>\n')
      ..write('<meta name="dtb:maxPageNumber" content="0"/>\n')
      ..write('</head>\n')
      ..write('<docTitle><text>${_m.text(title)}</text></docTitle>\n')
      ..write('<navMap>\n');
    var order = 0;
    void write(DiaryEpubNavPoint point) {
      order++;
      final label = point.date == null
          ? point.label
          : '${point.date} ${point.label}';
      out.write(
        '<navPoint id="nav-$order" playOrder="$order">'
        '<navLabel><text>${_m.text(label)}</text></navLabel>'
        '<content src="${_m.attr(point.href)}"/>\n',
      );
      point.children.forEach(write);
      out.write('</navPoint>\n');
    }

    points.forEach(write);
    out.write('</navMap>\n</ncx>\n');
    return out.toString();
  }

  /// 包文档：元数据、清单（[items]）与阅读顺序（[spine]，清单项的 id）。
  /// [coverImageId] 是封面图片的清单 id，另写一条 EPUB 2 的
  /// `<meta name="cover">` 给旧阅读器找封面。
  static String opf({
    required String identifier,
    required String title,
    required String language,
    required DateTime modified,
    String? description,
    required List<DiaryEpubItem> items,
    required List<String> spine,
    String? coverImageId,
  }) {
    final stamp = timestamp(modified);
    final out = StringBuffer()
      ..write('<?xml version="1.0" encoding="utf-8"?>\n')
      ..write(
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
        'unique-identifier="pub-id" xml:lang="${_m.attr(language)}">\n',
      )
      ..write('<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\n')
      ..write(
        '<dc:identifier id="pub-id">${_m.text(identifier)}</dc:identifier>\n',
      )
      ..write(
        '<dc:title>${_m.text(title.trim().isEmpty ? 'Jotsy' : title)}'
        '</dc:title>\n',
      )
      ..write('<dc:language>${_m.text(language)}</dc:language>\n')
      ..write('<dc:date>$stamp</dc:date>\n');
    if (description != null && description.trim().isNotEmpty) {
      out.write('<dc:description>${_m.text(description)}</dc:description>\n');
    }
    out.write('<meta property="dcterms:modified">$stamp</meta>\n');
    if (coverImageId != null) {
      out.write('<meta name="cover" content="${_m.attr(coverImageId)}"/>\n');
    }
    out
      ..write('</metadata>\n')
      ..write('<manifest>\n');
    for (final item in items) {
      out.write(
        '<item id="${item.id}" href="${_m.attr(item.href)}" '
        'media-type="${item.mediaType}"'
        '${item.properties == null ? '' : ' properties="${item.properties}"'}'
        '/>\n',
      );
    }
    out
      ..write('</manifest>\n')
      ..write('<spine toc="ncx">\n');
    for (final id in spine) {
      out.write('<itemref idref="$id"/>\n');
    }
    out.write('</spine>\n</package>\n');
    return out.toString();
  }
}

/// 包文档清单里的一项。
@immutable
class DiaryEpubItem {
  const DiaryEpubItem({
    required this.id,
    required this.href,
    required this.mediaType,
    this.properties,
  });

  /// 清单 id（XML 名称，字母开头）。
  final String id;

  /// 相对 `OEBPS/` 的路径。
  final String href;
  final String mediaType;

  /// `nav`、`cover-image` 等；没有为 null。
  final String? properties;
}

/// 目录里的一项（导航文档与 NCX 共用）：一章或一篇。
@immutable
class DiaryEpubNavPoint {
  const DiaryEpubNavPoint({
    required this.label,
    required this.href,
    this.date,
    this.children = const <DiaryEpubNavPoint>[],
  });

  /// 篇名或章名，不能为空（导航文档要求链接有文字）。
  final String label;

  /// 篇目的日期，写在篇名前；章节为 null。
  final String? date;

  /// 相对 `OEBPS/` 的目标，可带锚点。
  final String href;

  /// 章节下的各篇。
  final List<DiaryEpubNavPoint> children;
}
