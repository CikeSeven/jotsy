import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show TextDirection;
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_to_pdf/flutter_quill_to_pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_blocks.dart';
import 'diary_export_book.dart';
import 'diary_export_entry.dart';
import 'diary_export_format.dart';
import 'diary_export_media.dart';
import 'diary_export_plain_text.dart';

/// PDF 用的字体：内置 HarmonyOS Sans SC 常规与粗体，生成时按实际字符做
/// 子集嵌入。字体文件各约 8MB，加载一次后由调用方复用。
class DiaryPdfFonts {
  const DiaryPdfFonts(this.regular, this.bold);

  final pw.Font regular;
  final pw.Font bold;

  static Future<DiaryPdfFonts> load() async {
    const base = 'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC';
    // 依次加载：资源包可能返回 SynchronousFuture，交给 Future.wait 会在
    // 结果写入前就完成，得到空列表。
    final regular = await rootBundle.load('${base}_Regular.ttf');
    final bold = await rootBundle.load('${base}_Bold.ttf');
    return DiaryPdfFonts(pw.Font.ttf(regular), pw.Font.ttf(bold));
  }
}

/// PDF 写出器：多篇日记连续排版进一个 A4 文档，页脚为页码。
///
/// 正文仍由 flutter_quill_to_pdf 按 Delta 渲染（保留标题、列表、引用、
/// 代码块等样式），但不用它直接生成整份文档：经 `pageBuilder` 取出每篇
/// 正文的块级组件，再与自绘的抬头（标题、日期、信息行、标签、封面）拼进
/// 同一个 MultiPage。
///
/// 送进插件前先改写正文（[_prepareBody]），绕开插件的几处问题：
/// - 本地图片文件不存在时插件会直接抛异常，整次导出失败——缺失的图片先删掉；
/// - 以 `/9j/` 开头的 base64（JPEG）会被它误判成本地路径——所有图片改写成
///   `https://jotsy.export/<序号>.png` 的虚拟地址，由 `onDetectImageUrl`
///   按序号返回已读好的字节；
/// - 录音、视频、附件它会把路径原样印出——改成名称说明，远程地址保留链接；
/// - 正文非空却解析不出段落时它会死循环——没有可见内容的正文不送进去。
///
/// 心情 emoji 不写进 PDF：内置字体没有 emoji 字形，会印成方框。
///
/// 排版库生成文档时要同时持有全部图片；图片总量超过 [maxImageBytes] 时
/// 抛出 [DiaryExportTooLargeException]，请用户缩小范围或关闭图片，而不是
/// 让应用因内存不足被系统结束。
///
/// 导出成书（`book` 不为 null）时文档分三部分：扉页（单页：封面、书名、
/// 简介、统计行与导出日期，封面同样计入图片总量）、目录、正文（每章另起
/// 一页，以章节标题开头）。章节与各篇标题同时是 PDF 书签与命名目标，目录
/// 每行可点按跳转，并带真实页码：
/// - 页码只有正文绘制时才确定（`MultiPage` 排版时放不下的组件会挪到下一页
///   重排，排版阶段记下的页码不可靠），所以由 [_BookAnchor] 在绘制时记下；
/// - pdf 库按 `addPage` 的先后绘制，目录因此最后加入、以 `index` 插在扉页
///   之后：正文先绘制、页码已记下，目录绘制时再填（[pw.DelayedWidget]）。
///   页码与页脚同一套编号（扉页算第 1 页）。
class DiaryPdfWriter {
  const DiaryPdfWriter._();

  static const String _virtualImageHost = 'https://jotsy.export/';

  /// 图片总量上限（字节）：手机照片约 3~5MB 一张，约等于 40 张左右。
  static const int maxImageBytes = 160 * 1024 * 1024;
  static final PdfPageFormat _pageFormat = PdfPageFormat(
    21.0 * PdfPageFormat.cm,
    29.7 * PdfPageFormat.cm,
    marginAll: 2.0 * PdfPageFormat.cm,
  );

