import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Color, TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/font_file_info.dart';
import '../models/diary_text_colors.dart';
import 'diary_export_blocks.dart';
import 'diary_export_book.dart';
import 'diary_export_code.dart';
import 'diary_export_entry.dart';
import 'diary_export_font.dart';
import 'diary_export_format.dart';
import 'diary_export_media.dart';
import 'diary_export_pdf_body.dart';
import 'diary_export_pdf_comments.dart';
import 'diary_export_pdf_text_effects.dart';
import 'diary_export_plain_text.dart';

/// PDF 用的字体，生成时按实际字符做子集嵌入。字体文件各约 8MB 起，加载一次
/// 后由调用方复用。
///
/// - 默认为内置 HarmonyOS Sans SC 常规与粗体；
/// - 正文排版选了导入字体（[load] 给出 `bodyFont`）且 pdf 库能嵌入时，整份
///   文档（标题、信息行、正文、目录与页码）改用它。导入字体只有一个字重，
///   粗体也用它（正文经 [DiaryPdfTextEffects] 补粗），避免在同一段里混用
///   两种字形；
/// - [bundled] 始终是内置常规体：导入字体缺字时回落到它（如只含西文的字体
///   遇到中文），代码块也用它（应用内代码块同样不跟随正文字体）。
class DiaryPdfFonts {
  const DiaryPdfFonts(this.regular, this.bold, {pw.Font? bundled})
    : bundled = bundled ?? regular;

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font bundled;

  static Future<DiaryPdfFonts> load([DiaryExportFont? bodyFont]) async {
    const base = 'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC';
    // 依次加载：资源包可能返回 SynchronousFuture，交给 Future.wait 会在
    // 结果写入前就完成，得到空列表。
    final regular = pw.Font.ttf(await rootBundle.load('${base}_Regular.ttf'));
    final imported = bodyFont == null ? null : embeddable(bodyFont.bytes);
    if (imported != null) {
      // 用不到内置粗体，不再读入。
      return DiaryPdfFonts(imported, imported, bundled: regular);
    }
    final bold = pw.Font.ttf(await rootBundle.load('${base}_Bold.ttf'));
    return DiaryPdfFonts(regular, bold);
  }

  /// 导入字体能否交给 pdf 库：先取出 TrueType 字面（TTC 取第一个），再试
  /// 解析一遍。CFF 轮廓、缺表、没有 Unicode 字符映射或解析出错时返回 null，
  /// 整份文档回落内置字体——字体在排版途中才被解析，那时出错会让整次导出
  /// 失败。
  @visibleForTesting
  static pw.Font? embeddable(Uint8List bytes) {
    final face = extractTrueTypeFace(bytes);
    if (face == null) {
      return null;
    }
    final data = ByteData.sublistView(face);
    try {
      final parser = TtfParser(data);
      // 子集写出时空格的字形是直接取用的（没有就会抛出）。
      if (parser.glyphOffsets.isEmpty ||
          !parser.charToGlyphIndexMap.containsKey(0x20)) {
        return null;
      }
    } catch (_) {
      // 调试模式下是断言失败，发布模式下多为越界；都按无法嵌入处理。
      return null;
    }
    return pw.Font.ttf(data);
  }
}

