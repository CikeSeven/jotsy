import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../database/code_block_codec.dart';
import '../database/divider_embed_codec.dart';
import '../database/diary_blocks/diary_blocks_walk.dart';
import 'journal_import_block_writer.dart';
import 'journal_import_blocks.dart';
import 'journal_import_html_style.dart';
import 'journal_import_html_table.dart';
import 'journal_import_style.dart';

/// 粗略判断导出正文是不是 HTML（Journey、Daylio 等的旧版本存纯文本）。
bool looksLikeJournalHtml(String text) => RegExp(
  r'<(p|div|br|span|b|i|u|s|strong|em|ul|ol|li|h[1-6]|blockquote|pre|a|img|hr|table|video|audio)\b[^>]*>',
  caseSensitive: false,
).hasMatch(text);

/// 把其他日记应用导出的 HTML 正文写入 [JournalBlockWriter]。
///
/// 保留本应用正文能渲染的格式：粗体、斜体、下划线、删除线、行内代码、链接、
/// 文字颜色与背景色（`color` / `background-color`、`<font color>`、`<mark>`）、
/// 字号（`font-size`、`<font size>`、`<big>` / `<small>`，换算成三档）、上下标
/// （`<sup>` / `<sub>`）、标题（1~6 级）、有序/无序/待办列表与缩进、引用、
/// 代码块、段落对齐（`text-align`、`align` 属性、`<center>`）、分隔线
/// （`<hr>`）、折叠列表（带 `<summary>` 的 `<details>`）与规整的表格（规则
/// 见 [_appendTable]，不规整的表格按格写成文字）。颜色、字号与
/// 对齐的换算规则见 journal_import_style.dart（来源的默认墨色不导入，全文
/// 占比最大的字号视为正文字号）；字体一律丢弃，正文字体只跟随本应用的排版
/// 设置。
///
/// 空白按 HTML 规则合并；空的 `<p></p>` 保留为空行（Journey 用它表示段间
/// 空行），`<br>` 结束当前行。`<img>`、`<video>`、`<audio>` 经 [resolveEmbed]
/// 转为本应用的媒体嵌入，无法解析的本地引用被丢弃，http(s) 图片保留原地址；
/// 图片所在段落的对齐写在图片行上。
class JournalHtmlConverter {
  JournalHtmlConverter(this.writer, {this.resolveEmbed, this.resolveLink});

  final JournalBlockWriter writer;
  final JournalEmbedResolver? resolveEmbed;
  final JournalEmbedResolver? resolveLink;

  /// 本次转换的正文字号（见 journalDominantFontSizeRatio）。
  double _baseRatio = 1;

  /// 正在按格展开成文字的表格层数：不规整的表格里嵌套的表格同样展开，
  /// 不在文字中间冒出表格块。
  int _flatteningTables = 0;

  void appendHtml(String html) {
    appendNodes(html_parser.parseFragment(html).nodes);
  }

  void appendNodes(Iterable<dom.Node> nodes) {
    final list = nodes.toList();
    _baseRatio = journalDominantFontSizeRatio(list);
    const block = _Block();
    for (final node in list) {
      _visit(node, const <String, Object?>{}, block);
    }
    writer.closeLine();
  }

  void _visitChildren(
    dom.Node node,
    Map<String, Object?> inline,
    _Block block,
  ) {
    for (final child in node.nodes) {
      _visit(child, inline, block);
    }
  }

