/// GFM 管道表格的识别（见 JournalMarkdownConverter）：表头行、分隔行（每格
/// 只有 `-`，两端可带对齐冒号，冒号忽略）与其后连续的表体行。纯文本处理，
/// 格子的行内语法由调用方解析。
library;

import 'journal_import_blocks.dart';

final RegExp _pipeDelimiter = RegExp(r'^:?-+:?$');

/// 从 [start] 行开始的管道表格按行给出各格原文（首行为表头，表体短的行
/// 补空格子）；不是表格或不规整时为 null。不规整即：分隔行格数与表头
/// 不同、表体某行格数多于表头（多出的格放不下）、行列数超出上限
/// （[journalImportTableFits]）。表体遇到空行、没有 `|` 的行或
/// [isOtherBlock] 认出的别的块级语法时结束；表头行本身是别的块级语法时
/// 不是表格。
List<List<String>>? journalPipeTableRows(
  List<String> lines,
  int start,
  bool Function(String line) isOtherBlock,
) {
  if (start + 1 >= lines.length || isOtherBlock(lines[start])) return null;
  final header = journalPipeCells(lines[start]);
  if (header == null) return null;
  final delimiter = journalPipeCells(lines[start + 1]);
  if (delimiter == null ||
      delimiter.length != header.length ||
      !delimiter.every(_pipeDelimiter.hasMatch)) {
    return null;
  }
  final rows = <List<String>>[header];
  for (var index = start + 2; index < lines.length; index++) {
    if (isOtherBlock(lines[index])) break;
    final cells = journalPipeCells(lines[index]);
    if (cells == null) break;
    if (cells.length > header.length) return null;
    rows.add([...cells, for (var i = cells.length; i < header.length; i++) '']);
  }
  return journalImportTableFits(rows.length, header.length) ? rows : null;
}

/// 按未转义的 `|` 拆成格（去掉两端各一个 `|`，格内首尾空白去掉，`\|`
/// 还原为 `|`）；没有 `|` 的行不是表格行，返回 null。
List<String>? journalPipeCells(String line) {
  final text = line.trim();
  if (text.isEmpty) return null;
  final cells = <String>[];
  final buffer = StringBuffer();
  var pipes = 0;
  var trailingPipe = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    trailingPipe = false;
    if (char == r'\' && i + 1 < text.length && text[i + 1] == '|') {
      buffer.write('|');
      i++;
      continue;
    }
    if (char == '|') {
      pipes++;
      cells.add(buffer.toString());
      buffer.clear();
      trailingPipe = true;
      continue;
    }
    buffer.write(char);
  }
  if (pipes == 0) return null;
  if (!trailingPipe) cells.add(buffer.toString());
  if (text.startsWith('|')) cells.removeAt(0);
  if (cells.isEmpty) return null;
  return [for (final cell in cells) cell.trim()];
}
