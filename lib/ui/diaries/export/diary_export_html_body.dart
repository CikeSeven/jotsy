import 'dart:math' as math;

import '../../../core/database/app_database.dart' show DiaryCommentRowImages;
import '../../../core/database/code_block_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/services/diary_typography.dart';
import '../models/diary_callout_tone.dart';
import 'diary_export_blocks.dart';
import 'diary_export_code.dart';
import 'diary_export_entry.dart';
import 'diary_export_html_markup.dart';

/// 网页与 EPUB 共用的一篇日记：抬头（标题、日期、信息行与标签）、封面、
/// 正文各块与留言区。两种格式的正文写法只有这一份，新增块类型或行内样式
/// 只改这里，EPUB 不会落在网页后面。
///
/// - 语法由 [markup] 决定（网页为 HTML5，EPUB 为 XHTML，见
///   [DiaryHtmlMarkup]）；网页的产物与拆分前逐字节相同。
/// - [images] 是图片来源 → `src`（网页为 data URI 或打包时的相对路径，EPUB
///   为包内相对路径）；不在里面的图片（关掉了图片、文件缺失或格式不支持）
///   不写，留言里没写成图片的几张写成文字占位。
/// - 给了代码配色 [code] 时代码记号写成 `<span class="hl-角色">`，颜色由所在
///   格式的样式表给出；没给时代码块只是等宽文字。
/// - 正文的文字色与背景色写成内联 `style`，按原值带透明度写出；代码里设过
///   文字色的片段保留原色、不取记号色。
/// - 标注写成 `<div class="callout callout-档位">`（图标 + 正文），折叠列表
///   写成默认展开的 `<details open>`（后面缩进更深的块都收进去），表格写成
///   `<table>`（首行为表头时放进 `<thead>`），上下标写成 `<sup>` / `<sub>`，
///   行内字号写成以 em 计的 `font-size`。
/// - 段落对齐、首行缩进与嵌套层级同应用：首行缩进的字数取 [typography]
///   快照（口径见 [ExportBlock.firstLineIndentOf]，写成以 em 计的
///   `text-indent`）；块比所在容器（正文或折叠列表）多出的层级写成左外边距
///   （每级 1.5em，[_nestRule]），列表的层级仍由嵌套的 ul / ol 表达。
class DiaryHtmlBody {
  DiaryHtmlBody({
    required this.markup,
    required this.labels,
    required this.images,
    this.code,
    DiaryTypography typography = const DiaryTypography(),
  }) : _indentRegular = typography.firstLineIndent,
       _indentMarked = math.max(
         typography.firstLineIndent,
         DiaryTypography.paragraphFirstLineIndent,
       );

  final DiaryHtmlMarkup markup;
  final DiaryExportLabels labels;
  final Map<String, String> images;
  final DiaryExportCodeTheme? code;

  /// 首行缩进的字数：正文段落取 [_indentRegular]，带工具栏缩进标记的取
  /// [_indentMarked]。
  final double _indentRegular;
  final double _indentMarked;

  String _text(String value) => markup.text(value);

  String _attr(String value) => markup.attr(value);

  /// 一篇日记；成书时带锚点 [anchor]，标题降为 h[titleLevel]，正文标题顺延。
  /// [includeMeta] 为 false 时不写信息行与标签。
  void writeEntry(
    StringBuffer out,
    DiaryExportEntry entry, {
    required bool includeMeta,
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
    if (includeMeta) {
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
        '<figure class="cover"><img src="${_attr(cover)}" alt=""'
        '${markup.voidEnd}</figure>\n',
      );
    }
    _writeRange(
      out,
      entry,
      0,
      entry.blocks.length,
      codeRuns: code?.highlightBlocks(entry.blocks),
      headingOffset: titleLevel,
    );
    _writeComments(out, entry, level: titleLevel + 1);
    out.write('</article>\n');
  }

