import 'package:flutter/foundation.dart';
import 'package:markdown/markdown.dart' as md;

/// 更新说明的块类型。只覆盖 Release 说明会用到的 Markdown 子集。
enum ReleaseNoteBlockKind { heading, paragraph, listItem, quote, code, rule }

/// 一段行内文字及其样式。
@immutable
class ReleaseNoteSpan {
  const ReleaseNoteSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.link,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;

  /// 链接地址（http/https），其余协议当普通文字。
  final String? link;
}

/// 一个渲染块。
@immutable
class ReleaseNoteBlock {
  const ReleaseNoteBlock(
    this.kind, {
    this.spans = const <ReleaseNoteSpan>[],
    this.level = 0,
    this.marker,
    this.text = '',
  });

  final ReleaseNoteBlockKind kind;
  final List<ReleaseNoteSpan> spans;

  /// 标题级别（1–6），或列表嵌套深度（0 起）。
  final int level;

  /// 列表项标记：有序列表为 `1.`，无序为 null（界面画圆点）。
  final String? marker;

  /// 代码块的原文。
  final String text;

  String get plainText => kind == ReleaseNoteBlockKind.code
      ? text
      : spans.map((span) => span.text).join();
}

/// 把 Markdown（GitHub 风格）解析成扁平的块列表：标题、段落、（嵌套）列表项、
/// 引用、代码块、分隔线；表格每行拼成一段，图片取替代文字。
///
/// 为什么不用 HTML 或通用 Markdown 组件：说明只在更新页与提示面板里出现，
/// 子集很小；扁平块列表便于逐块套用应用自己的字阶与配色，也易于测试。
List<ReleaseNoteBlock> parseReleaseNotes(String markdown) {
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  final nodes = document.parseLines(
    markdown.replaceAll('\r\n', '\n').split('\n'),
  );
  final blocks = <ReleaseNoteBlock>[];
  for (final node in nodes) {
    _collectBlock(node, blocks, listDepth: 0, inQuote: false);
  }
  return blocks
      .where(
        (block) =>
            block.kind == ReleaseNoteBlockKind.rule ||
            block.plainText.trim().isNotEmpty,
      )
      .toList(growable: false);
}

void _collectBlock(
  md.Node node,
  List<ReleaseNoteBlock> out, {
  required int listDepth,
  required bool inQuote,
}) {
  if (node is md.Text) {
    final spans = _inlineSpans(<md.Node>[node]);
    out.add(_textBlock(spans, inQuote: inQuote));
    return;
  }
  if (node is! md.Element) {
    return;
  }
  final tag = node.tag;
  final children = node.children ?? const <md.Node>[];
  final headingLevel = switch (tag) {
    'h1' => 1,
    'h2' => 2,
    'h3' => 3,
    'h4' => 4,
    'h5' => 5,
    'h6' => 6,
    _ => 0,
  };
  if (headingLevel > 0) {
    out.add(
      ReleaseNoteBlock(
        ReleaseNoteBlockKind.heading,
        spans: _inlineSpans(children),
        level: headingLevel,
      ),
    );
    return;
  }
  switch (tag) {
    case 'p':
      out.add(_textBlock(_inlineSpans(children), inQuote: inQuote));
    case 'ul' || 'ol':
      final start = int.tryParse(node.attributes['start'] ?? '') ?? 1;
      var index = 0;
      for (final item in children.whereType<md.Element>()) {
        if (item.tag != 'li') {
          continue;
        }
        _collectListItem(
          item,
          out,
          depth: listDepth,
          marker: tag == 'ol' ? '${start + index}.' : null,
          inQuote: inQuote,
        );
        index++;
      }
    case 'blockquote':
      for (final child in children) {
        _collectBlock(child, out, listDepth: listDepth, inQuote: true);
      }
    case 'pre':
      out.add(
        ReleaseNoteBlock(
          ReleaseNoteBlockKind.code,
          text: node.textContent.replaceAll(RegExp(r'\n+$'), ''),
        ),
      );
    case 'hr':
      out.add(const ReleaseNoteBlock(ReleaseNoteBlockKind.rule));
    case 'table':
      for (final row in _descendants(node, 'tr')) {
        final cells = (row.children ?? const <md.Node>[])
            .map((cell) => cell.textContent.trim())
            .where((text) => text.isNotEmpty)
            .join(' · ');
        out.add(
          _textBlock(<ReleaseNoteSpan>[
            ReleaseNoteSpan(cells),
          ], inQuote: inQuote),
        );
      }
    default:
      out.add(_textBlock(_inlineSpans(children), inQuote: inQuote));
  }
}

