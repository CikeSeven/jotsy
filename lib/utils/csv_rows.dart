/// 按 RFC 4180 把 CSV 文本拆成行与字段。
///
/// 支持引号包裹的逗号与换行、`""` 转义、CRLF/LF 换行，并忽略开头的 UTF-8
/// BOM。字段不做 trim，完全空白的行由调用方自行跳过。
List<List<String>> parseCsvRows(
  String source, {
  String delimiter = ',',
  bool strict = false,
}) {
  if (delimiter.length != 1 || '"\r\n'.contains(delimiter)) {
    throw ArgumentError.value(delimiter, 'delimiter');
  }
  final text = source.startsWith('\uFEFF') ? source.substring(1) : source;
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (inQuotes) {
      if (char != '"') {
        field.write(char);
      } else if (i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        inQuotes = false;
      }
      continue;
    }
    if (char == delimiter) {
      endField();
      continue;
    }
    switch (char) {
      case '"':
        inQuotes = true;
      case '\r':
        if (i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      case '\n':
        endRow();
      default:
        field.write(char);
    }
  }
  if (strict && inQuotes) throw const FormatException('Unterminated CSV quote');
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