  void _visit(dom.Node node, Map<String, Object?> inline, _Block block) {
    if (node is dom.Text) {
      _text(node.text, inline, block);
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName ?? '';
    switch (tag) {
      case 'script' ||
          'style' ||
          'head' ||
          'title' ||
          'meta' ||
          'link' ||
          'noscript' ||
          'template' ||
          'svg' ||
          'button' ||
          'select' ||
          'input':
        return;
      case 'br':
        writer.endLine(block.attributes);
      case 'hr':
        writer.embed(diaryDividerEmbed, block.attributes);
      case 'img':
        _embed(node.attributes['src'], block, keepRemoteImage: true);
      case 'video' || 'audio':
        _embed(
          node.attributes['src'] ??
              node
                  .getElementsByTagName('source')
                  .map((source) => source.attributes['src'])
                  .nonNulls
                  .firstOrNull,
          block,
        );
      case 'b' || 'strong':
        _visitChildren(node, {..._styled(node, inline), 'bold': true}, block);
      case 'i' || 'em' || 'cite' || 'dfn':
        _visitChildren(node, {..._styled(node, inline), 'italic': true}, block);
      case 'u' || 'ins':
        _visitChildren(node, {
          ..._styled(node, inline),
          'underline': true,
        }, block);
      case 's' || 'strike' || 'del':
        _visitChildren(node, {..._styled(node, inline), 'strike': true}, block);
      case 'code' || 'kbd' || 'samp' || 'tt':
        _visitChildren(
          node,
          block.preformatted ? inline : {...inline, 'code': true},
          block,
        );
      case 'a':
        final href = node.attributes['href']?.trim();
        final styled = _styled(node, inline);
        final attachment =
            href == null ||
                RegExp(
                  r'^(https?|mailto):',
                  caseSensitive: false,
                ).hasMatch(href)
            ? null
            : resolveLink?.call(href);
        if (attachment != null) {
          writer.embed(attachment, block.attributes);
          return;
        }
        _visitChildren(
          node,
          href != null &&
                  RegExp(
                    r'^(https?|mailto):',
                    caseSensitive: false,
                  ).hasMatch(href)
              ? {...styled, 'link': href}
              : styled,
          block,
        );
      case 'span' || 'font' || 'mark' || 'big' || 'small' || 'sup' || 'sub':
        _visitChildren(node, _styled(node, inline), block);
      case 'ul' || 'ol':
        _visitBlock(
          node,
          inline,
          block,
          block.list(tag == 'ol' ? 'ordered' : 'bullet'),
        );
      case 'li':
        _visitBlock(
          node,
          _styled(node, inline),
          block,
          _aligned(node, block).listItem(_checkState(node)),
        );
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final level = int.parse(tag.substring(1));
        _visitBlock(
          node,
          _styled(node, inline),
          block,
          _aligned(node, block).withAttribute('header', level),
        );
      case 'blockquote':
        _visitBlock(
          node,
          _styled(node, inline),
          block,
          _aligned(node, block).withAttribute('blockquote', true),
        );
      case 'pre':
        _visitBlock(
          node,
          inline,
          block,
          block.preformattedBlock(_preLanguage(node)),
        );
      case 'details':
        final summary = node.children
            .where((dom.Element child) => child.localName == 'summary')
            .firstOrNull;
        if (summary == null) {
          // 没有标题的 <details> 无从折叠，与 <div> 一样展开。
          _visitBlock(
            node,
            _styled(node, inline),
            block,
            _aligned(node, block),
          );
        } else {
          _appendDetails(node, summary, inline, block);
        }
      case 'table':
        if (_flatteningTables > 0 || !_appendTable(node, inline, block)) {
          _flatteningTables++;
          _visitBlock(
            node,
            _styled(node, inline),
            block,
            _aligned(node, block),
          );
          _flatteningTables--;
        }
      case 'td' || 'th':
        _visitChildren(node, inline, block);
        writer.text(' ', inline);
      case 'p':
        _visitBlock(
          node,
          _styled(node, inline),
          block,
          _aligned(node, block),
          blankWhenEmpty: true,
        );
      case 'div' ||
          'section' ||
          'article' ||
          'header' ||
          'footer' ||
          'main' ||
          'aside' ||
          'nav' ||
          'figure' ||
          'figcaption' ||
          'address' ||
          'center' ||
          'dl' ||
          'dt' ||
          'dd' ||
          'thead' ||
          'tbody' ||
          'tfoot' ||
          'tr' ||
          'form' ||
          'fieldset' ||
          'summary' ||
          'body' ||
          'html':
        _visitBlock(node, _styled(node, inline), block, _aligned(node, block));
      default:
        _visitChildren(node, inline, block);
    }
  }

  /// 块元素：开始前把父块里未结束的文本按父块格式收尾（如 `<li>二<ul>` 中
  /// 的“二”），结束时按本块格式收尾。只有 `<p>` 在完全没有产出时补一个空行。
  void _visitBlock(
    dom.Element element,
    Map<String, Object?> inline,
    _Block parent,
    _Block block, {
    bool blankWhenEmpty = false,
  }) {
    writer.closeLine(parent.attributes);
    final before = writer.lineCount;
    _visitChildren(element, inline, block);
    if (writer.lineHasContent) {
      writer.endLine(block.attributes);
    } else {
      writer.closeLine();
      if (blankWhenEmpty && writer.lineCount == before) {
        writer.endLine(block.attributes);
      }
    }
  }

  /// 带 `<summary>` 的 `<details>`：标题写成折叠列表的标题行（没有 `open`
  /// 属性时收起），其余内容写成它的子块（缩进多一级，内部的列表照常
  /// 嵌套）。折叠列表与外层块同级：在列表项里时与列表项并列，不挂到它
  /// 下面（`<li>` 后面紧跟 `<details>` 时没有可挂的父行）。
  void _appendDetails(
    dom.Element details,
    dom.Element summary,
    Map<String, Object?> inline,
    _Block block,
  ) {
    final styled = _styled(details, inline);
    final toggle = _aligned(
      details,
      block,
    ).toggle(collapsed: !details.attributes.containsKey('open'));
    _visitBlock(
      summary,
      _styled(summary, styled),
      block,
      _aligned(summary, toggle),
      blankWhenEmpty: true,
    );
    final content = toggle.toggleContent();
    for (final child in details.nodes) {
      if (identical(child, summary)) continue;
      _visit(child, styled, content);
    }
    if (writer.lineHasContent) {
      writer.endLine(content.attributes);
    } else {
      writer.closeLine();
    }
  }

  /// 规整的表格写成表格块，写出时返回 true；不规整时什么都不写、返回
  /// false，由调用方照旧按格展开成文字。规整即：
  /// - 行只来自 `<thead>` / `<tbody>` / `<tfoot>` / `<tr>`（`<colgroup>` 忽略），
  ///   格子只有 `<td>` / `<th>`，中间不夹文字、`<caption>` 或别的元素；
  /// - 没有 `rowspan` / `colspan` 大于 1 的格子，每行格数相同，行列数在
  ///   上限内（[journalImportTableFits]）；
  /// - 格子里只有行内格式、`<br>` 与 `<p>`（没有图片、列表、嵌套表格等
  ///   块级结构），也不含要经解析器换成媒体或附件的引用（解析器可能有
  ///   副作用，试写时一律不调用，遇到即按不规整处理）。
  /// 首行在 `<thead>` 里或全是 `<th>` 时首行为表头。格子的对齐写在格内
  /// 段落上，行内格式照常保留。
  bool _appendTable(
    dom.Element table,
    Map<String, Object?> inline,
    _Block block,
  ) {
    final parsed = journalHtmlTableRows(table);
    if (parsed == null) return false;
    final rows = parsed.rows;
    final cols = rows.first.length;
    if (!journalImportTableFits(rows.length, cols) ||
        rows.any((row) => row.length != cols)) {
      return false;
    }
    var trapped = false;
    Map<String, Object?>? trap(String _) {
      trapped = true;
      return null;
    }

    final tableInline = _styled(table, inline);
    final cells = <List<List<Map<String, Object?>>>>[];
    for (final row in rows) {
      final rowInline = _styled(row.first.parent!, tableInline);
      final rowBlock = _aligned(row.first.parent!, const _Block());
      final cellRow = <List<Map<String, Object?>>>[];
      for (final cell in row) {
        if (!journalHtmlCellIsInline(cell)) return false;
        final sub = JournalBlockWriter();
        final converter = JournalHtmlConverter(
          sub,
          resolveEmbed: trap,
          resolveLink: trap,
        ).._baseRatio = _baseRatio;
        converter._visitBlock(
          cell,
          converter._styled(cell, rowInline),
          const _Block(),
          _aligned(cell, rowBlock),
        );
        final body = diaryBlockChildren(diaryBlocksRoot(sub.buildDocument())!);
        if (trapped || !journalImportCellIsInline(body)) return false;
        cellRow.add(body);
      }
      cells.add(cellRow);
    }
    writer.node(
      journalImportTableNode(cells, headerRow: parsed.headerRow),
      block.attributes,
    );
    return true;
  }

  void _text(String raw, Map<String, Object?> inline, _Block block) {
    if (block.preformatted) {
      final lines = raw.replaceAll('\r\n', '\n').split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (i > 0) writer.endLine(block.attributes);
        writer.text(lines[i], inline);
      }
      return;
    }
    var text = raw
        .replaceAll(RegExp(r'[ \t\r\n\f]+'), ' ')
        .replaceAll('\u00a0', ' ');
    // 相邻文本节点各自带一个空白时只保留一个，与浏览器的空白合并一致。
    if (text.startsWith(' ') && writer.endsWithSpace) {
      text = text.substring(1);
    }
    writer.text(text, inline);
  }

