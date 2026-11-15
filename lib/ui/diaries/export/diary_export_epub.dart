import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../../core/services/diary_typography.dart';
import 'diary_export_blocks.dart';
import 'diary_export_book.dart';
import 'diary_export_code.dart';
import 'diary_export_entry.dart';
import 'diary_export_epub_package.dart';
import 'diary_export_epub_style.dart';
import 'diary_export_format.dart';
import 'diary_export_html_body.dart';
import 'diary_export_html_markup.dart';
import 'diary_export_media.dart';

/// EPUB 写出器：导出成一本可在阅读器里翻看的电子书（EPUB 3，另带 EPUB 2
/// 的 `toc.ncx` 给旧阅读器）。
///
/// 内容与网页同一套写法：每篇的抬头、正文各块（标注、折叠列表、表格、
/// 代码高亮、小图一排、对齐与首行缩进、文字色与字号）与留言都由
/// [DiaryHtmlBody] 以 XHTML 语法写出，网页能写的这里一样不少；录音、视频与
/// 附件写成一行名称（与网页一致，不把大文件塞进书里）。
///
/// 包的结构（产物交给控制器流式打包成 `.epub`）：
/// - `mimetype` 是第一个文件且不压缩（[DiaryExportBundleFile.stored]），
///   阅读器靠它识别格式；
/// - `OEBPS/text/0001.xhtml` 起每篇一个文件：阅读器按文件分章，翻到下一篇
///   另起一页，目录逐篇跳转，几百篇也不必一次排完整本；
/// - 图片放在 `OEBPS/images/`，按原文件流式写入。JPEG、PNG、GIF 原样
///   收进书里；BMP 与 WebP 不是所有阅读器都认，转成 JPEG（有透明像素时
///   PNG）再收；读不出格式（如 HEIC）或找不到的图片不写，与网页一致；
/// - 目录：导航文档 `nav.xhtml` 与 `toc.ncx` 逐篇列出“日期 标题”。
///
/// 导出成书（[book] 不为 null）时，书的开头是扉页（`text/title.xhtml`：封面、
/// 书名、简介、统计行与导出日期）与可见的目录页（导航文档本身排进阅读顺序），
/// 每篇标题降为 h2、正文标题顺延；有章节时每章的第一篇文件以 `<h1>` 章节
/// 标题开头（与 Word 一样，章节标题与第一篇同页），目录按章分组；书的封面
/// 同时是 EPUB 的封面图片（阅读器书架上显示它）。
class DiaryEpubWriter {
  const DiaryEpubWriter._();

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
    DiaryTypography typography = const DiaryTypography(),
    DateTime? now,
  }) async {
    const root = DiaryEpubPackage.root;
    final exportedAt = now ?? DateTime.now();
    final language = languageTag.trim().isEmpty ? 'und' : languageTag.trim();
    final title = documentTitle.trim().isEmpty ? 'Jotsy' : documentTitle.trim();
    // 没有代码块时不写高亮样式。
    final codeTheme =
        code != null &&
            entries.any(
              (DiaryExportEntry entry) => entry.blocks.any(
                (ExportBlock block) => block.kind == ExportBlockKind.code,
              ),
            )
        ? code
        : null;

    final images = _EpubImages(media);
    if (options.includeMedia) {
      if (book?.coverPath != null) {
        await images.collect(book!.coverPath!, cover: true);
      }
      for (final entry in entries) {
        for (final source in entry.imageSources) {
          await images.collect(source);
        }
      }
    }

    final body = DiaryHtmlBody(
      markup: DiaryHtmlMarkup.epub,
      labels: labels,
      images: images.sources,
      code: codeTheme,
      typography: typography,
    );
    final pages = <_EpubPage>[];
    final points = <DiaryEpubNavPoint>[];
    String entryHref() =>
        'text/${(pages.where((p) => p.isEntry).length + 1).toString().padLeft(4, '0')}.xhtml';
    DiaryEpubNavPoint pointOf(DiaryExportEntry entry, String href) =>
        DiaryEpubNavPoint(
          label: labels.titleOf(entry),
          date: labels.formatDate(entry.createdAt.toLocal()),
          href: href,
        );

    if (book == null) {
      for (final entry in entries) {
        final href = entryHref();
        final out = StringBuffer();
        body.writeEntry(out, entry, includeMeta: options.includeMeta);
        pages.add(_EpubPage.entry(href, labels.titleOf(entry), out));
        points.add(pointOf(entry, href));
      }
    } else {
      pages.add(_titlePage(book, images.sources));
      for (final section in book.sections) {
        final chapterTitle = section.title;
        final children = <DiaryEpubNavPoint>[];
        String? chapterHref;
        for (final entry in section.entries) {
          final href = entryHref();
          final anchor = book.anchorOf(entry);
          final out = StringBuffer();
          if (chapterTitle != null && chapterHref == null) {
            out.write(
              '<h1 class="chapter-title" id="${section.anchor}">'
              '${DiaryHtmlMarkup.epub.text(chapterTitle)}</h1>\n',
            );
            chapterHref = '$href#${section.anchor}';
          }
          body.writeEntry(
            out,
            entry,
            includeMeta: options.includeMeta,
            anchor: anchor,
            titleLevel: 2,
          );
          pages.add(_EpubPage.entry(href, labels.titleOf(entry), out));
          children.add(pointOf(entry, '$href#$anchor'));
        }
        if (chapterTitle != null && chapterHref != null) {
          points.add(
            DiaryEpubNavPoint(
              // 导航里的链接不能没有文字。
              label: chapterTitle.trim().isEmpty
                  ? labels.untitled
                  : chapterTitle,
              href: chapterHref,
              children: children,
            ),
          );
        } else {
          points.addAll(children);
        }
      }
    }

    final identifier = DiaryEpubPackage.identifierFor(
      entries.map((DiaryExportEntry e) => e.diaryId),
      exportedAt,
    );
    final chapters = book?.hasChapterHeadings ?? false;
    final items = <DiaryEpubItem>[
      const DiaryEpubItem(
        id: 'nav',
        href: 'nav.xhtml',
        mediaType: 'application/xhtml+xml',
        properties: 'nav',
      ),
      const DiaryEpubItem(
        id: 'ncx',
        href: 'toc.ncx',
        mediaType: 'application/x-dtbncx+xml',
      ),
      const DiaryEpubItem(id: 'css', href: 'style.css', mediaType: 'text/css'),
      for (final page in pages)
        DiaryEpubItem(
          id: page.id,
          href: page.href,
          mediaType: 'application/xhtml+xml',
        ),
      ...images.items,
    ];
    // 成书时目录页排在扉页之后、正文之前，翻书时能看到；普通导出的目录只
    // 在阅读器的目录面板里。
    final spine = <String>[
      for (final page in pages) ...<String>[
        page.id,
        if (book != null && !page.isEntry) 'nav',
      ],
    ];

    List<int> encode(String value) => utf8.encode(value);
    return DiaryExportOutput.bundle(
      <DiaryExportBundleFile>[
        DiaryExportBundleFile.bytes(
          'mimetype',
          encode(DiaryEpubPackage.mimetype),
          stored: true,
        ),
        DiaryExportBundleFile.bytes(
          'META-INF/container.xml',
          encode(DiaryEpubPackage.containerXml),
        ),
        DiaryExportBundleFile.bytes(
          '$root/content.opf',
          encode(
            DiaryEpubPackage.opf(
              identifier: identifier,
              title: title,
              language: language,
              modified: exportedAt,
              description: book?.description,
              items: items,
              spine: spine,
              coverImageId: images.coverId,
            ),
          ),
        ),
        DiaryExportBundleFile.bytes(
          '$root/nav.xhtml',
          encode(
            DiaryEpubPackage.nav(
              language: language,
              title: book?.contentsTitle ?? title,
              heading: book?.contentsTitle ?? labels.book?.contents,
              points: points,
              chapters: chapters,
            ),
          ),
        ),
        DiaryExportBundleFile.bytes(
          '$root/toc.ncx',
          encode(
            DiaryEpubPackage.ncx(
              identifier: identifier,
              language: language,
              title: title,
              points: points,
            ),
          ),
        ),
        DiaryExportBundleFile.bytes(
          '$root/style.css',
          encode(
            DiaryEpubStyle.css(code: codeTheme, fontFamilies: fontFamilies),
          ),
        ),
        for (final page in pages)
          DiaryExportBundleFile.bytes(
            '$root/${page.href}',
            encode(
              DiaryEpubPackage.page(
                language: language,
                title: page.title,
                body: page.body.toString(),
              ),
            ),
          ),
        ...images.files,
      ],
      containerExtension: DiaryExportFormat.epub.extension,
      containerMimeType: DiaryExportFormat.epub.mimeType,
    );
  }

  /// 扉页：封面（开启媒体且读得到时）、书名、简介、统计行与导出日期。
  static _EpubPage _titlePage(
    DiaryExportBookLayout book,
    Map<String, String> images,
  ) {
    const m = DiaryHtmlMarkup.epub;
    final out = StringBuffer(
      '<section class="book-title" epub:type="titlepage">\n',
    );
    final cover = book.coverPath == null ? null : images[book.coverPath!];
    if (cover != null) {
      out.write(
        '<figure class="book-cover"><img src="${m.attr(cover)}" alt=""/>'
        '</figure>\n',
      );
    }
    out.write('<h1>${m.text(book.title)}</h1>\n');
    if (book.description != null) {
      out.write(
        '<p class="book-description">${m.text(book.description!)}</p>\n',
      );
    }
    if (book.summaryLine.isNotEmpty) {
      out.write('<p class="meta">${m.text(book.summaryLine)}</p>\n');
    }
    out
      ..write('<p class="meta">${m.text(book.exportedLine)}</p>\n')
      ..write('</section>\n');
    return _EpubPage('titlepage', 'text/title.xhtml', book.title, out);
  }

  /// 阅读器不一定认得的图片（BMP、WebP）转成 JPEG（质量 90）；有透明像素
  /// 时转成 PNG，不把透明处压成黑底。在后台 isolate 里解码与编码，不卡
  /// 等待动画；解不开时为 null（这张图不写，与读不出格式的图片一样）。
  @visibleForTesting
  static Future<({Uint8List bytes, String mimeType, String extension})?>
  transcodeImage(Uint8List bytes) => Isolate.run(() {
    final image = img.decodeImage(bytes);
    if (image == null) {
      return null;
    }
    final max = image.maxChannelValue;
    final transparent =
        image.hasAlpha && image.any((img.Pixel pixel) => pixel.a < max);
    return transparent
        ? (
            bytes: img.encodePng(image),
            mimeType: 'image/png',
            extension: '.png',
          )
        : (
            bytes: img.encodeJpg(image, quality: 90),
            mimeType: 'image/jpeg',
            extension: '.jpg',
          );
  });
}