  /// 留言区（没有留言时不写）：标题比日记标题低一级，每条留言为一行说明
  /// 加心情与文字；文字按原样换行（`pre-wrap`），不必把换行改写成 `<br>`。
  /// 有格式的留言按正文的行内写法写出（[DiaryExportLabels.commentLines]），
  /// 没有格式的照旧写纯文字。
  /// 留言图片在文字下面排成一行方形缩略图（[images] 里有的，即开启了媒体且
  /// 读得到的），其余在文字里写成占位（[DiaryExportLabels.commentText]）。
  void _writeComments(
    StringBuffer out,
    DiaryExportEntry entry, {
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
      final sources = comment.imagePaths;
      final shown = <String>[for (final source in sources) ?images[source]];
      final text = labels.commentText(
        comment,
        unrenderedImages: sources.length - shown.length,
      );
      out.write(
        '<div class="comment">'
        '<p class="meta">${_text(labels.commentMetaLine(entry, comment))}</p>',
      );
      if (labels.commentHasFormats(comment)) {
        final lines = labels.commentLines(
          comment,
          unrenderedImages: sources.length - shown.length,
        );
        out.write(
          '<p class="comment-text">'
          '${lines.map(markup.inlines).join('\n')}</p>',
        );
      } else if (text.isNotEmpty) {
        out.write('<p class="comment-text">${_text(text)}</p>');
      }
      if (shown.isNotEmpty) {
        out.write('<div class="comment-images">');
        for (final src in shown) {
          out.write('<img src="${_attr(src)}" alt=""${markup.voidEnd}');
        }
        out.write('</div>');
      }
      out.write('</div>\n');
    }
    out.write('</section>\n');
  }

  /// 写出 `entry.blocks[start, end)`。折叠列表把它后面缩进更深的块（它的
  /// 子块）收进自己的 `<details>`，递归写出；列表、引用与代码的分组不越过
  /// [end]，不会从折叠列表里跑出去。[codeRuns] 按整篇的下标给出。[base]
  /// 是所在容器的层级（正文为 0，折叠列表里为它的层级 + 1）：块比它深的
  /// 层级写成左外边距（[_nestRule]）。
  ///
  /// [headingOffset] 是日记标题的级别：正文标题从下一级起。超过 h6 的
  /// 级别（成书时正文标题顺延）仍写 `<h6>`，但带 `h-level-N` 类名与
  /// `aria-level`，样式上比真正的 h6 再弱一级，不与它混成同一级。
  void _writeRange(
    StringBuffer out,
    DiaryExportEntry entry,
    int start,
    int end, {
    required List<List<DiaryExportCodeRun>?>? codeRuns,
    required int headingOffset,
    int base = 0,
  }) {
    final blocks = entry.blocks;
    var i = start;
    while (i < end) {
      final block = blocks[i];
      final nest = _nestRule(block, base);
      if (block.isListItem) {
        final next = _runEnd(blocks, i, end, (ExportBlock b) => b.isListItem);
        _writeList(out, blocks.sublist(i, next), base: base);
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
        out.write('<blockquote${_styleAttr(<String?>[nest])}>');
        for (final line in blocks.sublist(i, next)) {
          out.write('<p${_align(line)}>${markup.inlines(line.inlines)}</p>');
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
                : codeRuns[j]!.map(markup.codeRun).join(),
        ].join('\n');
        // 沿用 highlight.js / Prism 的 `language-*` 约定；纯文本写
        // `language-plaintext`，未指定不写 class（交给阅读端自动识别）。
        final language = switch (block.codeLanguage) {
          null => null,
          kCodeBlockPlain => 'plaintext',
          final id => id,
        };
        final classAttr = language == null ? '' : ' class="language-$language"';
        out.write(
          '<pre${_styleAttr(<String?>[nest])}><code$classAttr>$html</code></pre>\n',
        );
        i = next;
        continue;
      }
      if (block.kind == ExportBlockKind.image && block.imageThumbnail) {
        // 小图一律写成一排（_writeThumbnails）：并排的几张在同一个 figure
        // 里，单独一张（含容器块里的）是只有一张的一排，边长同样随宽度收缩。
        final next = exportThumbnailRowEnd(blocks, i, end);
        _writeThumbnails(
          out,
          blocks.sublist(i, next),
          cover: entry.cover,
          nest: nest,
        );
        i = next;
        continue;
      }
      if (block.kind == ExportBlockKind.toggle) {
        // 导出的文件不保存折叠状态：一律展开，读者仍可点标题收起。
        final close = _runEnd(
          blocks,
          i + 1,
          end,
          (ExportBlock b) => b.indent > block.indent,
        );
        out.write(
          '<details ${markup.flag('open')}${_styleAttr(<String?>[nest])}>'
          '<summary${_align(block)}>'
          '${markup.inlines(block.inlines)}</summary>\n',
        );
        _writeRange(
          out,
          entry,
          i + 1,
          close,
          codeRuns: codeRuns,
          headingOffset: headingOffset,
          base: block.indent + 1,
        );
        out.write('</details>\n');
        i = close;
        continue;
      }
      switch (block.kind) {
        case ExportBlockKind.heading:
          final level = block.level + headingOffset;
          final html = markup.inlines(block.inlines);
          final style = _styleAttr(<String?>[_alignRule(block), nest]);
          out.write(
            level <= 6
                ? '<h$level$style>$html</h$level>\n'
                : '<h6 class="h-level-$level" aria-level="$level"'
                      '$style>$html</h6>\n',
          );
        case ExportBlockKind.image:
          final data = images[block.source!];
          if (data != null && block.source != entry.cover) {
            out.write(
              '<figure${_figureClass(block)}${_styleAttr(<String?>[nest])}>'
              '<img src="${_attr(data)}" '
              'alt=""$_lazy${_imageSize(block)}${markup.voidEnd}</figure>\n',
            );
          }
        case ExportBlockKind.media:
          out.write(
            '<p class="attachment"${_styleAttr(<String?>[nest])}>'
            '${_text(labels.mediaLine(block))}</p>\n',
          );
        case ExportBlockKind.divider:
          out.write('<hr${_styleAttr(<String?>[nest])}${markup.voidEnd}\n');
        case ExportBlockKind.callout:
          final tone = DiaryCalloutTone.fromId(block.calloutTone);
          out.write(
            '<div class="callout callout-${tone.id}"'
            '${_styleAttr(<String?>[nest])}>'
            '<span class="callout-icon">'
            '${_text(block.calloutIcon ?? kDiaryCalloutDefaultIcon)}</span>'
            '<div class="callout-body"${_align(block)}>'
            '${markup.inlines(block.inlines)}</div></div>\n',
          );
        case ExportBlockKind.table:
          _writeTable(out, block, nest: nest);
        default:
          final html = markup.inlines(block.inlines);
          final textIndent = block.firstLineIndentOf(
            regular: _indentRegular,
            marked: _indentMarked,
          );
          out.write(
            html.trim().isEmpty
                ? '<p class="blank"></p>\n'
                : '<p${_styleAttr(<String?>[_alignRule(block), if (textIndent > 0) 'text-indent:${DiaryHtmlMarkup.em(textIndent)}', nest])}>$html</p>\n',
          );
      }
      i++;
    }
  }