  void _embed(String? source, _Block block, {bool keepRemoteImage = false}) {
    final src = source?.trim();
    if (src == null || src.isEmpty) return;
    final data =
        resolveEmbed?.call(src) ??
        (keepRemoteImage &&
                RegExp(r'^https?://', caseSensitive: false).hasMatch(src)
            ? <String, Object?>{'image': src}
            : null);
    if (data == null) return;
    final align = block.attributes['align'];
    writer.embed(data, block.attributes, {
      if (align != null && data.containsKey('image')) 'align': align,
    });
  }

  Map<String, Object?> _styled(
    dom.Element element,
    Map<String, Object?> inline,
  ) => journalHtmlInlineStyle(element, inline, baseRatio: _baseRatio);

  /// 块元素自身的对齐：`<center>`、`text-align`、`align` 属性；显式左对齐
  /// 会取消外层继承的对齐，没有声明时沿用外层。
  static _Block _aligned(dom.Element element, _Block block) {
    if (element.localName == 'center') return block.aligned('center');
    final raw =
        journalStyleValue(element.attributes['style'], 'text-align') ??
        element.attributes['align'];
    return raw == null ? block : block.aligned(journalAlign(raw));
  }

  /// 待办项：`data-checked` 属性或内含复选框；不是待办时返回 null。
  static bool? _checkState(dom.Element item) {
    final dataChecked = item.attributes['data-checked'];
    if (dataChecked != null) return dataChecked == 'true';
    for (final input in item.getElementsByTagName('input')) {
      if (input.attributes['type']?.toLowerCase() == 'checkbox') {
        return input.attributes.containsKey('checked');
      }
    }
    return null;
  }