  /// 扉页封面的最大高度：书名、简介与统计行要留在同一页。
  static const double _maxCoverHeight = 11.0 * PdfPageFormat.cm;

  static Future<DiaryExportOutput> write(
    List<DiaryExportEntry> entries, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required DiaryPdfFonts fonts,
    required String documentTitle,
    TextDirection textDirection = TextDirection.ltr,
    DiaryExportBookLayout? book,
  }) async {
    final theme = pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      italic: fonts.regular,
      boldItalic: fonts.bold,
      fontFallback: <pw.Font>[fonts.regular],
    );
    final images = <Uint8List>[];
    final document = pw.Document(
      theme: theme,
      title: documentTitle,
      creator: 'Jotsy',
      producer: 'Jotsy',
    );
    if (book != null) {
      await _writeBook(
        document,
        book,
        options: options,
        labels: labels,
        media: media,
        fonts: fonts,
        theme: theme,
        images: images,
        textDirection: textDirection,
      );
      return DiaryExportOutput.single(await document.save());
    }

    final content = <pw.Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) {
        content.addAll(_entrySeparator());
      }
      content.addAll(
        await _entryWidgets(
          entries[i],
          options: options,
          labels: labels,
          media: media,
          fonts: fonts,
          theme: theme,
          images: images,
          textDirection: textDirection,
        ),
      );
    }
    document.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        theme: theme,
        maxPages: 100000,
        footer: _footer,
        build: (pw.Context context) => content,
      ),
    );
    return DiaryExportOutput.single(await document.save());
  }

  static pw.Widget _footer(pw.Context context) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      '${context.pageNumber} / ${context.pagesCount}',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    ),
  );

  /// 篇与篇之间的细分隔线。
  static List<pw.Widget> _entrySeparator() => <pw.Widget>[
    pw.SizedBox(height: 20),
    pw.Divider(color: PdfColors.grey400, thickness: 0.5),
    pw.SizedBox(height: 16),
  ];

  /// 一篇日记的抬头与正文；[wrapTitle] 给标题套上书签锚点（成书时）。
  static Future<List<pw.Widget>> _entryWidgets(
    DiaryExportEntry entry, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required DiaryPdfFonts fonts,
    required pw.ThemeData theme,
    required List<Uint8List> images,
    required TextDirection textDirection,
    pw.Widget Function(pw.Widget title)? wrapTitle,
  }) async {
    final widgets = await _header(
      entry,
      options: options,
      labels: labels,
      media: media,
      images: images,
      wrapTitle: wrapTitle,
    );
    final body = await prepareBody(
      entry,
      includeImages: options.includeMedia,
      labels: labels,
      media: media,
      images: images,
    );
    if (body != null) {
      widgets.addAll(
        await _renderBody(
          body,
          theme: theme,
          fonts: fonts,
          images: images,
          textDirection: textDirection,
        ),
      );
    }
    return widgets;
  }

  /// 成书：扉页 → 目录 → 正文（见类注释里的页码与绘制顺序）。
  static Future<void> _writeBook(
    pw.Document document,
    DiaryExportBookLayout book, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required DiaryPdfFonts fonts,
    required pw.ThemeData theme,
    required List<Uint8List> images,
    required TextDirection textDirection,
  }) async {
    // 锚点 → 页码：正文绘制时由 _BookAnchor 写入，目录绘制时读取。
    final pages = <String, int>{};
    Uint8List? cover;
    if (options.includeMedia && book.coverPath != null) {
      final bytes = await media.bytesOf(book.coverPath!);
      if (bytes != null && ExportImageInfo.read(bytes) != null) {
        _addImage(images, bytes);
        cover = bytes;
      }
    }

    final content = <pw.Widget>[];
    final entryLevel = book.hasChapterHeadings ? 1 : 0;
    for (var s = 0; s < book.sections.length; s++) {
      final section = book.sections[s];
      final title = section.title;
      if (title != null) {
        // 正文本身从新的一页开始，之后每章另起一页。
        if (s > 0) {
          content.add(pw.NewPage());
        }
        content.add(
          _BookAnchor(
            name: section.anchor,
            title: title,
            level: 0,
            pages: pages,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }
      for (var i = 0; i < section.entries.length; i++) {
        final entry = section.entries[i];
        if (i > 0) {
          content.addAll(_entrySeparator());
        }
        content.addAll(
          await _entryWidgets(
            entry,
            options: options,
            labels: labels,
            media: media,
            fonts: fonts,
            theme: theme,
            images: images,
            textDirection: textDirection,
            wrapTitle: (pw.Widget child) => _BookAnchor(
              name: book.anchorOf(entry),
              title: labels.titleOf(entry),
              level: entryLevel,
              pages: pages,
              child: child,
            ),
          ),
        );
      }
    }

    document
      ..addPage(
        pw.Page(
          pageFormat: _pageFormat,
          theme: theme,
          build: (pw.Context context) => _titlePage(book, cover),
        ),
      )
      ..addPage(
        pw.MultiPage(
          pageFormat: _pageFormat,
          theme: theme,
          maxPages: 100000,
          footer: _footer,
          build: (pw.Context context) => content,
        ),
      )
      // 最后加入、插在扉页之后：绘制排在正文之后，页码已经记下。
      ..addPage(
        pw.MultiPage(
          pageFormat: _pageFormat,
          theme: theme,
          maxPages: 100000,
          footer: _footer,
          build: (pw.Context context) => _contents(book, labels, pages),
        ),
        index: 1,
      );
  }

  static pw.Widget _titlePage(DiaryExportBookLayout book, Uint8List? cover) {
    final info = cover == null ? null : ExportImageInfo.read(cover);
    pw.Widget? coverImage;
    if (cover != null && info != null && info.width > 0 && info.height > 0) {
      final scale = math.min(
        _pageFormat.availableWidth / info.width,
        _maxCoverHeight / info.height,
      );
      coverImage = pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: pw.Image(
          pw.MemoryImage(cover),
          width: info.width * scale,
          height: info.height * scale,
          fit: pw.BoxFit.contain,
        ),
      );
    }
    const muted = pw.TextStyle(fontSize: 11, color: PdfColors.grey700);
    return pw.Center(
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: <pw.Widget>[
          if (coverImage != null) ...<pw.Widget>[
            coverImage,
            pw.SizedBox(height: 28),
          ],
          pw.Text(
            book.title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
          ),
          if (book.description != null) ...<pw.Widget>[
            pw.SizedBox(height: 12),
            pw.Text(
              book.description!,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 20),
          if (book.summaryLine.isNotEmpty)
            pw.Text(
              book.summaryLine,
              textAlign: pw.TextAlign.center,
              style: muted,
            ),
          pw.SizedBox(height: 4),
          pw.Text(
            book.exportedLine,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _contents(
    DiaryExportBookLayout book,
    DiaryExportLabels labels,
    Map<String, int> pages,
  ) {
    final widgets = <pw.Widget>[
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 16),
        child: pw.Text(
          book.contentsTitle,
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];
    final indent = book.hasChapterHeadings ? 16.0 : 0.0;
    for (final section in book.sections) {
      if (section.title != null) {
        widgets.add(
          _contentsRow(
            section.title!,
            section.anchor,
            pages,
            style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold),
            top: widgets.length > 1 ? 10 : 0,
          ),
        );
      }
      for (final entry in section.entries) {
        widgets.add(
          _contentsRow(
            '${labels.formatDate(entry.createdAt.toLocal())}  '
            '${labels.titleOf(entry)}',
            book.anchorOf(entry),
            pages,
            style: const pw.TextStyle(fontSize: 11),
            indent: indent,
          ),
        );
      }
    }
    return widgets;
  }

  /// 目录的一行：点按跳到 [anchor]，右侧是它所在的页码。
  static pw.Widget _contentsRow(
    String text,
    String anchor,
    Map<String, int> pages, {
    required pw.TextStyle style,
    double indent = 0,
    double top = 0,
  }) {
    return pw.Link(
      destination: anchor,
      child: pw.Padding(
        padding: pw.EdgeInsets.only(left: indent, top: top + 3, bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(child: pw.Text(text, style: style)),
            pw.SizedBox(width: 12),
            // 排版时页码还不知道，先占一格；绘制时（正文已绘制完）再取。
            pw.SizedBox(
              width: 36,
              child: pw.DelayedWidget(
                build: (pw.Context context) => pw.Text(
                  pages[anchor]?.toString() ?? ' ',
                  style: style,
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<List<pw.Widget>> _header(
    DiaryExportEntry entry, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required List<Uint8List> images,
    pw.Widget Function(pw.Widget title)? wrapTitle,
  }) async {
    const muted = pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700);
    final title = pw.Text(
      labels.titleOf(entry),
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    );
    final widgets = <pw.Widget>[
      wrapTitle == null ? title : wrapTitle(title),
      pw.SizedBox(height: 4),
      pw.Text(labels.formatDateTime(entry.createdAt.toLocal()), style: muted),
    ];
    if (options.includeMeta) {
      final meta = labels.metaLine(entry, includeMood: false);
      if (meta.isNotEmpty) {
        widgets.add(pw.Text(meta, style: muted));
      }
      if (entry.tagNames.isNotEmpty) {
        widgets.add(
          pw.Text(
            entry.tagNames.map((String tag) => '#$tag').join('  '),
            style: const pw.TextStyle(
              fontSize: 10.5,
              color: PdfColors.blueGrey700,
            ),
          ),
        );
      }
    }
    if (options.includeMedia && entry.cover != null) {
      final bytes = await media.bytesOf(entry.cover!);
      if (bytes != null && ExportImageInfo.read(bytes) != null) {
        // 计入总量（虚拟地址按下标取图，封面不经插件，放在列表里不影响）。
        _addImage(images, bytes);
        widgets
          ..add(pw.SizedBox(height: 12))
          ..add(
            pw.ClipRRect(
              horizontalRadius: 8,
              verticalRadius: 8,
              child: pw.Image(
                pw.MemoryImage(bytes),
                height: 260,
                fit: pw.BoxFit.cover,
              ),
            ),
          );
      }
    }
    widgets.add(pw.SizedBox(height: 14));
    return widgets;
  }

  /// 改写正文 Delta（见类注释）；没有可见内容时返回 null。
  @visibleForTesting
  static Future<Delta?> prepareBody(
    DiaryExportEntry entry, {
    required bool includeImages,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required List<Uint8List> images,
  }) async {
    final ops = <Map<String, dynamic>>[];
    var hasContent = false;
    for (final raw in entry.deltaOps) {
      if (raw is! Map) {
        continue;
      }
      final op = Map<String, dynamic>.from(raw);
      final insert = op['insert'];
      if (insert is String) {
        hasContent = hasContent || insert.trim().isNotEmpty;
        ops.add(op);
        continue;
      }
      if (insert is! Map) {
        continue;
      }
      final image = insert['image'];
      if (image is String) {
        final bytes = includeImages ? await media.bytesOf(image) : null;
        if (bytes == null || ExportImageInfo.read(bytes) == null) {
          continue;
        }
        _addImage(images, bytes);
        op['insert'] = <String, dynamic>{
          'image': '$_virtualImageHost${images.length - 1}.png',
        };
        hasContent = true;
        ops.add(op);
        continue;
      }
      final label = _embedLabel(insert, labels);
      if (label != null) {
        hasContent = true;
        ops.add(<String, dynamic>{
          'insert': label.text,
          if (label.link != null)
            'attributes': <String, dynamic>{'link': label.link},
        });
      }
    }
    if (!hasContent) {
      return null;
    }
    // Delta 必须以换行结尾，否则最后一行不会成为段落。
    final last = ops.isEmpty ? null : ops.last['insert'];
    if (last is! String || !last.endsWith('\n')) {
      ops.add(<String, dynamic>{'insert': '\n'});
    }
    return Delta.fromJson(ops);
  }

  static void _addImage(List<Uint8List> images, Uint8List bytes) {
    images.add(bytes);
    final total = images.fold<int>(0, (int sum, Uint8List b) => sum + b.length);
    if (total > maxImageBytes) {
      throw DiaryExportTooLargeException(total);
    }
  }

  static ({String text, String? link})? _embedLabel(
    Map<dynamic, dynamic> insert,
    DiaryExportLabels labels,
  ) {
    ({String text, String? link}) labelFor(ExportBlock block, String path) {
      final uri = Uri.tryParse(path);
      final remote =
          uri != null && (uri.isScheme('http') || uri.isScheme('https'));
      return (text: labels.mediaLine(block), link: remote ? path : null);
    }

    final blocks = ExportBlockParser.parse(<dynamic>[
      <String, dynamic>{'insert': insert},
    ]);
    final block = blocks.isEmpty ? null : blocks.single;
    if (block?.kind == ExportBlockKind.divider) {
      // 插件不认识分隔线嵌入，写成一行横线。
      return (text: ExportPlainText.dividerLine, link: null);
    }
    if (block == null || block.kind != ExportBlockKind.media) {
      // 其他无文字的嵌入：插件本身也会忽略，这里直接去掉。
      return null;
    }
    return labelFor(block, block.source!);
  }

  static Future<List<pw.Widget>> _renderBody(
    Delta body, {
    required pw.ThemeData theme,
    required DiaryPdfFonts fonts,
    required List<Uint8List> images,
    required TextDirection textDirection,
  }) async {
    final captured = <pw.Widget>[];
    final converter = PDFConverter(
      pageFormat: PDFPageFormat.a4,
      document: body,
      textDirection: textDirection,
      themeData: theme,
      codeBlockFont: fonts.regular,
      // 日记里的代码块只是等宽文字；语法高亮库还会把解析异常打到控制台。
      // 插件把该参数标为实验性，变动时这里会编译失败，不会静默失效。
      // ignore: experimental_member_use
      enableCodeBlockHighlighting: false,
      fallbacks: <pw.Font>[fonts.regular],
      // 插件把该回调标为实验性；它是唯一能直接交给插件图片字节的入口，
      // 接口若在升级中变化，这里会编译失败而不是静默失效。
      // ignore: experimental_member_use
      onDetectImageUrl: (String url) async {
        final index = int.tryParse(
          url.substring(_virtualImageHost.length).split('.').first,
        );
        return index == null || index >= images.length ? null : images[index];
      },
      onRequestFontFamily: (FontFamilyRequest _) => FontFamilyResponse(
        fontNormalV: fonts.regular,
        boldFontV: fonts.bold,
        italicFontV: fonts.regular,
        boldItalicFontV: fonts.bold,
        fallbacks: <pw.Font>[fonts.regular],
      ),
    );
    // 只借用插件把 Delta 转成块级组件；它生成的那份文档直接丢弃。
    await converter.createDocument(
      pageBuilder: (List<pw.Widget> children, pw.ThemeData _, PdfPageFormat _) {
        captured.addAll(children);
        return pw.Page(build: (pw.Context _) => pw.SizedBox());
      },
    );
    return captured;
  }
}

/// 成书的章节与篇标题：PDF 书签（大纲）+ 命名目标，并在绘制时记下自己所在
/// 的页码供目录使用（见 [DiaryPdfWriter] 的类注释）。
class _BookAnchor extends pw.Outline {
  _BookAnchor({
    required super.name,
    required super.title,
    required super.level,
    required this.pages,
    required pw.Widget super.child,
  });

  final Map<String, int> pages;

  @override
  void paint(pw.Context context) {
    super.paint(context);
    pages[name] = context.pageNumber;
  }
}