/// 列表项：紧凑列表的文字直接挂在 li 下，松散列表包在 p 里；嵌套列表
/// 深度加一。项内第一段文字带标记，后续段落作为同级无标记的续行。
void _collectListItem(
  md.Element item,
  List<ReleaseNoteBlock> out, {
  required int depth,
  required String? marker,
  required bool inQuote,
}) {
  final inline = <md.Node>[];
  var markerUsed = false;

  void flushInline() {
    if (inline.isEmpty) {
      return;
    }
    out.add(
      ReleaseNoteBlock(
        ReleaseNoteBlockKind.listItem,
        spans: _inlineSpans(List<md.Node>.of(inline)),
        level: depth,
        marker: markerUsed ? '' : marker,
      ),
    );
    markerUsed = true;
    inline.clear();
  }

  for (final child in item.children ?? const <md.Node>[]) {
    if (child is md.Element && (child.tag == 'ul' || child.tag == 'ol')) {
      flushInline();
      _collectBlock(child, out, listDepth: depth + 1, inQuote: inQuote);
    } else if (child is md.Element && child.tag == 'p') {
      flushInline();
      inline.addAll(child.children ?? const <md.Node>[]);
      flushInline();
    } else {
      inline.add(child);
    }
  }
  flushInline();
}

ReleaseNoteBlock _textBlock(
  List<ReleaseNoteSpan> spans, {
  required bool inQuote,
}) => ReleaseNoteBlock(
  inQuote ? ReleaseNoteBlockKind.quote : ReleaseNoteBlockKind.paragraph,
  spans: spans,
);

Iterable<md.Element> _descendants(md.Element root, String tag) sync* {
  for (final child in root.children ?? const <md.Node>[]) {
    if (child is md.Element) {
      if (child.tag == tag) {
        yield child;
      }
      yield* _descendants(child, tag);
    }
  }
}

List<ReleaseNoteSpan> _inlineSpans(List<md.Node> nodes) {
  final spans = <ReleaseNoteSpan>[];

  void walk(
    md.Node node, {
    bool bold = false,
    bool italic = false,
    String? link,
  }) {
    if (node is md.Text) {
      if (node.text.isNotEmpty) {
        spans.add(
          ReleaseNoteSpan(node.text, bold: bold, italic: italic, link: link),
        );
      }
      return;
    }
    if (node is! md.Element) {
      return;
    }
    switch (node.tag) {
      case 'code':
        spans.add(ReleaseNoteSpan(node.textContent, code: true, link: link));
        return;
      case 'br':
        spans.add(const ReleaseNoteSpan('\n'));
        return;
      case 'img':
        final alt = node.attributes['alt'] ?? '';
        if (alt.isNotEmpty) {
          spans.add(ReleaseNoteSpan(alt, bold: bold, italic: italic));
        }
        return;
    }
    final href = node.tag == 'a' ? node.attributes['href'] : null;
    final isWebLink =
        href != null &&
        (href.startsWith('https://') || href.startsWith('http://'));
    for (final child in node.children ?? const <md.Node>[]) {
      walk(
        child,
        bold: bold || node.tag == 'strong',
        italic: italic || node.tag == 'em',
        link: isWebLink ? href : link,
      );
    }
  }

  for (final node in nodes) {
    walk(node);
  }
  return spans;
}
