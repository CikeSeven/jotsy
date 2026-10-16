import 'dart:io';

import 'package:html/parser.dart' as html_parser;

import 'journal_import_delta_writer.dart';
import 'journal_import_markdown.dart';
import 'journal_import_models.dart';
import 'journal_import_note_bridge.dart';

/// 每篇的开头：`# 标题`、空行、创建时间、修改时间（标题经过 HTML 转义）。
final RegExp _markdownHeader = RegExp(
  r'^# (.*)\n\n创建时间：(.*)\n修改时间：(.*)$',
  multiLine: true,
);

/// 合并导出中篇与篇之间的分隔（参考项目 `exporter.py` 的 `_write`）。
const String _markdownSeparator = '\n---\n\n';
final String _textSeparator = '\n\n${'═' * 40}\n\n';

/// 读取「笔记互迁」的 Markdown 导出；不是该格式时返回 null。
///
/// 每篇为 `# 标题`、时间两行与正文，合并模式以 `\n---\n\n` 连接各篇。正文
/// 由受控模型生成（参考项目 `richtext.py` 的 `blocks_markdown`）：块与块
/// 之间固定空一行，空段落因此表现为多出的两个空行；标题比原级别多一个
/// `#`；文字中的 Markdown 符号用反斜杠、`< > &` 用实体转义；下划线、带
/// 首尾空格的粗体等用行内 HTML，录音/视频是 `<audio src>`/`<video src>`。
NoteBridgeDocument? readNoteBridgeMarkdown(
  File file,
  String text, {
  JournalImportSource? platform,
}) {
  final source = text.replaceAll('\r\n', '\n');
  final headers = _markdownHeader.allMatches(source).toList(growable: false);
  if (headers.isEmpty ||
      source.substring(0, headers.first.start).trim().isNotEmpty) {
    return null;
  }
  final notes = <NoteBridgeNote>[];
  for (var i = 0; i < headers.length; i++) {
    final header = headers[i];
    var body = source.substring(
      header.end,
      i + 1 < headers.length ? headers[i + 1].start : source.length,
    );
    if (i + 1 < headers.length && body.endsWith(_markdownSeparator)) {
      body = body.substring(0, body.length - _markdownSeparator.length);
    }
    notes.add(
      NoteBridgeNote(
        title: html_parser.parseFragment(header.group(1)!).text ?? '',
        created: parseNoteBridgeTime(header.group(2)),
        updated: parseNoteBridgeTime(header.group(3)),
        writeBody: (writer, media) => JournalMarkdownConverter(
          writer,
          resolveEmbed: media.resolve,
          resolveLink: media.resolve,
          inlineHtml: true,
        ).append(_lineMarkdown(body, media)),
      ),
    );
  }
  return NoteBridgeDocument(
    file,
    NoteBridgeFormat.markdown,
    notes,
    platform: platform,
  );
}

/// 把“块间空一行”的正文还原成“一行一段”，供逐行转换：
///
/// - 两个块之间的 n 个空行对应 (n - 1) / 2 个空段落；代码围栏内原样保留；
/// - 标题去掉多出的一个 `#`；行首单个 `#` 只可能是正文文字，转义掉；
/// - 表格（`| … |` 行）合成一行纯文本，各单元格以空格分隔，与 HTML 导入
///   对表格的处理一致；
/// - `[附件未获取…]` 行计入缺失媒体后丢弃。
String _lineMarkdown(String body, NoteBridgeMedia media) {
  final output = <String>[];
  var blanks = 0;
  String? fence;
  for (final line in body.split('\n')) {
    if (fence != null) {
      output.add(line);
      if (line.trimLeft().startsWith(fence)) fence = null;
      continue;
    }
    if (line.trim().isEmpty) {
      blanks++;
      continue;
    }
    if (output.isNotEmpty && blanks > 1) {
      output.addAll(List.filled((blanks - 1) ~/ 2, ''));
    }
    blanks = 0;
    final opening = RegExp(r'^(`{3,}|~{3,})').firstMatch(line);
    if (opening != null) {
      fence = opening.group(1)!;
      output.add(line);
    } else if (RegExp(r'^\[附件未获取(：.*)?\]$').hasMatch(line.trim())) {
      media.markMissing();
    } else if (RegExp(r'^#{2,6}\s').hasMatch(line)) {
      output.add(line.substring(1));
    } else if (RegExp(r'^#\s').hasMatch(line)) {
      output.add('\\$line');
    } else if (RegExp(r'^\|.*\|\s*$').hasMatch(line)) {
      if (!RegExp(r'^\|(\s*-{3,}\s*\|)+\s*$').hasMatch(line)) {
        output.add(_tableRow(line));
      }
    } else {
      output.add(line);
    }
  }
  return output.join('\n');
}

