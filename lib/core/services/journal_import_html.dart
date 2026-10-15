import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'journal_import_delta_writer.dart';

/// 粗略判断导出正文是不是 HTML（Journey、Daylio 等的旧版本存纯文本）。
bool looksLikeJournalHtml(String text) => RegExp(
  r'<(p|div|br|span|b|i|u|s|strong|em|ul|ol|li|h[1-6]|blockquote|pre|a|img)\b[^>]*>',
  caseSensitive: false,
).hasMatch(text);

/// 把其他日记应用导出的 HTML 正文写入 [JournalDeltaWriter]。
///
/// 只保留本应用编辑器能编辑的格式：粗体、斜体、下划线、删除线、行内代码、
/// 链接、标题（最多三级）、有序/无序/待办列表与缩进、引用、代码块。颜色、
/// 字号、字体、对齐等样式一律丢弃，避免导入后出现无法在编辑器里修改的格式。
///
/// 空白按 HTML 规则合并；空的 `<p></p>` 保留为空行（Journey 用它表示段间
/// 空行），`<br>` 结束当前行。`<img>`、`<video>`、`<audio>` 经 [resolveEmbed]
/// 转为本应用的媒体嵌入，无法解析的本地引用被丢弃，http(s) 图片保留原地址。
class JournalHtmlConverter {
  JournalHtmlConverter(this.writer, {this.resolveEmbed});

  final JournalDeltaWriter writer;
  final JournalEmbedResolver? resolveEmbed;

  void appendHtml(String html) {
    appendNodes(html_parser.parseFragment(html).nodes);
  }

  void appendNodes(Iterable<dom.Node> nodes) {
    const block = _Block();
    for (final node in nodes) {
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
        writer.closeLine(block.attributes);
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
        _visitChildren(node, {...inline, 'bold': true}, block);
      case 'i' || 'em' || 'cite' || 'dfn':
        _visitChildren(node, {...inline, 'italic': true}, block);
      case 'u' || 'ins':
        _visitChildren(node, {...inline, 'underline': true}, block);
      case 's' || 'strike' || 'del':
        _visitChildren(node, {...inline, 'strike': true}, block);
      case 'code' || 'kbd' || 'samp' || 'tt':
        _visitChildren(
          node,
          block.preformatted ? inline : {...inline, 'code': true},
          block,
        );
      case 'a':
        final href = node.attributes['href']?.trim();
        _visitChildren(
          node,
          href != null &&
                  RegExp(
                    r'^(https?|mailto):',
                    caseSensitive: false,
                  ).hasMatch(href)
              ? {...inline, 'link': href}
              : inline,
          block,
        );
      case 'span' || 'font':
        _visitChildren(node, _styled(node, inline), block);
      case 'ul' || 'ol':
        _visitBlock(
          node,
          inline,
          block,
          block.list(tag == 'ol' ? 'ordered' : 'bullet'),
        );
      case 'li':
        _visitBlock(node, inline, block, block.listItem(_checkState(node)));
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final level = int.parse(tag.substring(1));
        _visitBlock(
          node,
          inline,
          block,
          block.withAttribute('header', level > 3 ? 3 : level),
        );
      case 'blockquote':
        _visitBlock(
          node,
          inline,
          block,
          block.withAttribute('blockquote', true),
        );
      case 'pre':
        _visitBlock(node, inline, block, block.preformattedBlock());
      case 'td' || 'th':
        _visitChildren(node, inline, block);
        writer.text(' ', inline);
      case 'p':
        _visitBlock(node, inline, block, block, blankWhenEmpty: true);
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
          'table' ||
          'thead' ||
          'tbody' ||
          'tfoot' ||
          'tr' ||
          'form' ||
          'fieldset' ||
          'details' ||
          'summary' ||
          'body' ||
          'html':
        _visitBlock(node, inline, block, block);
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
    if (data != null) writer.embed(data, block.attributes);
  }

  /// 读取内联 style 中能映射到编辑器格式的部分。
  static Map<String, Object?> _styled(
    dom.Element element,
    Map<String, Object?> inline,
  ) {
    final style = (element.attributes['style'] ?? '').toLowerCase();
    if (style.isEmpty) return inline;
    return {
      ...inline,
      if (RegExp(r'font-weight\s*:\s*(bold|[6-9]00)').hasMatch(style))
        'bold': true,
      if (RegExp(r'font-style\s*:\s*italic').hasMatch(style)) 'italic': true,
      if (RegExp(r'text-decoration[^;]*underline').hasMatch(style))
        'underline': true,
      if (RegExp(r'text-decoration[^;]*line-through').hasMatch(style))
        'strike': true,
    };
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
}

/// 块级上下文：当前行要带的块属性，以及列表嵌套信息。
class _Block {
  const _Block({
    this.attributes = const <String, Object?>{},
    this.listType,
    this.listDepth = -1,
    this.preformatted = false,
  });

  final Map<String, Object?> attributes;

  /// 所在列表（`ul`/`ol`）的类型，不在列表中为 null。
  final String? listType;

  /// 列表嵌套深度，最外层列表为 0。
  final int listDepth;
  final bool preformatted;

  _Block withAttribute(String key, Object value) => _Block(
    attributes: {...attributes, key: value},
    listType: listType,
    listDepth: listDepth,
    preformatted: preformatted,
  );

  _Block list(String type) => _Block(
    attributes: attributes,
    listType: type,
    listDepth: listDepth + 1,
    preformatted: preformatted,
  );

  _Block listItem(bool? checked) {
    final type = listType ?? 'bullet';
    return _Block(
      attributes: {
        ...attributes,
        'list': checked == null
            ? type
            : checked
            ? 'checked'
            : 'unchecked',
        if (listDepth > 0) 'indent': listDepth,
      },
      listType: listType,
      listDepth: listDepth < 0 ? 0 : listDepth,
      preformatted: preformatted,
    );
  }

  _Block preformattedBlock() => _Block(
    attributes: {...attributes, 'code-block': true},
    listType: listType,
    listDepth: listDepth,
    preformatted: true,
  );
}