/// PDF 写出器：多篇日记连续排版进一个 A4 文档，页脚为页码。
///
/// 正文与其他格式读同一份块（[DiaryExportEntry.blocks]，块文档直接解析，
/// 保留嵌套深度与列表样式），经 prepareBody 检查图片、把媒体换为可读名称、
/// 压平透明色与代码着色，再由 pdf 库直接绘制，保持标题、列表、嵌套、引用与
/// 行内格式。所有图片先检查/载入后换成虚拟地址，避免缺图中断或泄露私有
/// 路径；高亮与应用配色同源。中文字体的粗斜体经 DiaryPdfTextEffects 在绘制时补偿。
///
/// 心情 emoji 不写进 PDF：内置字体没有 emoji 字形，会印成方框。有留言的
/// 日记在正文之后接留言区（[buildDiaryPdfComments]，同样不写心情）。
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
    DiaryExportCodeTheme? code,
  }) async {
    final textEffects = DiaryPdfTextEffects(
      regular: fonts.regular,
      bold: fonts.bold,
      bundled: fonts.bundled,
    );
    final theme = pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      italic: fonts.regular,
      boldItalic: fonts.bold,
      fontFallback: <pw.Font>[fonts.bundled],
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
        textEffects: textEffects,
        images: images,
        textDirection: textDirection,
        code: code,
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
          textEffects: textEffects,
          images: images,
          textDirection: textDirection,
          code: code,
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
    required DiaryPdfTextEffects textEffects,
    required List<Uint8List> images,
    required TextDirection textDirection,
    DiaryExportCodeTheme? code,
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
      code: code,
    );
    if (body != null) {
      widgets.addAll(
        buildDiaryPdfBody(
          body,
          theme: theme,
          codeFont: fonts.bundled,
          effects: textEffects,
          images: images,
          textDirection: textDirection,
          code: code,
        ),
      );
    }
    widgets.addAll(buildDiaryPdfComments(entry, labels));
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
    required DiaryPdfTextEffects textEffects,
    required List<Uint8List> images,
    required TextDirection textDirection,
    DiaryExportCodeTheme? code,
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
            textEffects: textEffects,
            images: images,
            textDirection: textDirection,
            code: code,
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

  /// 准备要绘制的正文块（见类注释）；没有可见内容时返回 null。除了把图片
  /// 字节计入 [images]，不改动任何东西：块与片段都不可变，结果是新列表。
  ///
  /// 依次：给了 [code] 时先为代码行着色（[DiaryExportCodeTheme.colorCodeBlocks]，
  /// 按语言整块高亮）；图片读出字节、读不出或关掉图片时整块去掉，否则计入
  /// [images] 并把来源换成按下标取图的虚拟地址；录音、视频、附件换成一行
  /// 名称（远程地址保留为链接，本地私有路径不写出）；分隔线写成一行横线；
  /// 还没有专门画法的标注、折叠列表与表格退化为普通段落
  /// （[ExportBlock.fallbackLines]）；最后把文字色与背景色压平到白纸上。
  @visibleForTesting
  static Future<List<ExportBlock>?> prepareBody(
    DiaryExportEntry entry, {
    required bool includeImages,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required List<Uint8List> images,
    DiaryExportCodeTheme? code,
  }) async {
    final body = <ExportBlock>[];
    var hasContent = false;
    void addText(ExportBlock block) {
      body.add(block.copyWith(inlines: _flattenColors(block.inlines)));
      hasContent = hasContent || block.plainText.trim().isNotEmpty;
    }

    for (final block in code?.colorCodeBlocks(entry.blocks) ?? entry.blocks) {
      switch (block.kind) {
        case ExportBlockKind.image:
          final bytes = includeImages
              ? await media.bytesOf(block.source!)
              : null;
          if (bytes == null || ExportImageInfo.read(bytes) == null) {
            continue;
          }
          _addImage(images, bytes);
          body.add(
            block.copyWith(
              source: '$_virtualImageHost${images.length - 1}.png',
            ),
          );
          hasContent = true;
        case ExportBlockKind.media:
          final uri = Uri.tryParse(block.source!);
          final remote =
              uri != null && (uri.isScheme('http') || uri.isScheme('https'));
          body.add(
            block.paragraphWith(<ExportInline>[
              ExportInline(
                labels.mediaLine(block),
                link: remote ? block.source : null,
              ),
            ]),
          );
          hasContent = true;
        case ExportBlockKind.divider:
          body.add(
            block.paragraphWith(const <ExportInline>[
              ExportInline(ExportPlainText.dividerLine),
            ]),
          );
          hasContent = true;
        case ExportBlockKind.callout ||
            ExportBlockKind.toggle ||
            ExportBlockKind.table:
          for (final line in block.fallbackLines) {
            addText(block.paragraphWith(line));
          }
        default:
          addText(block);
      }
    }
    return hasContent ? List<ExportBlock>.unmodifiable(body) : null;
  }

  /// PDF 的纸面颜色：页面不画背景，即白纸。
  static const Color _paper = Color(0xFFFFFFFF);

  /// 把文字色 / 背景色压平成叠在白纸上的不透明色（pdf 库填色时只写 RGB、
  /// 丢掉透明度，见 [flattenDiaryColors]）。完全透明与读不懂的颜色在解析
  /// 块时已经去掉（[ExportInline.fromAttributes]）。
  static List<ExportInline> _flattenColors(List<ExportInline> inlines) {
    final result = <ExportInline>[];
    for (final run in inlines) {
      if (run.color == null && run.background == null) {
        result.add(run);
        continue;
      }
      final flat = flattenDiaryColors(
        text: run.color,
        background: run.background,
        paper: _paper,
      );
      result.add(run.copyWith(color: flat.text, background: flat.background));
    }
    return result;
  }

  static void _addImage(List<Uint8List> images, Uint8List bytes) {
    images.add(bytes);
    final total = images.fold<int>(0, (int sum, Uint8List b) => sum + b.length);
    if (total > maxImageBytes) {
      throw DiaryExportTooLargeException(total);
    }
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
