import 'dart:convert';

import 'backup_constants.dart';

/// 托管媒体相对 documents 的定位键，形如 `diary_images/media_x/a.jpg`。
///
/// 数据库存的是写入时的绝对路径，但 iOS 容器路径会随应用更新变化、备份恢复
/// 也会换根目录，所以引用与磁盘文件统一按“最后一个托管目录名及之后的部分”
/// 比对，与备份恢复重绑路径的定位规则一致。不含托管目录或带 `..` 时返回 null。
String? diaryMediaKeyOf(String path) {
  final segments = path
      .replaceAll('\\', '/')
      .split('/')
      .where((segment) => segment.isNotEmpty && segment != '.')
      .toList(growable: false);
  var index = -1;
  for (final name in backupMediaDirectories) {
    final candidate = segments.lastIndexOf(name);
    if (candidate > index) index = candidate;
  }
  if (index < 0 || index + 1 >= segments.length) return null;
  final rest = segments.sublist(index);
  if (rest.contains('..')) return null;
  return rest.join('/');
}

/// 汇总日记正文、封面、metadata 与草稿里出现过的托管媒体引用。
///
/// 不按具体 embed 类型解析，而是遍历 JSON 里的每个字符串（包括附件 metadata
/// 这类嵌套 JSON 字符串），只要提到托管目录就记为引用：历史 AppFlowy 正文、
/// 旧版附件格式以及以后新增的 embed 都不会因为解析遗漏而被误删。
/// 精确键查不到时，再按“原文包含该键”兜底，宁可多留文件也不误删。
class DiaryMediaReferences {
  DiaryMediaReferences(Iterable<String?> sources) {
    for (final source in sources) {
      if (source != null) _visitString(source);
    }
  }

  final Set<String> _keys = <String>{};
  final List<String> _mentions = <String>[];

  /// 精确识别出的托管媒体键，不含只能靠“原文包含”兜底的提及；导出日记包时
  /// 据此复制被引用的文件。
  Set<String> get keys => Set.unmodifiable(_keys);

  bool contains(String key) =>
      _keys.contains(key) || _mentions.any((mention) => mention.contains(key));

  void _visitString(String value) {
    if (!backupMediaDirectories.any(value.contains)) return;
    final trimmed = value.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        _visitJson(jsonDecode(trimmed));
        return;
      } on FormatException {
        // 不是合法 JSON，按普通文本兜底。
      }
    }
    final normalized = trimmed.replaceAll('\\', '/');
    _record(normalized);
    if (normalized.startsWith('file:')) {
      try {
        _record(Uri.decodeComponent(Uri.parse(normalized).path));
      } on FormatException {
        // 编码损坏的 URI 只保留原文匹配。
      }
    }
  }

  void _record(String mention) {
    final key = diaryMediaKeyOf(mention);
    if (key != null) _keys.add(key);
    _mentions.add(mention);
  }

  void _visitJson(Object? node) {
    if (node is String) {
      _visitString(node);
    } else if (node is List) {
      node.forEach(_visitJson);
    } else if (node is Map) {
      for (final entry in node.entries) {
        _visitJson(entry.key);
        _visitJson(entry.value);
      }
    }
  }
}
