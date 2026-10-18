import 'package:html/parser.dart' as html_parser;

import 'journal_import_cloud_blocks.dart';
import 'journal_import_style.dart';

/// 小米笔记正文的解析结果：块与正文内联引用的附件（文件 ID、是否录音）。
class XiaomiMarkup {
  const XiaomiMarkup(this.blocks, this.media);

  final List<CloudBlock> blocks;
  final List<({String id, bool audio})> media;
}

/// 解析小米笔记正文（`entry.content`），规则逐条对应参考实现（笔记互迁
/// `xiaomi_markup.py`）：
///
/// - 按行组织，只有字面的 `\n` 分段（`<br>`、`<p>` 不换行）；新版正文以
///   `<new-format/>` 开头，忽略；
/// - 行首的空标签是行标记：`<h1/>`~`<h3/>` 标题，`<bullet indent/>`、
///   `<order indent/>` 列表，`<input type="checkbox" [checked="true"]/>`
///   待办（只有字面 `true` 算已完成），`indent` 从 1 开始；
/// - 行内 `<b>`/`<i>`/`<u>`/`<delete>`（删除线）/`<background color>`（高亮，
///   颜色是 Android 的 `#AARRGGBB`）；`<size>`/`<mid-size>`/`<h3-size>` 是
///   大 / 中 / 三级标题三档字号（官方网页版的 large / middle / h3Level，都
///   比正文大），`<center>`/`<right>`/`<left>` 包住整行表示对齐；
///   `<quote>…</quote>` 内每行一个引用块；旧版 `<ul>/<ol>/<li>` 按嵌套
///   深度缩进，`<del>` 表示已完成的旧版待办；
/// - `<img fileid/>`、`<sound fileid/>` 独占一块（之后紧跟的换行只是分隔），
///   `<hr/>` 是分隔线；`<a href>` 的文字作为独立的链接段落放在当前行之后；
/// - 可执行内容（script/style/iframe…）连同内容丢弃，其他未知标签透明。
XiaomiMarkup parseXiaomiMarkup(String content) {
  final parser = _XiaomiParser();
  _tokenize(
    content,
    onStart: parser.start,
    onEnd: parser.end,
    onText: parser.text,
  );
  return parser.finish();
}

class _Mark {
  const _Mark(
    this.tag, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.highlight = false,
    this.background,
    this.size,
    this.align,
    this.alignSet = false,
  });

  final String tag;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool highlight;
  final String? background;
  final String? size;

  /// 行对齐；[alignSet] 为 true 时生效（`<left>` 把对齐设回 null）。
  final String? align;
  final bool alignSet;
}

class _Line {
  _Line(this.kind);

  CloudBlockKind kind;
  int level = 1;
  bool ordered = false;
  bool checked = false;
  String? align;
  final List<CloudSpan> spans = <CloudSpan>[];

  CloudBlock build() => CloudBlock(
    kind,
    spans: List.unmodifiable(spans),
    level: level,
    ordered: ordered,
    checked: checked,
    align: align,
  );
}

class _XiaomiParser {
  final List<CloudBlock> blocks = <CloudBlock>[];
  final List<({String id, bool audio})> media = <({String id, bool audio})>[];
  final List<CloudBlock> _links = <CloudBlock>[];
  final List<_Mark> _marks = <_Mark>[];
  final List<String> _lists = <String>[];
  final List<String> _skip = <String>[];
  int _quoteDepth = 0;
  bool _lineClosed = false;
  ({String? href, StringBuffer text})? _link;
  late _Line _current = _fresh();

  static const Set<String> _active = {
    'script',
    'style',
    'iframe',
    'object',
    'embed',
    'form',
    'button',
    'svg',
    'math',
  };
  static const Set<String> _void = {'br', 'img', 'input', 'hr', 'meta', 'link'};

  _Line _fresh() =>
      _Line(_quoteDepth > 0 ? CloudBlockKind.quote : CloudBlockKind.paragraph);

  void _flush({bool force = false}) {
    final line = _current;
    if ((force && _links.isEmpty) ||
        line.spans.isNotEmpty ||
        (line.kind != CloudBlockKind.paragraph &&
            line.kind != CloudBlockKind.quote)) {
      blocks.add(line.build());
    }
    blocks.addAll(_links);
    _links.clear();
    _current = _fresh();
  }

