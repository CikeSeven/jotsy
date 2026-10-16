/// Markdown 文件开头的 YAML front matter 与宽松日期解析，供 Markdown 类
/// 导入（Obsidian、Bear、Joplin 的 Markdown 导出等）共用。纯文本处理，无 IO。
library;

/// 拆出文件开头 `---` 包围的 front matter，返回字段与其后的正文；没有
/// front matter 时字段为空、正文为原文。
///
/// 只支持日记导出里常见的简单 YAML：`key: value`、`key: [a, b]` 与其下
/// 缩进的 `- item` 列表。键统一转小写，值去掉成对引号；列表值为
/// `List<String>`，其余为 `String`。嵌套对象等复杂写法忽略，不影响正文。
({Map<String, Object> fields, String body}) splitJournalFrontMatter(
  String text,
) {
  final lines = text.split('\n');
  if (lines.isEmpty || lines.first.trimRight() != '---') {
    return (fields: const <String, Object>{}, body: text);
  }
  final end = lines.indexWhere(
    (line) => line.trimRight() == '---' || line.trimRight() == '...',
    1,
  );
  if (end < 0) return (fields: const <String, Object>{}, body: text);
  final fields = <String, Object>{};
  String? listKey;
  for (final line in lines.sublist(1, end)) {
    final item = RegExp(r'^\s+-\s+(.*)$').firstMatch(line);
    if (item != null && listKey != null) {
      final value = _unquote(item.group(1)!);
      if (value.isNotEmpty) (fields[listKey] as List<String>).add(value);
      continue;
    }
    final field = RegExp(r'^([A-Za-z_][\w -]*?)\s*:\s*(.*)$').firstMatch(line);
    if (field == null) {
      listKey = null;
      continue;
    }
    final key = field.group(1)!.toLowerCase();
    final raw = field.group(2)!.trim();
    if (raw.isEmpty) {
      listKey = key;
      fields[key] = <String>[];
    } else if (raw.startsWith('[') && raw.endsWith(']')) {
      listKey = null;
      fields[key] = raw
          .substring(1, raw.length - 1)
          .split(',')
          .map(_unquote)
          .where((value) => value.isNotEmpty)
          .toList();
    } else {
      listKey = null;
      fields[key] = _unquote(raw);
    }
  }
  return (fields: fields, body: lines.sublist(end + 1).join('\n'));
}

String _unquote(String raw) {
  final value = raw.trim();
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    return value.substring(1, value.length - 1).trim();
  }
  return value;
}

/// front matter 中第一个存在的字符串字段。
String? journalFrontMatterString(
  Map<String, Object> fields,
  Iterable<String> keys,
) {
  for (final key in keys) {
    final value = fields[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

/// 宽松解析导出里的日期时间：
///
/// - `2024-01-15`、`2024/1/15 8:30`、`2024年1月15日 08:30:05`、
///   `2024-01-15T08:30:00.000+08:00`、`20240115T083000Z` 等；
/// - 10/13 位数字视为 Unix 秒/毫秒时间戳。
///
/// 带时区（`Z` 或 `±hh:mm`）时换算为本机时间，不带时区时视为本地墙钟时间；
/// 日期越界或无法识别时返回 null。
DateTime? parseLooseJournalDate(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  if (RegExp(r'^\d{10}(\d{3})?$').hasMatch(text)) {
    final value = int.parse(text);
    return DateTime.fromMillisecondsSinceEpoch(
      text.length == 10 ? value * 1000 : value,
    );
  }
  final match = RegExp(
    r'^(\d{4})[-/.年]?(\d{1,2})[-/.月]?(\d{1,2})日?'
    r'(?:[ T]+(\d{1,2})[:：]?(\d{2})(?:[:：]?(\d{2}))?(?:[.,]\d+)?)?'
    r'\s*(Z|[+-]\d{2}(?::?\d{2})?)?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  int field(int group) => int.tryParse(match.group(group) ?? '') ?? 0;
  final year = field(1);
  final month = field(2);
  final day = field(3);
  final hour = field(4);
  final minute = field(5);
  final second = field(6);
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }
  final zone = match.group(7)?.toUpperCase();
  if (zone == null) return DateTime(year, month, day, hour, minute, second);
  final utc = DateTime.utc(year, month, day, hour, minute, second);
  if (zone == 'Z') return utc.toLocal();
  final digits = zone.substring(1).replaceAll(':', '');
  final offset = Duration(
    hours: int.parse(digits.substring(0, 2)),
    minutes: digits.length > 2 ? int.parse(digits.substring(2)) : 0,
  );
  return (zone.startsWith('-') ? utc.add(offset) : utc.subtract(offset))
      .toLocal();
}