  /// `<pre>` 的代码语言，作为 `code-block` 的值：依次看 `<pre>` 与它的
  /// 第一个 `<code>` 子元素上的 `language-*` / `lang-*` class（highlight.js、
  /// Prism 与多数 Markdown 渲染器的约定）和 `data-lang` / `data-language`
  /// 属性，经 [normalizeCodeLanguageTag] 规整；都没有或认不出时为 true。
  static Object _preLanguage(dom.Element pre) {
    final code = pre.children
        .where((dom.Element child) => child.localName == 'code')
        .firstOrNull;
    for (final element in [pre, ?code]) {
      final candidates = <String?>[
        for (final token in element.classes)
          if (token.startsWith('language-'))
            token.substring('language-'.length)
          else if (token.startsWith('lang-'))
            token.substring('lang-'.length),
        element.attributes['data-lang'],
        element.attributes['data-language'],
      ];
      for (final candidate in candidates) {
        final language = normalizeCodeLanguageTag(candidate);
        if (language != null) return language;
      }
    }
    return true;
  }
}

/// 块级上下文：当前行要带的块属性，以及列表嵌套信息。
class _Block {
  const _Block({
    this.attributes = const <String, Object?>{},
    this.listType,
    this.listDepth = -1,
    this.preformatted = false,
    this.indentBase = 0,
  });

