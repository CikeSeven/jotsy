import 'package:path/path.dart' as p;

import 'journal_import_support.dart';

/// 导出文件的只读路径索引。在任何附件被暂存（rename）前拍下清单，后续
/// 查找不依赖源路径是否仍存在。同一文件可被多篇笔记共享；只按文件名
/// 兜底时必须唯一，避免两个笔记本的同名图片被错误地互换。
class JournalImportFiles {
  JournalImportFiles(String root) : root = p.normalize(p.absolute(root)) {
    for (final file in listJournalExportFiles(this.root)) {
      final path = p.normalize(p.absolute(file.path));
      _exact[path] = path;
      _addUnique(_caseFolded, path.toLowerCase(), path);
      _addUnique(_byName, p.basename(path).toLowerCase(), path);
      _addUnique(_byStem, p.basenameWithoutExtension(path).toLowerCase(), path);
      _addUnique(
        _byDirectoryStem,
        p.withoutExtension(path).toLowerCase(),
        path,
      );
    }
  }

  final String root;
  final Map<String, String> _exact = {};
  final Map<String, String?> _caseFolded = {};
  final Map<String, String?> _byName = {};
  final Map<String, String?> _byStem = {};
  final Map<String, String?> _byDirectoryStem = {};

  /// 相对路径优先；兼容 URL 编码、Windows 分隔符、大小写与站内绝对路径。
  /// 链接的 query/fragment 只在按字面文件名找不到时剥去（真实文件名可能
  /// 带 #）。索引只含导出内的普通文件，不会读取设备私有路径或符号链接。
  String? resolve(
    String source, {
    required String from,
    bool matchStem = false,
    bool fallbackToName = true,
  }) {
    var raw = source.trim().replaceAll('\\', '/');
    if (raw.startsWith('<') && raw.endsWith('>')) {
      raw = raw.substring(1, raw.length - 1);
    }
    if (raw.isEmpty ||
        raw.startsWith('#') ||
        raw.startsWith('//') ||
        RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(raw)) {
      return null;
    }
    final variants = <String>{raw, _decode(raw)};
    final pathOnly = raw.split(RegExp(r'[?#]')).first;
    variants.addAll([pathOnly, _decode(pathOnly)]);
    for (final relative in variants) {
      final direct = relative.startsWith('/')
          ? p.join(root, relative.replaceFirst(RegExp(r'^/+'), ''))
          : p.join(p.absolute(from), relative);
      final normalized = p.normalize(direct);
      // 越出导出的相对路径不能通过文件名兜底重新绑定到无关文件。
      if (!p.isWithin(root, normalized)) continue;
      final exact = _exact[normalized] ?? _caseFolded[normalized.toLowerCase()];
      if (exact != null) return exact;
      if (matchStem) {
        final stem =
            _byDirectoryStem[p.withoutExtension(normalized).toLowerCase()];
        if (stem != null) return stem;
      }
    }
    if (!fallbackToName) return null;
    for (final relative in variants) {
      final direct = relative.startsWith('/')
          ? p.join(root, relative.replaceFirst(RegExp(r'^/+'), ''))
          : p.join(p.absolute(from), relative);
      if (!p.isWithin(root, p.normalize(direct))) continue;
      final named = _byName[p.posix.basename(relative).toLowerCase()];
      if (named != null) return named;
      if (matchStem) {
        final stem =
            _byStem[p.posix.basenameWithoutExtension(relative).toLowerCase()];
        if (stem != null) return stem;
      }
    }
    return null;
  }

  static String _decode(String text) {
    try {
      return Uri.decodeComponent(text);
    } on FormatException {
      return text;
    } on ArgumentError {
      return text;
    }
  }

  static void _addUnique(Map<String, String?> index, String key, String path) {
    if (index.containsKey(key)) {
      if (index[key] != path) index[key] = null;
    } else {
      index[key] = path;
    }
  }
}