  void _newline() {
    if (!_lineClosed) _flush(force: true);
    _lineClosed = false;
  }

  static int _level(String? raw) => (int.tryParse(raw ?? '') ?? 1).clamp(1, 6);

  void start(String tag, Map<String, String?> attributes) {
    if (_skip.isNotEmpty) {
      if (!_void.contains(tag)) _skip.add(tag);
      return;
    }
    if (_active.contains(tag)) {
      _skip.add(tag);
      return;
    }
    switch (tag) {
      case 'meta' || 'link' || 'new-format' || 'br':
        return;
      case 'a':
        _link = (href: attributes['href'], text: StringBuffer());
        return;
      case 'img' || 'sound' || 'hr':
        _flush();
        if (tag == 'hr') {
          blocks.add(const CloudBlock(CloudBlockKind.divider));
        } else {
          final id = attributes['fileid'];
          if (id != null && id.isNotEmpty) {
            media.add((id: id, audio: tag == 'sound'));
            blocks.add(CloudBlock(CloudBlockKind.attachment, attachmentId: id));
          }
        }
        _lineClosed = true;
        return;
      case 'input' when attributes['type']?.toLowerCase() != 'checkbox':
        return;
      case 'input' || 'bullet' || 'order' || 'h1' || 'h2' || 'h3':
        _lineClosed = false;
        if (_current.spans.isNotEmpty) _flush();
        if (tag.startsWith('h')) {
          _current
            ..kind = CloudBlockKind.heading
            ..level = int.parse(tag.substring(1));
        } else {
          _current
            ..kind = tag == 'input' ? CloudBlockKind.todo : CloudBlockKind.list
            ..checked = tag == 'input' && attributes['checked'] == 'true'
            ..ordered = tag == 'order'
            ..level = _level(attributes['indent']);
        }
        return;
      case 'quote':
        _flush();
        _quoteDepth++;
        _current = _fresh();
        return;
      case 'ul' || 'ol':
        _flush();
        _lists.add(tag);
        return;
      case 'li':
        _flush();
        _current = _Line(CloudBlockKind.list)
          ..ordered = _lists.isNotEmpty && _lists.last == 'ol'
          ..level = _lists.length.clamp(1, 6);
        return;
      case 'del':
        _current
          ..kind = CloudBlockKind.todo
          ..checked = true;
        _marks.add(const _Mark('del'));
        return;
      case 'b':
        _marks.add(const _Mark('b', bold: true));
      case 'i':
        _marks.add(const _Mark('i', italic: true));
      case 'u':
        _marks.add(const _Mark('u', underline: true));
      case 'delete':
        _marks.add(const _Mark('delete', strike: true));
      case 'background':
        final color = journalBackgroundColor(
          journalArgbToCss(attributes['color']),
        );
        _marks.add(
          _Mark('background', highlight: color == null, background: color),
        );
      case 'size' || 'mid-size' || 'h3-size':
        _marks.add(
          _Mark(
            tag,
            size: switch (tag) {
              'size' => 'huge',
              _ => 'large',
            },
          ),
        );
      case 'center' || 'right' || 'left':
        _marks.add(
          _Mark(tag, align: tag == 'left' ? null : tag, alignSet: true),
        );
      default:
        _marks.add(_Mark(tag));
    }
  }

  void end(String tag) {
    if (_skip.isNotEmpty) {
      final index = _skip.lastIndexOf(tag);
      if (index >= 0) _skip.removeRange(index, _skip.length);
      return;
    }
    if (tag == 'a' && _link != null) {
      _closeLink();
      return;
    }
    if (tag == 'quote') {
      _flush();
      _quoteDepth = _quoteDepth > 0 ? _quoteDepth - 1 : 0;
      _current = _fresh();
      _lineClosed = true;
    } else if (tag == 'ul' || tag == 'ol' || tag == 'li') {
      _flush();
      if (tag != 'li' && _lists.isNotEmpty) _lists.removeLast();
      _lineClosed = true;
    }
    final index = _marks.lastIndexWhere((mark) => mark.tag == tag);
    if (index >= 0) _marks.removeRange(index, _marks.length);
  }