  final Map<String, Object?> attributes;

  /// 所在列表（`ul`/`ol`）的类型，不在列表中为 null。
  final String? listType;

  /// 列表嵌套深度，最外层列表为 0。
  final int listDepth;
  final bool preformatted;

  /// 所在折叠列表内容的层级（不在折叠列表里为 0）：这里的行至少缩进这么
  /// 多级，列表项在此基础上再按嵌套深度缩进。
  final int indentBase;

  /// 本块的行缩进层级。
  int get _indent => switch (attributes['indent']) {
    final int indent when indent > 0 => indent,
    _ => 0,
  };

  _Block withAttribute(String key, Object value) => _Block(
    attributes: {...attributes, key: value},
    listType: listType,
    listDepth: listDepth,
    preformatted: preformatted,
    indentBase: indentBase,
  );

  _Block list(String type) => _Block(
    attributes: attributes,
    listType: type,
    listDepth: listDepth + 1,
    preformatted: preformatted,
    indentBase: indentBase,
  );

  _Block listItem(bool? checked) {
    final type = listType ?? 'bullet';
    final level = indentBase + (listDepth < 0 ? 0 : listDepth);
    return _Block(
      attributes: {
        for (final entry in attributes.entries)
          if (entry.key != 'indent') entry.key: entry.value,
        'list': checked == null
            ? type
            : checked
            ? 'checked'
            : 'unchecked',
        if (level > 0) 'indent': level,
      },
      listType: listType,
      listDepth: listDepth < 0 ? 0 : listDepth,
      preformatted: preformatted,
      indentBase: indentBase,
    );
  }

  /// 折叠列表的标题行：与本块同级，不带列表、标题、引用与代码块格式，
  /// 保留对齐。
  _Block toggle({required bool collapsed}) => _Block(
    attributes: {
      'toggle': true,
      'collapsed': collapsed,
      'align': ?attributes['align'],
      if (_indent > 0) 'indent': _indent,
    },
    indentBase: _indent,
  );

  /// 折叠列表（本块为它的标题行）的内容：缩进比标题多一级，重新开始
  /// 列表嵌套，沿用标题的对齐。
  _Block toggleContent() => _Block(
    attributes: {'align': ?attributes['align'], 'indent': _indent + 1},
    indentBase: _indent + 1,
  );

  /// 设置（[align] 为 null 时取消）行对齐。
  _Block aligned(String? align) => _Block(
    attributes: {
      for (final entry in attributes.entries)
        if (entry.key != 'align') entry.key: entry.value,
      'align': ?align,
    },
    listType: listType,
    listDepth: listDepth,
    preformatted: preformatted,
    indentBase: indentBase,
  );

  /// 代码块不带对齐：编辑器里代码块按原样左对齐显示。[codeBlock] 为
  /// `code-block` 的值（语言 id、`plain` 或 true）。
  _Block preformattedBlock([Object codeBlock = true]) => _Block(
    attributes: {
      for (final entry in attributes.entries)
        if (entry.key != 'align') entry.key: entry.value,
      'code-block': codeBlock,
    },
    listType: listType,
    listDepth: listDepth,
    preformatted: true,
    indentBase: indentBase,
  );
}
