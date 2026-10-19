import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;

import '../database/divider_embed_codec.dart';
import 'journal_import_delta_writer.dart';
import 'journal_import_html_style.dart';
import 'journal_import_markdown_references.dart';

/// 把 Markdown 正文（Day One、旧版 Journey、笔记应用导出）写入
/// [JournalDeltaWriter]。
///
/// 日记应用里每个换行都是用户敲下的换行，所以按“源文本一行 = 正文一行”
/// 处理，不套用 Markdown 的段落合并规则（那会把相邻两行拼成一段）。块级
/// 语法（标题、列表、待办、引用、代码围栏、分隔线）逐行识别，分隔线写成
/// 分隔线嵌入；行内语法
/// （粗体、斜体、删除线、行内代码、链接、图片、转义字符）交给 markdown
/// 包解析，图片经 [resolveEmbed] 转为本应用的媒体嵌入。
///
/// [inlineHtml] 为 true 时识别行内 HTML 标签：Joplin、Obsidian、Bear 等
/// 用 `<u>`、`<strong>`、`<span style="color:…">`、`<font color>`、`<mark>`、
/// `<img src>`、`<audio src>`、`<hr>` 表达 Markdown 写不出的格式与媒体，这些
/// 来源的阅读器会渲染 HTML，未知标签因此直接丢弃；Day One
/// 等纯文本来源保持关闭，`<` 开头的文字原样保留。[resolveLink] 把指向本地
/// 文件的链接（如 `[说明书.pdf](resources/…)`）转为附件嵌入，返回 null 时
/// 保留链接文字。
class JournalMarkdownConverter {
  JournalMarkdownConverter(
    this.writer, {
    this.resolveEmbed,
    this.resolveLink,
    this.inlineHtml = false,
  }) : _inlineParser = md.Document(
         encodeHtml: false,
         extensionSet: md.ExtensionSet.none,
         inlineSyntaxes: [
           md.StrikethroughSyntax(),
           md.AutolinkExtensionSyntax(),
           if (inlineHtml) _HtmlTagSyntax(),
         ],
       );

  final JournalDeltaWriter writer;
  final JournalEmbedResolver? resolveEmbed;
  final JournalEmbedResolver? resolveLink;
  final bool inlineHtml;
  final md.Document _inlineParser;

  /// 当前行内尚未闭合的 HTML 格式标签（属性 → 层数），每行开始时清空：
  /// 来源里的标签不跨行配对，残留的开标签不能把格式带到下一行。
  final Map<String, int> _htmlFormats = <String, int>{};

  /// 当前行内尚未闭合、带值的 HTML 格式（颜色、背景、字号），按开标签顺序
  /// 排列，内层覆盖外层；同样每行开始时清空。
  final List<({String name, Map<String, Object?> style})> _htmlStyles =
      <({String name, Map<String, Object?> style})>[];

  /// 列表各级的缩进宽度，用于把任意缩进风格（2/4 空格、Tab）换算成层级。
  final List<int> _listIndents = <int>[];

  static final RegExp _fence = RegExp(r'^\s*(`{3,}|~{3,})');
  static final RegExp _heading = RegExp(r'^ {0,3}(#{1,6})\s+(.*?)(\s+#+)?\s*$');
  static final RegExp _rule = RegExp(r'^ {0,3}([-*_])(\s*\1){2,}\s*$');
  static final RegExp _quote = RegExp(r'^ {0,3}>\s?(.*)$');
  static final RegExp _task = RegExp(r'^(\s*)[-*+]\s+\[([ xX])\]\s+(.*)$');
  static final RegExp _bullet = RegExp(r'^(\s*)[-*+]\s+(.*)$');
  static final RegExp _ordered = RegExp(r'^(\s*)\d{1,9}[.)]\s+(.*)$');

  void append(String markdown) {
    final lines = markdown
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u200b', '')
        .split('\n');
    final definitions = collectJournalMarkdownReferences(lines, _inlineParser);
    String? fence;
    for (final (index, line) in lines.indexed) {
      if (definitions.contains(index)) continue;
      if (fence != null) {
        if (line.trimLeft().startsWith(fence)) {
          fence = null;
        } else {
          writer.text(line);
          writer.endLine(const {'code-block': true});
        }
        continue;
      }
      final fenceMatch = _fence.firstMatch(line);
      if (fenceMatch != null) {
        fence = fenceMatch.group(1)!.substring(0, 3);
        continue;
      }
      _appendLine(line);
    }
    writer.closeLine();
  }

