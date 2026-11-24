import 'dart:convert';

import '../../../core/database/app_database.dart'
    show DiaryCommentRow, DiaryCommentRowImages;
import '../../../core/services/diary_typography.dart';
import '../models/diary_callout_tone.dart';
import '../models/diary_code_block/diary_code_theme.dart';
import '../models/diary_text_colors.dart';
import 'diary_export_blocks.dart';
import 'diary_export_book.dart';
import 'diary_export_code.dart';
import 'diary_export_entry.dart';
import 'diary_export_format.dart';
import 'diary_export_html_body.dart';
import 'diary_export_html_markup.dart';
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
/// 每篇的抬头、正文各块与留言区由 [DiaryHtmlBody] 写出（与 EPUB 共用，写法
/// 见那里）；这里只管页面骨架、扉页与目录和样式表。
///
/// 导出成书（`book` 不为 null）时，页面开头是扉页（封面、书名、简介、统计行
/// 与导出日期）与目录 `<nav>`（章节与各篇链接到锚点），每章是带
/// `<h1 id="chapter-n">` 的 `<section>`，每篇 `<article id="entry-n">` 的标题
/// 降为 h2、正文标题顺延到 h3 起；打印时扉页、目录与每章各自另起一页。封面
/// 与日记图片走同一条媒体链路（单篇内嵌、多篇打包），不写设备路径。
///
/// 给了代码配色（[DiaryExportCodeTheme]）且正文里有代码块时，记号的颜色是
/// CSS 变量：浅色模式用纸面配色，深色模式换成深色那套（固定明暗时只有一
/// 套）；代码块的底色与正文字色同样取配色。
///
/// 正文的文字色与背景色按原值带透明度写出：半透明背景叠在卡片上，与应用里
/// 叠在纸面上一样；亮暗模式都不换色，也与应用一致。
///
/// 标注、折叠列表与表格的样式（[_blocksCss]）只在正文里有这几种块时写出，
/// 留言区的样式只在有留言时写出。
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
    DiaryTypography typography = const DiaryTypography(),
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
    // 留言图片的样式只在真有一张写成图片时才写（不带媒体、文件缺失时
    // 只有文字占位）。
    final hasCommentImages = entries.any(
      (DiaryExportEntry entry) => entry.comments.any(
        (DiaryCommentRow comment) => comment.imagePaths.any(images.containsKey),
      ),
    );

    const markup = DiaryHtmlMarkup.html;
    final body = DiaryHtmlBody(
      markup: markup,
      labels: labels,
      images: images,
      code: codeTheme,
      typography: typography,
    );
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
        '${typography.panguSpacing ? _panguCss : ''}'
        '${book == null ? '' : _bookCss}'
        '${hasRichBlocks ? _blocksCss() : ''}'
        '${hasComments ? _commentsCss : ''}'
        '${hasCommentImages ? _commentImagesCss : ''}</style>\n',
      )
      ..write('</head>\n<body>\n<main>\n');
    if (book != null) {
      _writeBook(out, book, options: options, labels: labels, body: body);
    } else {
      for (final entry in entries) {
        body.writeEntry(out, entry, includeMeta: options.includeMeta);
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
    required DiaryHtmlBody body,
  }) {
    out.write('<section class="book-title">\n');
    final cover = book.coverPath == null ? null : body.images[book.coverPath!];
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
        body.writeEntry(
          out,
          entry,
          includeMeta: options.includeMeta,
          anchor: book.anchorOf(entry),
          titleLevel: 2,
        );
      }
      out.write('</section>\n');
    }
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
    return 'body{font-family:${fontFamilies.map(DiaryHtmlMarkup.cssString).join(',')},'
        '$_fontStack}\n';
  }

  /// 盘古之白（CSS Text Level 4 `text-autospace`）：只在排版开启时写出，
  /// 代码块与行内代码保持原样。
  static const String _panguCss =
      'body{text-autospace:normal}pre,code{text-autospace:no-autospace}\n';

  static String _text(String value) => DiaryHtmlMarkup.html.text(value);

  static String _attr(String value) => DiaryHtmlMarkup.html.attr(value);

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
figure.align-center img{margin-left:auto;margin-right:auto}
figure.align-right img{margin-left:auto}
hr{margin:16px 0;border:0;border-top:1px solid var(--line)}
img{display:block;max-width:100%;height:auto;border-radius:16px}
figure.thumbs{display:flex;gap:8px}
figure.thumbs-center{justify-content:center}
figure.thumbs-right{justify-content:flex-end}
img.thumb{flex:none;width:calc((100% - 16px) / 3);max-width:120px;height:auto;aspect-ratio:1;object-fit:cover;border-radius:12px}
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
        '.callout-${tone.id}{background:${DiaryHtmlMarkup.cssColor(tone.paperBackground)};'
        'border-left-color:${DiaryHtmlMarkup.cssColor(tone.paperAccent)}}\n',
      );
      final tint = tone.darkAccent.withValues(alpha: kDiaryCalloutDarkTint);
      dark.write(
        '.callout-${tone.id}{background:${DiaryHtmlMarkup.cssColor(tint)};'
        'border-left-color:${DiaryHtmlMarkup.cssColor(tone.darkAccent)}}',
      );
    }
    return '.callout{display:flex;gap:10px;margin:8px 0;padding:10px 14px;'
        'border-left:3px solid;border-radius:6px}\n'
        '.callout-icon{flex:none}\n'
        '.callout-body{flex:1;min-width:0}\n'
        // 子块的缩进放在 details 的内边距上：更深的子块再带自己的左外
        // 边距（_nestRule），不会被这里覆盖。
        'details{margin:4px 0;padding-left:1.4em}\n'
        'details>summary{cursor:pointer;margin-left:-1.4em}\n'
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
  static const String _commentImagesCss = '''
.comment-images{display:flex;flex-wrap:wrap;gap:4px;margin-top:6px}
.comment-images img{width:112px;height:112px;object-fit:cover;border-radius:10px;margin:0}
''';

  static const String _commentsCss = '''
.comments{margin-top:20px;padding-top:12px;border-top:1px solid var(--line)}
.comments>h2,.comments>h3{margin:0 0 8px;font-size:16px;line-height:1.4;color:var(--muted)}
.comment{margin:0 0 12px}
.comment:last-child{margin-bottom:0}
.comment-text{white-space:pre-wrap}
''';
}