/// 书里的一个内容文件（扉页或一篇日记）。
class _EpubPage {
  _EpubPage(this.id, this.href, this.title, this.body);

  /// 一篇日记：清单 id 取文件名（`e0001`）。
  _EpubPage.entry(String href, String title, StringBuffer body)
    : this(
        'e${href.substring('text/'.length, href.length - '.xhtml'.length)}',
        href,
        title,
        body,
      );

  final String id;

  /// 相对 `OEBPS/` 的路径。
  final String href;
  final String title;
  final StringBuffer body;

  bool get isEntry => id != 'titlepage';
}

/// 收进书里的图片：来源 → 内容文件里的 `src`（`../images/0001.jpg`），以及
/// 清单项与要打包的文件。同一来源只收一次。
class _EpubImages {
  _EpubImages(this._media);

  final DiaryExportMediaLibrary _media;
  final Map<String, String> sources = <String, String>{};
  final List<DiaryEpubItem> items = <DiaryEpubItem>[];
  final List<DiaryExportBundleFile> files = <DiaryExportBundleFile>[];

  /// 封面图片的清单 id；没有封面为 null。
  String? coverId;

  /// 阅读器普遍认得、原样收进书里的格式（EPUB 核心媒体类型）。
  static const Set<String> _passThrough = <String>{
    'image/jpeg',
    'image/png',
    'image/gif',
  };