  /// 返回 Markdown 行内语法渲染后的纯文本（如把 `# **标题**` 的内容取作标题）。
  String plainInline(String text) =>
      _inlineParser.parseInline(text).map((node) => node.textContent).join();

  void _appendLine(String line) {
    if (line.trim().isEmpty) {
      _listIndents.clear();
      writer.endLine();
      return;
    }
    if (_rule.hasMatch(line)) {
      _listIndents.clear();
      writer.embed(diaryDividerEmbed);
      return;
    }
    final (content, attributes) = _classify(line);
    _htmlFormats.clear();
    _htmlStyles.clear();
    final before = writer.lineCount;
    _inline(_inlineParser.parseInline(content), const {}, attributes);
    if (writer.lineHasContent) {
      writer.endLine(attributes);
    } else {
      writer.closeLine();
      // 只有媒体的行已由 embed 独占成行；什么都没产出（如空列表项）时才补行。
      if (writer.lineCount == before) writer.endLine(attributes);
    }
  }

  (String, Map<String, Object?>) _classify(String line) {
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      _listIndents.clear();
      final level = heading.group(1)!.length;
      return (heading.group(2)!, {'header': level > 3 ? 3 : level});
    }
    final quote = _quote.firstMatch(line);
    if (quote != null) {
      _listIndents.clear();
      var content = quote.group(1)!;
      // 嵌套引用（> > 文本）在编辑器里只有一级。
      for (
        var nested = _quote.firstMatch(content);
        nested != null;
        nested = _quote.firstMatch(content)
      ) {
        content = nested.group(1)!;
      }
      return (content, const {'blockquote': true});
    }
    final task = _task.firstMatch(line);
    if (task != null) {
      return (
        task.group(3)!,
        _listAttributes(
          task.group(1)!,
          task.group(2) == ' ' ? 'unchecked' : 'checked',
        ),
      );
    }
    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      return (bullet.group(2)!, _listAttributes(bullet.group(1)!, 'bullet'));
    }
    final ordered = _ordered.firstMatch(line);
    if (ordered != null) {
      return (ordered.group(2)!, _listAttributes(ordered.group(1)!, 'ordered'));
    }
    _listIndents.clear();
    return (line.trim(), const {});
  }

  Map<String, Object?> _listAttributes(String indent, String type) {
    final width = indent.replaceAll('\t', '    ').length;
    while (_listIndents.isNotEmpty && width < _listIndents.last) {
      _listIndents.removeLast();
    }
    if (_listIndents.isEmpty || width > _listIndents.last) {
      _listIndents.add(width);
    }
    final level = _listIndents.length - 1;
    return {'list': type, if (level > 0) 'indent': level};
  }

  void _inline(
    List<md.Node> nodes,
    Map<String, Object?> inline,
    Map<String, Object?> line,
  ) {
    for (final node in nodes) {
      if (node is md.Text) {
        writer.text(node.text.replaceAll('\u00a0', ' '), _withHtml(inline));
        continue;
      }
      if (node is! md.Element) {
        writer.text(node.textContent, _withHtml(inline));
        continue;
      }
      final children = node.children ?? const <md.Node>[];
      switch (node.tag) {
        case 'strong':
          _inline(children, {...inline, 'bold': true}, line);
        case 'em':
          _inline(children, {...inline, 'italic': true}, line);
        case 'del':
          _inline(children, {...inline, 'strike': true}, line);
        case 'code':
          writer.text(node.textContent, {..._withHtml(inline), 'code': true});
        case 'a':
          final href = node.attributes['href']?.trim() ?? '';
          final file = href.isEmpty || _isWebLink(href)
              ? null
              : resolveLink?.call(href);
          if (file != null) {
            writer.embed(file, line);
          } else {
            _inline(
              children,
              _isWebLink(href) ? {...inline, 'link': href} : inline,
              line,
            );
          }
        case 'img':
          _embedSource(node.attributes['src'] ?? '', line);
        case 'br':
          writer.endLine(line);
        case _HtmlTagSyntax.tag:
          _htmlTag(node, line);
        default:
          _inline(children, inline, line);
      }
    }
  }

  /// 行内 HTML 标签（见 [_HtmlTagSyntax]）：格式标签开/闭当前行的格式
  /// （`<span>`/`<font>`/`<mark>`/`<big>`/`<small>` 带颜色、背景与字号），
  /// `<br>` 换行，`<hr>` 为分隔线，`<img>`/`<audio>`/`<video>` 转为媒体嵌入，
  /// 其余丢弃。
  void _htmlTag(md.Element node, Map<String, Object?> line) {
    final closing = node.attributes['closing'] == 'true';
    final name = node.attributes['name']!;
    final attribute = switch (name) {
      'b' || 'strong' => 'bold',
      'i' || 'em' => 'italic',
      'u' || 'ins' => 'underline',
      's' || 'del' || 'strike' => 'strike',
      'code' => 'code',
      _ => null,
    };
    if (const {'span', 'font', 'mark', 'big', 'small'}.contains(name)) {
      if (closing) {
        final index = _htmlStyles.lastIndexWhere((entry) => entry.name == name);
        if (index >= 0) _htmlStyles.removeAt(index);
      } else {
        final element = html_parser
            .parseFragment(node.attributes['raw']!)
            .children
            .firstOrNull;
        _htmlStyles.add((
          name: name,
          style: element == null
              ? const <String, Object?>{}
              : journalHtmlInlineStyle(element, const {}),
        ));
      }
      return;
    }
    if (attribute != null) {
      final depth = (_htmlFormats[attribute] ?? 0) + (closing ? -1 : 1);
      if (depth > 0) {
        _htmlFormats[attribute] = depth;
      } else {
        _htmlFormats.remove(attribute);
      }
      return;
    }
    if (closing) return;
    switch (name) {
      case 'br':
        writer.endLine(line);
      case 'hr':
        writer.embed(diaryDividerEmbed, line);
      case 'img' || 'audio' || 'video' || 'source':
        final src = html_parser
            .parseFragment(node.attributes['raw']!)
            .children
            .firstOrNull
            ?.attributes['src'];
        if (src != null) {
          _embedSource(src, line, keepRemoteImage: name == 'img');
        }
    }
  }

  Map<String, Object?> _withHtml(Map<String, Object?> inline) =>
      _htmlFormats.isEmpty && _htmlStyles.isEmpty
      ? inline
      : {
          ...inline,
          for (final key in _htmlFormats.keys) key: true,
          for (final entry in _htmlStyles) ...entry.style,
        };

  /// 图片/音视频引用：经 [resolveEmbed] 转为嵌入；解析不了的本地引用丢弃，
  /// http(s) 图片保留原地址。
  void _embedSource(
    String source,
    Map<String, Object?> line, {
    bool keepRemoteImage = true,
  }) {
    final src = source.trim();
    final data =
        resolveEmbed?.call(src) ??
        (keepRemoteImage &&
                RegExp(r'^https?://', caseSensitive: false).hasMatch(src)
            ? <String, Object?>{'image': src}
            : null);
    if (data != null) writer.embed(data, line);
  }

  static bool _isWebLink(String href) =>
      RegExp(r'^(https?|mailto):', caseSensitive: false).hasMatch(href);
}

/// 把一个 HTML 标签或注释解析为占位元素（tag 为 [tag]），原文放在 `raw`
/// 属性。markdown 包自带的 InlineHtmlSyntax 只跳过标签、把它留在相邻文字
/// 里，转换器无从区分标签与文字，所以单独匹配。注释的 `name` 为空，按未知
/// 标签丢弃。
class _HtmlTagSyntax extends md.InlineSyntax {
  _HtmlTagSyntax()
    : super(
        r'<!--[\s\S]*?-->|<(/?)([a-zA-Z][a-zA-Z0-9-]*)'
        r'''(?:\s+[^\s"'<>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*'''
        r'\s*/?>',
        startCharacter: 0x3C,
      );

  static const String tag = 'x-journal-html';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element.empty(tag)
        ..attributes['raw'] = match[0]!
        ..attributes['closing'] = '${match[1] == '/'}'
        ..attributes['name'] = (match[2] ?? '').toLowerCase(),
    );
    return true;
  }
}
