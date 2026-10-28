import 'journal_import_block_writer.dart';
import 'journal_import_style.dart';

/// 把来源应用的 Quill Delta 正文（flutter_quill 的 `Document.toDelta()`，
/// 如榴莲日记的富文本日记）写入 [JournalBlockWriter]。
///
/// - 先按换行切成行：Delta 的行级属性（标题、列表、引用、代码块、缩进、
///   对齐）挂在结束这一行的换行符上，要等读到换行才知道整行的格式；
/// - 嵌入（图片、分隔线等）经 [resolveEmbed] 换成本应用的嵌入数据，独占
///   一行：结束嵌入所在行的那个换行只是行尾，不另起空行；同一行里夹着的
///   文字拆到嵌入前后各成一行，沿用这一行的格式；
/// - 行内属性只保留正文能渲染的：粗体、斜体、下划线、删除线、行内代码、
///   网页链接、颜色、背景与字号；颜色按 flutter_quill 的约定，8 位十六进制
///   是 `#AARRGGBB`，再经 journal_import_style.dart 规整（默认墨色不导入），
///   字号只写 small / large / huge 三档；
/// - 标题最多 3 级（与正文一致），对齐只保留 center / right / justify。
///
/// [resolveEmbed] 返回这个嵌入对应的媒体（实况照片是静图 + 视频两项），
/// 空列表即丢弃（文件缺失、认不出的类型），调用方负责统计缺失。纯内存
/// 操作。
void appendJournalQuillOps(
  JournalBlockWriter writer,
  List<Object?> ops, {
  required List<Map<String, Object?>> Function(Map<Object?, Object?> embed)
  resolveEmbed,
}) {
  for (final line in _splitLines(ops)) {
    final attributes = _blockAttributes(line.attributes);
    if (!line.segments.any((segment) => segment.embed != null)) {
      for (final segment in line.segments) {
        writer.text(segment.text!, segment.attributes);
      }
      writer.endLine(attributes);
      continue;
    }
    // 嵌入所在行：文字与嵌入按顺序各占一行；嵌入的行沿用对齐。
    final align = attributes['align'];
    var hasText = false;
    for (final segment in line.segments) {
      final embed = segment.embed;
      if (embed == null) {
        writer.text(segment.text!, segment.attributes);
        hasText = true;
        continue;
      }
      if (hasText) {
        writer.endLine(attributes);
        hasText = false;
      }
      for (final data in resolveEmbed(embed)) {
        writer.embed(data, const {}, {'align': ?align});
      }
    }
    if (hasText) writer.endLine(attributes);
  }
}

class _Segment {
  const _Segment.text(String this.text, this.attributes) : embed = null;

  const _Segment.embed(Map<Object?, Object?> this.embed)
    : text = null,
      attributes = const {};

  final String? text;
  final Map<String, Object?> attributes;
  final Map<Object?, Object?>? embed;
}

class _Line {
  _Line(this.segments, this.attributes);

  final List<_Segment> segments;
  final Map<Object?, Object?> attributes;
}

/// 按换行切行。文档末尾没有换行收尾的残余文字照样成为一行。
List<_Line> _splitLines(List<Object?> ops) {
  final lines = <_Line>[];
  var segments = <_Segment>[];
  for (final op in ops) {
    if (op is! Map) continue;
    final insert = op['insert'];
    final raw = op['attributes'];
    final attributes = raw is Map ? raw : const <Object?, Object?>{};
    if (insert is Map) {
      segments.add(_Segment.embed(insert));
      continue;
    }
    if (insert is! String) continue;
    final parts = insert.replaceAll('\r\n', '\n').split('\n');
    for (var index = 0; index < parts.length; index++) {
      if (index > 0) {
        lines.add(_Line(segments, attributes));
        segments = <_Segment>[];
      }
      final text = parts[index];
      if (text.isNotEmpty) {
        segments.add(_Segment.text(text, _inlineAttributes(attributes)));
      }
    }
  }
  if (segments.isNotEmpty) {
    lines.add(_Line(segments, const <Object?, Object?>{}));
  }
  return lines;
}

Map<String, Object?> _inlineAttributes(Map<Object?, Object?> source) {
  String? color(Object? value, String? Function(String?) normalize) =>
      value is String ? normalize(journalArgbToCss(value) ?? value) : null;
  final link = source['link'];
  return {
    for (final key in const ['bold', 'italic', 'underline', 'strike', 'code'])
      if (source[key] == true) key: true,
    if (link is String &&
        RegExp(r'^(https?|mailto):', caseSensitive: false).hasMatch(link))
      'link': link,
    'color': ?color(source['color'], journalTextColor),
    'background': ?color(source['background'], journalBackgroundColor),
    'size': ?_size(source['size']),
  };
}

/// flutter_quill 的字号：small / large / huge 原样保留，数字按 16 的正文
/// 字号换算成档位。
String? _size(Object? value) {
  if (value == 'small' || value == 'large' || value == 'huge') {
    return value as String;
  }
  final number = value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value.trim())
      : null;
  return number == null ? null : journalFontSizeForRatio(number / 16);
}

Map<String, Object?> _blockAttributes(Map<Object?, Object?> source) {
  final header = source['header'];
  final list = source['list'];
  final indent = source['indent'];
  final code = source['code-block'];
  return {
    if (header is int && header > 0) 'header': header > 3 ? 3 : header,
    if (list case 'ordered' || 'bullet' || 'checked' || 'unchecked')
      'list': list,
    if (source['blockquote'] == true) 'blockquote': true,
    if (code == true || (code is String && code.isNotEmpty)) 'code-block': code,
    if (indent is int && indent > 0) 'indent': indent,
    'align': ?journalAlign(
      source['align'] is String ? source['align'] as String : null,
    ),
  };
}