  void text(String data) {
    if (_skip.isNotEmpty) return;
    final link = _link;
    if (link != null) {
      link.text.write(data);
      return;
    }
    // 内层标记覆盖外层：取最后一个声明了背景色 / 字号 / 对齐的标记。
    _Mark? innermost(bool Function(_Mark mark) test) =>
        _marks.reversed.where(test).firstOrNull;
    final background = innermost(
      (mark) => mark.background != null || mark.highlight,
    )?.background;
    final alignMark = innermost((mark) => mark.alignSet);
    final style = CloudSpan(
      '',
      bold: _marks.any((mark) => mark.bold),
      italic: _marks.any((mark) => mark.italic),
      underline: _marks.any((mark) => mark.underline),
      strike: _marks.any((mark) => mark.strike),
      highlight: _marks.any((mark) => mark.highlight) && background == null,
      background: background,
      size: innermost((mark) => mark.size != null)?.size,
    );
    final parts = data.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) _newline();
      final part = parts[i].replaceFirst(RegExp(r'\r$'), '');
      if (part.isEmpty) continue;
      _lineClosed = false;
      if (alignMark != null) _current.align = alignMark.align;
      final spans = _current.spans;
      final last = spans.isEmpty ? null : spans.last;
      if (last != null && last.sameStyle(style)) {
        spans[spans.length - 1] = last.copyWith(text: last.text + part);
      } else {
        spans.add(style.copyWith(text: part));
      }
    }
  }

  void _closeLink() {
    final link = _link!;
    _link = null;
    _links.add(
      CloudBlock.paragraph([CloudSpan(link.text.toString(), link: link.href)]),
    );
  }

  XiaomiMarkup finish() {
    if (_link != null) _closeLink();
    _flush();
    return XiaomiMarkup(List.unmodifiable(blocks), List.unmodifiable(media));
  }
}

final RegExp _tagPattern = RegExp(
  r'<(/?)([a-zA-Z][a-zA-Z0-9:_-]*)'
  r'''((?:\s+[^\s"'>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*)'''
  r'\s*(/?)>',
);
final RegExp _attributePattern = RegExp(
  r'''([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''',
);

/// 与 Python `html.parser`（convert_charrefs）一致的最小分词：标签名与
/// 属性名小写、属性值解码实体、无值属性为 null，`<x/>` 依次触发开始与
/// 结束；注释、DOCTYPE 与处理指令忽略；script/style 内容按原文处理。
void _tokenize(
  String source, {
  required void Function(String tag, Map<String, String?> attributes) onStart,
  required void Function(String tag) onEnd,
  required void Function(String data) onText,
}) {
  var index = 0;
  void text(String value) {
    if (value.isNotEmpty) onText(_decode(value));
  }

  while (index < source.length) {
    final open = source.indexOf('<', index);
    if (open < 0) {
      text(source.substring(index));
      break;
    }
    text(source.substring(index, open));
    if (source.startsWith('<!--', open)) {
      final close = source.indexOf('-->', open + 4);
      index = close < 0 ? source.length : close + 3;
      continue;
    }
    if (source.startsWith('<!', open) || source.startsWith('<?', open)) {
      final close = source.indexOf('>', open);
      index = close < 0 ? source.length : close + 1;
      continue;
    }
    final match = _tagPattern.matchAsPrefix(source, open);
    if (match == null) {
      onText('<');
      index = open + 1;
      continue;
    }
    index = match.end;
    final tag = match.group(2)!.toLowerCase();
    if (match.group(1) == '/') {
      onEnd(tag);
      continue;
    }
    final attributes = <String, String?>{
      for (final attribute in _attributePattern.allMatches(match.group(3)!))
        attribute.group(1)!.toLowerCase(): switch (attribute.group(2) ??
            attribute.group(3) ??
            attribute.group(4)) {
          final String value => _decode(value),
          null => null,
        },
    };
    onStart(tag, attributes);
    if (match.group(4) == '/') {
      onEnd(tag);
    } else if (tag == 'script' || tag == 'style') {
      final close = source.toLowerCase().indexOf('</$tag', index);
      final end = close < 0 ? source.length : close;
      if (end > index) onText(source.substring(index, end));
      index = end;
    }
  }
}

/// 解码字符引用（`&amp;`、`&#x1F600;` 等），未知实体保留原样。
String _decode(String value) => value.contains('&')
    ? (html_parser.parseFragment(value).text ?? value)
    : value;
