import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

export 'journal_import_dates.dart';

/// 一次导入的输入：用户选择的文件，以及它是 ZIP 时解压到的目录。
///
/// 只含路径字符串，可整体发送到解析用的后台 isolate。
class JournalImportInput {
  const JournalImportInput({required this.filePath, this.extractedPath});

  final String filePath;

  /// 所选文件是 ZIP 时的解压目录（位于导入暂存区内），否则为 null。
  final String? extractedPath;
}

/// 递归列出导出目录中的普通文件（按路径排序，结果稳定）。
///
/// 跳过 macOS 压缩时附带的 `__MACOSX/` 与 `._*` 资源分支文件，它们与真实
/// 文件同名，会被误当作日记或媒体。
List<File> listJournalExportFiles(String root) {
  final directory = Directory(root);
  if (!directory.existsSync()) return const <File>[];
  final files = <File>[
    for (final entity in directory.listSync(
      recursive: true,
      followLinks: false,
    ))
      if (entity is File &&
          !p
              .split(p.relative(entity.path, from: root))
              .any(
                (segment) =>
                    segment == '__MACOSX' ||
                    segment.startsWith('._') ||
                    segment == '.DS_Store',
              ))
        entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// 为没有自带 ID 的条目生成稳定键：同一基础键第二次出现时追加 `#2`、`#3`。
/// 调用方需按稳定顺序（如时间 + 正文）登记，重复导入同一文件时键才不变。
class JournalKeyRegistry {
  final Map<String, int> _counts = <String, int>{};
  final Set<String> _used = <String>{};

  String unique(String base) {
    var count = (_counts[base] ?? 0) + 1;
    var key = count == 1 ? base : '$base#$count';
    // 来源 ID 本身也可能带 #2；只数同名次数不能保证生成的键没有被占用。
    while (!_used.add(key)) {
      key = '$base#${++count}';
    }
    _counts[base] = count;
    return key;
  }
}

/// 本地墙钟时间的稳定文本键，如 `2024-11-03T08:30`。
String journalWallClockKey(DateTime local, {bool seconds = false}) {
  String two(int value) => value.toString().padLeft(2, '0');
  final base =
      '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}T${two(local.hour)}:${two(local.minute)}';
  return seconds ? '$base:${two(local.second)}' : base;
}

/// 导出文本可能来自 Windows（UTF-16）或带 BOM 的编辑器。明确识别编码，
/// 不以替换字符掩盖损坏的数据；调用方把解码失败作为格式错误处理。
String readJournalText(File file) {
  final bytes = file.readAsBytesSync();
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
          (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
    if (bytes.length.isOdd) throw const FormatException('Truncated UTF-16');
    final littleEndian = bytes[0] == 0xFF;
    final units = <int>[
      for (var i = 2; i < bytes.length; i += 2)
        littleEndian
            ? bytes[i] | bytes[i + 1] << 8
            : bytes[i] << 8 | bytes[i + 1],
    ];
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (++i >= units.length || units[i] < 0xDC00 || units[i] > 0xDFFF) {
          throw const FormatException('Invalid UTF-16 surrogate');
        }
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        throw const FormatException('Invalid UTF-16 surrogate');
      }
    }
    return String.fromCharCodes(units);
  }
  return utf8.decode(bytes).replaceFirst(RegExp(r'^\uFEFF'), '');
}

/// 可选数值允许 JSON 数字或数字字符串；NaN、无穷与异常类型视为缺失，
/// 不能让一项天气、坐标或时长中断整包导入。
num? journalNumber(Object? value) {
  final number = value is num
      ? value
      : value is String
      ? num.tryParse(value.trim())
      : null;
  return number != null && number.isFinite ? number : null;
}

/// JSON 中稳定 ID 有时是整数；只接受字符串与有限的整数数值。
String? journalId(Object? value) => switch (value) {
  final String text => journalString(text),
  final int number => '$number',
  final double number
      when number.isFinite && number == number.truncateToDouble() =>
    '${number.toInt()}',
  _ => null,
};

/// 可选数组字段类型变化时视为空数组，避免不安全的 `as List?` 强转。
List<Object?> journalList(Object? value) => value is List ? value : const [];

/// 与天气服务一致的展示文案：`<天气> <温度>℃`，缺一项时只保留另一项。
///
/// 温度不合理（导出用极大值表示“无数据”）时忽略。
String? journalWeatherText(String? description, num? celsius) {
  final text = description?.trim() ?? '';
  final temperature =
      celsius != null && celsius.isFinite && celsius > -100 && celsius < 100
      ? '${celsius.round()}℃'
      : '';
  final result = [text, temperature].where((part) => part.isNotEmpty).join(' ');
  return result.isEmpty ? null : result;
}

/// 经纬度是否有效：在合法范围内，且不是导出用来表示“无位置”的 0,0。
bool isJournalCoordinate(num? latitude, num? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180 &&
    !(latitude == 0 && longitude == 0);

/// 读取 JSON 里的字符串字段，空白串视为缺失。
String? journalString(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

/// 读取 JSON 里的字符串列表（如标签），忽略非字符串与空白项。
List<String> journalStringList(Object? value) => value is List
    ? value.map(journalString).nonNulls.toList(growable: false)
    : const <String>[];

/// 从英文日期文本中找出月份（1~12），如 `Sunday, 3 November 2024`、
/// `January 23`；星期等其他单词会被跳过，找不到返回 null。
int? journalEnglishMonth(String text) {
  const months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];
  for (final match in RegExp(r'[A-Za-z]{3,}').allMatches(text)) {
    final index = months.indexOf(match.group(0)!.substring(0, 3).toLowerCase());
    if (index >= 0) return index + 1;
  }
  return null;
}