  /// 图片的懒加载：网页按需加载；EPUB 不写（阅读器整章排版，没有懒加载，
  /// 旧的校验器也不认这个属性）。
  String get _lazy => markup.xhtml ? '' : ' loading="lazy"';

  /// 一排小图（[exportThumbnailRowEnd] 取出的同一排）：`figure.thumbs` 是一
  /// 行弹性布局，格间 8px，整排按第一张的对齐靠起始侧 / 居中 / 靠右（与应用
  /// 的 `DiaryThumbnailRowView` 一致）。每张 `img.thumb` 的边长与应用同一
  /// 口径：一排三张恰好放下、最大 120px，窄屏上一起收缩、不折行。读不出
  /// 或与封面相同的图片不写，一张都不剩时整排不写。
  void _writeThumbnails(
    StringBuffer out,
    List<ExportBlock> row, {
    required String? cover,
    String? nest,
  }) {
    final shown = <String>[
      for (final block in row)
        if (images[block.source!] case final data? when block.source != cover)
          '<img src="${_attr(data)}" alt=""$_lazy class="thumb"'
              '${markup.voidEnd}',
    ];
    if (shown.isEmpty) return;
    final align = switch (row.first.align) {
      ExportAlign.center => ' thumbs-center',
      ExportAlign.end => ' thumbs-right',
      _ => '',
    };
    out.write(
      '<figure class="thumbs$align"${_styleAttr(<String?>[nest])}>'
      '${shown.join()}</figure>\n',
    );
  }

