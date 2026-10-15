import 'package:markdown/markdown.dart' as md;

import 'journal_import_delta_writer.dart';

/// 把 Markdown 正文（Day One、旧版 Journey）写入 [JournalDeltaWriter]。
///
/// 日记应用里每个换行都是用户敲下的换行，所以按“源文本一行 = 正文一行”
/// 处理，不套用 Markdown 的段落合并规则（那会把相邻两行拼成一段）。块级
/// 语法（标题、列表、待办、引用、代码围栏、分隔线）逐行识别；行内语法
/// （粗体、斜体、删除线、行内代码、链接、图片、转义字符）交给 markdown
/// 包解析，图片经 [resolveEmbed] 转为本应用的媒体嵌入。
class JournalMarkdownConverter {
  JournalMarkdownConverter(this.writer, {this.resolveEmbed});

  final JournalDeltaWriter writer;
  final JournalEmbedResolver? resolveEmbed;

  /// 不启用行内 HTML 语法：本应用不渲染 HTML，原样保留为文本更直观。
  final md.Document _inlineParser = md.Document(
    encodeHtml: false,
    extensionSet: md.ExtensionSet.none,
    inlineSyntaxes: [md.StrikethroughSyntax(), md.AutolinkExtensionSyntax()],
  );

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
    String? fence;
    for (final line in lines) {
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
      return;
    }
    final (content, attributes) = _classify(line);
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
        writer.text(node.text.replaceAll('\u00a0', ' '), inline);
        continue;
      }
      if (node is! md.Element) {
        writer.text(node.textContent, inline);
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
          writer.text(node.textContent, {...inline, 'code': true});
        case 'a':
          final href = node.attributes['href']?.trim();
          _inline(
            children,
            href != null &&
                    RegExp(
                      r'^(https?|mailto):',
                      caseSensitive: false,
                    ).hasMatch(href)
                ? {...inline, 'link': href}
                : inline,
            line,
          );
        case 'img':
          final src = node.attributes['src']?.trim() ?? '';
          final data =
              resolveEmbed?.call(src) ??
              (RegExp(r'^https?://', caseSensitive: false).hasMatch(src)
                  ? <String, Object?>{'image': src}
                  : null);
          if (data != null) writer.embed(data, line);
        case 'br':
          writer.endLine(line);
        default:
          _inline(children, inline, line);
      }
    }
  }
}
