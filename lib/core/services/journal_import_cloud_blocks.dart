import 'journal_import_cloud.dart';
import 'journal_import_delta_writer.dart';

/// 云端笔记的通用富文本块，对应参考实现（笔记互迁 `models.py`）的
/// Block/Span：各平台把自有格式解析成块，再统一写成本应用的正文。
enum CloudBlockKind {
  paragraph,
  heading,
  list,
  todo,
  quote,
  code,
  divider,
  table,
  attachment,
}

/// 一段行内文字及其格式。[link] 只接受 http(s)/mailto。高亮在本应用的
/// 编辑器中没有对应格式，写出时丢弃。
class CloudSpan {
  const CloudSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.highlight = false,
    this.code = false,
    this.link,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool highlight;
  final bool code;
  final String? link;

  CloudSpan copyWith({String? text}) => CloudSpan(
    text ?? this.text,
    bold: bold,
    italic: italic,
    underline: underline,
    strike: strike,
    highlight: highlight,
    code: code,
    link: link,
  );

  Map<String, Object?> get attributes => {
    if (bold) 'bold': true,
    if (italic) 'italic': true,
    if (underline) 'underline': true,
    if (strike) 'strike': true,
    if (code) 'code': true,
    if (link case final url?
        when RegExp(r'^(https?|mailto):', caseSensitive: false).hasMatch(url))
      'link': url,
  };
}

/// 一个块。[level] 对标题是 1~6，对列表/待办是从 1 开始的缩进层级。
class CloudBlock {
  const CloudBlock(
    this.kind, {
    this.spans = const <CloudSpan>[],
    this.level = 1,
    this.ordered = false,
    this.checked = false,
    this.rows = const <List<String>>[],
    this.attachmentId,
  });

  const CloudBlock.paragraph(List<CloudSpan> spans)
    : this(CloudBlockKind.paragraph, spans: spans);

  final CloudBlockKind kind;
  final List<CloudSpan> spans;
  final int level;
  final bool ordered;
  final bool checked;
  final List<List<String>> rows;
  final String? attachmentId;

  String get text => spans.map((span) => span.text).join();
}

/// 把块写入正文：每块至少一行，块内文字中的换行拆成多行并沿用块格式；
/// 附件块经 [resolve] 换成媒体嵌入，未下载到的附件丢弃；分隔线没有对应
/// 格式，丢弃；表格每行一行、单元格以空格分隔。
void writeCloudBlocks(
  JournalDeltaWriter writer,
  List<CloudBlock> blocks,
  CloudEmbedResolver resolve,
) {
  for (final block in blocks) {
    switch (block.kind) {
      case CloudBlockKind.attachment:
        final data = block.attachmentId == null
            ? null
            : resolve(block.attachmentId!);
        if (data != null) writer.embed(data);
      case CloudBlockKind.divider:
        writer.closeLine();
      case CloudBlockKind.table:
        for (final row in block.rows) {
          writer.text(row.where((cell) => cell.trim().isNotEmpty).join(' '));
          writer.endLine();
        }
      default:
        _writeLines(writer, block.spans, _attributes(block));
    }
  }
}

Map<String, Object?> _attributes(CloudBlock block) {
  final indent = block.level - 1;
  return switch (block.kind) {
    CloudBlockKind.heading => {'header': block.level.clamp(1, 3)},
    CloudBlockKind.list => {
      'list': block.ordered ? 'ordered' : 'bullet',
      if (indent > 0) 'indent': indent.clamp(1, 5),
    },
    CloudBlockKind.todo => {
      'list': block.checked ? 'checked' : 'unchecked',
      if (indent > 0) 'indent': indent.clamp(1, 5),
    },
    CloudBlockKind.quote => {'blockquote': true},
    CloudBlockKind.code => {'code-block': true},
    _ => const <String, Object?>{},
  };
}

void _writeLines(
  JournalDeltaWriter writer,
  List<CloudSpan> spans,
  Map<String, Object?> attributes,
) {
  for (final span in spans) {
    final lines = span.text
        .replaceAll('\r\n', '\n')
        .replaceAll(' ', ' ')
        .split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) writer.endLine(attributes);
      writer.text(lines[i], span.attributes);
    }
  }
  writer.endLine(attributes);
}
