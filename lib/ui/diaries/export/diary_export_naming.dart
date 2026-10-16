import 'package:intl/intl.dart';

import 'diary_export_entry.dart';

/// 导出文件与包内文件的命名。
///
/// 以“日期 时间 标题”开头：文件管理器按名称排序即按时间排序，Jotsy 与
/// Obsidian 等的 Markdown 导入也能从文件名读出日期。去掉各平台文件名
/// 不允许的字符，标题截断到 40 个字符，避免超出路径长度限制。
class DiaryExportNaming {
  const DiaryExportNaming._();

  static final DateFormat _stamp = DateFormat('yyyy-MM-dd HHmm');
  static final DateFormat _day = DateFormat('yyyy-MM-dd');

  static String sanitize(String raw, {int maxLength = 40}) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final characters = cleaned.runes.toList();
    final cut = characters.length > maxLength
        ? String.fromCharCodes(characters.take(maxLength)).trim()
        : cleaned;
    // 末尾的点在 Windows 上会被吞掉，导致同名冲突。
    return cut.replaceAll(RegExp(r'\.+$'), '');
  }

  /// 单篇文件名主干：`2026-04-03 0900 春日小记`，无标题时只有日期时间。
  static String entryStem(DiaryExportEntry entry) {
    final title = sanitize(entry.title);
    final stamp = _stamp.format(entry.createdAt.toLocal());
    return title.isEmpty ? stamp : '$stamp $title';
  }

  /// 导出文件名主干：单篇同 [entryStem]，多篇为 `Jotsy 起始日~结束日`。
  static String exportStem(List<DiaryExportEntry> entries) {
    if (entries.length == 1) {
      return entryStem(entries.single);
    }
    if (entries.isEmpty) {
      return 'Jotsy';
    }
    final dates = entries.map((DiaryExportEntry e) => e.createdAt.toLocal());
    final first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final start = _day.format(first);
    final end = _day.format(last);
    return start == end ? 'Jotsy $start' : 'Jotsy $start~$end';
  }

  /// 在 [taken] 中为 [name] 找一个不重名的写法（`名称 (2).md`），并登记。
  static String unique(Set<String> taken, String name) {
    if (taken.add(name.toLowerCase())) {
      return name;
    }
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';
    for (var i = 2; ; i++) {
      final candidate = '$stem ($i)$extension';
      if (taken.add(candidate.toLowerCase())) {
        return candidate;
      }
    }
  }
}