  /// 表格铺满内容宽度（嵌套时让出左外边距 [nest]）；首行为表头时放进
  /// `<thead>`、用 `<th>`。一格里的几段以换行相连。
  void _writeTable(StringBuffer out, ExportBlock block, {String? nest}) {
    String cell(String tag, List<ExportInline> runs) {
      final paragraphs = ExportBlock.tableCellParagraphs(
        runs,
      ).map(markup.inlines);
      return '<$tag>${paragraphs.join(markup.lineBreak)}</$tag>';
    }

    String row(String tag, List<List<ExportInline>> cells) =>
        '<tr>${cells.map((List<ExportInline> runs) => cell(tag, runs)).join()}</tr>';

    final rows = block.tableRows;
    final header = block.tableHeaderRow && rows.isNotEmpty;
    final margin = nest?.substring('margin-left:'.length);
    out.write(
      '<table${_styleAttr(<String?>[nest, if (margin != null) 'width:calc(100% - $margin)'])}>',
    );
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
  /// [base] 同 [_writeRange]：最外层的列表比它深时整个列表带左外边距。
  void _writeList(StringBuffer out, List<ExportBlock> items, {int base = 0}) {
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
        final outer = stack.isEmpty ? _nestRule(item, base) : null;
        out.write('<$tag$start${_styleAttr(<String?>[outer])}>');
        stack.add((tag: tag, indent: item.indent));
      } else if (itemOpen) {
        out.write('</li>');
      }
      // 待办的方框是只读的复选框；对齐写在 li 上（写在复选框上不起作用）。
      final box = switch (item.kind) {
        ExportBlockKind.checked =>
          '<input type="checkbox" ${markup.flag('disabled')} '
              '${markup.flag('checked')}${markup.voidEnd}',
        ExportBlockKind.unchecked =>
          '<input type="checkbox" ${markup.flag('disabled')}'
              '${markup.voidEnd}',
        _ => null,
      };
      // 列表样式按项写类名（见样式表的 li.ls-*）：无序项与待办共用一个
      // ul，一个 ul 里可能有几段样式不同的列表。
      final styleId = item.orderedStyle?.id ?? item.bulletStyle?.id;
      out.write(
        box == null
            ? '<li${styleId == null ? '' : ' class="ls-$styleId"'}'
                  '${_align(item)}>${markup.inlines(item.inlines)}'
            : '<li class="task"${_align(item)}>$box '
                  '${markup.inlines(item.inlines)}',
      );
      itemOpen = true;
    }
    while (stack.isNotEmpty) {
      out.write('</li></${stack.removeLast().tag}>');
    }
    out.write('\n');
  }

  static String _align(ExportBlock block) =>
      _styleAttr(<String?>[_alignRule(block)]);

  static String? _alignRule(ExportBlock block) => switch (block.align) {
    ExportAlign.center => 'text-align:center',
    ExportAlign.end => 'text-align:right',
    ExportAlign.justify => 'text-align:justify',
    ExportAlign.start => null,
  };

  /// 块比所在容器（[base] 层）多出的层级写成左外边距，每级 1.5em（与
  /// 列表的缩进同一量级）；没有多出时为 null。
  static String? _nestRule(ExportBlock block, int base) => block.indent > base
      ? 'margin-left:${DiaryHtmlMarkup.em((block.indent - base) * 1.5)}'
      : null;

  /// 把几条 CSS 声明合成 style 属性（略过 null）；都没有时为空串。
  static String _styleAttr(List<String?> rules) {
    final kept = rules.nonNulls;
    return kept.isEmpty ? '' : ' style="${kept.join(';')}"';
  }

  /// 正文图片的对齐（figure 的类）：居中 / 靠右经 CSS 的自动外边距
  /// （`figure.align-*`），靠起始侧不写。
  static String _figureClass(ExportBlock block) => switch (block.align) {
    ExportAlign.center => ' class="align-center"',
    ExportAlign.end => ' class="align-right"',
    _ => '',
  };

  /// 正文图片（小图以外，小图见 [_writeThumbnails]）的尺寸，与应用一致
  /// （口径见 `ExportImageBox`）：缩放菜单的宽高只作上限，宽高仍是 auto，
  /// 浏览器在上限内按原比例缩小；都没有时不写。
  static String _imageSize(ExportBlock block) {
    final width = block.imageMaxWidth;
    final height = block.imageMaxHeight;
    final limits = <String>[
      if (width != null) 'max-width:min(100%,${DiaryHtmlMarkup.px(width)})',
      if (height != null) 'max-height:${DiaryHtmlMarkup.px(height)}',
    ];
    return limits.isEmpty ? '' : ' style="${limits.join(';')}"';
  }
}