  Future<void> collect(String source, {bool cover = false}) async {
    if (sources.containsKey(source)) {
      return;
    }
    final file = await _media.resolve(source);
    // 读不出格式（如 HEIC）的图片阅读器多半也显示不了，略过。
    final info = file == null ? null : await _media.imageInfoOf(source);
    if (file == null || info == null) {
      return;
    }
    final index = (items.length + 1).toString().padLeft(4, '0');
    final String mediaType;
    final String href;
    if (_passThrough.contains(info.mimeType)) {
      mediaType = info.mimeType;
      href = 'images/$index${info.extension}';
      files.add(
        file.file != null
            ? DiaryExportBundleFile.file(
                '${DiaryEpubPackage.root}/$href',
                file.file!,
              )
            : DiaryExportBundleFile.bytes(
                '${DiaryEpubPackage.root}/$href',
                file.bytes!,
              ),
      );
    } else {
      final bytes = await _media.bytesOf(source);
      final converted = bytes == null
          ? null
          : await DiaryEpubWriter.transcodeImage(bytes);
      if (converted == null) {
        return;
      }
      mediaType = converted.mimeType;
      href = 'images/$index${converted.extension}';
      files.add(
        DiaryExportBundleFile.bytes(
          '${DiaryEpubPackage.root}/$href',
          converted.bytes,
        ),
      );
    }
    final id = cover ? 'cover-image' : 'img$index';
    if (cover) {
      coverId = id;
    }
    sources[source] = '../$href';
    items.add(
      DiaryEpubItem(
        id: id,
        href: href,
        mediaType: mediaType,
        properties: cover ? 'cover-image' : null,
      ),
    );
  }
}