String _tableRow(String line) {
  final row = line.trim();
  return row
      .substring(1, row.length - 1)
      .split(RegExp(r'(?<!\\)\|'))
      .map(
        (cell) => cell
            .trim()
            .replaceAll('<br>', ' ')
            .replaceAll(r'\|', '|')
            .replaceAllMapped(
              RegExp(r'([\\`*_\[\]~<])'),
              (match) => '\\${match[1]}',
            ),
      )
      .where((cell) => cell.isNotEmpty)
      .join(' ');
}

/// 读取「笔记互迁」的 TXT 导出（UTF-8 带 BOM）；不是该格式时返回 null。
///
/// 合并模式以空行包围的 40 个 `═` 分隔各篇。每篇依次为标题行、创建/修改
/// 时间两行、空行、正文（一块一行：列表为 `• `、待办为 `☑ `/`☐ `、分隔线为
/// 20 个 `─`，样式与表格边框已丢失），最后是全部附件
/// `[附件] 名称：相对路径`（未下载为“未获取”）与转换提示 `[提示] …`。
NoteBridgeDocument? readNoteBridgeText(
  File file,
  String text, {
  JournalImportSource? platform,
}) {
  final notes = <NoteBridgeNote>[];
  List<String>? previous;
  for (final part in text.replaceAll('\r\n', '\n').split(_textSeparator)) {
    final lines = part.split('\n');
    final isNote =
        lines.length >= 3 &&
        lines[0].trim().isNotEmpty &&
        lines[1].startsWith('创建时间：') &&
        lines[2].startsWith('修改时间：');
    if (!isNote) {
      // 首段对不上就不是这种格式；后面的段多半是正文里恰好出现了分隔线。
      if (previous == null) return null;
      previous.addAll(['', '═' * 40, '', ...lines]);
      continue;
    }
    final body = lines.length > 4 ? lines.sublist(4) : <String>[];
    previous = body;
    notes.add(
      NoteBridgeNote(
        title: lines[0].trim(),
        created: parseNoteBridgeTime(lines[1].substring(5)),
        updated: parseNoteBridgeTime(lines[2].substring(5)),
        writeBody: (writer, media) => _writeText(body, writer, media),
      ),
    );
  }
  if (notes.isEmpty) return null;
  return NoteBridgeDocument(
    file,
    NoteBridgeFormat.text,
    notes,
    platform: platform,
  );
}

final RegExp _attachmentLine = RegExp(r'^\[附件\] (.+)：(.+)$');

void _writeText(
  List<String> lines,
  JournalDeltaWriter writer,
  NoteBridgeMedia media,
) {
  var end = lines.length;
  while (end > 0 && lines[end - 1].trim().isEmpty) {
    end--;
  }
  while (end > 0 && lines[end - 1].startsWith('[提示] ')) {
    end--;
  }
  var start = end;
  while (start > 0 && _attachmentLine.hasMatch(lines[start - 1])) {
    start--;
  }
  for (final line in lines.sublist(0, start)) {
    if (line.trim() == '─' * 20) continue;
    final todo = RegExp(r'^([☑☐]) (.*)$').firstMatch(line);
    final bullet = RegExp(r'^( *)• (.*)$').firstMatch(line);
    if (todo != null) {
      writer.text(todo.group(2)!);
      writer.endLine({'list': todo.group(1) == '☑' ? 'checked' : 'unchecked'});
    } else if (bullet != null) {
      final indent = bullet.group(1)!.length ~/ 2;
      writer.text(bullet.group(2)!);
      writer.endLine({'list': 'bullet', if (indent > 0) 'indent': indent});
    } else {
      appendJournalPlainText(writer, line);
    }
  }
  for (final line in lines.sublist(start, end)) {
    final match = _attachmentLine.firstMatch(line)!;
    final path = match.group(2)!.trim();
    if (path == '未获取') {
      media.markMissing();
      continue;
    }
    final data = media.resolve(path, name: match.group(1)!.trim());
    if (data != null) writer.embed(data);
  }
}
