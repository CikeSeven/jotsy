import 'dart:convert';

import 'package:path/path.dart' as p;

const String diaryAttachmentEmbedType = 'attachment';
const List<String> diaryFileEmbedTypes = [diaryAttachmentEmbedType, 'file'];

/// 正文文件的持久化数据；兼容导入文件的路径字符串和旧版 url/size 字段。
/// 只负责映射，不读取文件，也不触发系统打开操作。
class DiaryFileAttachment {
  const DiaryFileAttachment({required this.path, this.name, this.sizeBytes});

  final String path;
  final String? name;
  final int? sizeBytes;

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    final filePath = uri != null && uri.hasScheme ? uri.path : path;
    return p.posix.basename(filePath.replaceAll('\\', '/'));
  }

  String encode() => jsonEncode(<String, Object?>{
    'path': path,
    if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
  });

  static DiaryFileAttachment? tryDecode(Object? data) {
    Object? value = data;
    if (value is String) {
      value = value.trim();
      if (value.isEmpty) return null;
      // 普通路径直接可用；看起来是 JSON 的坏数据不能被误当作文件路径。
      if (value.startsWith('{') ||
          value.startsWith('[') ||
          value.startsWith('"')) {
        try {
          value = jsonDecode(value);
        } on FormatException {
          return null;
        }
      }
    }
    if (value is String && value.trim().isNotEmpty) {
      return DiaryFileAttachment(path: value.trim());
    }
    if (value is! Map) return null;
    final path = value['path'] ?? value['url'];
    if (path is! String || path.trim().isEmpty) return null;
    final name = value['name'] ?? value['fileName'];
    final size = value['sizeBytes'] ?? value['size'];
    return DiaryFileAttachment(
      path: path.trim(),
      name: name is String && name.trim().isNotEmpty ? name.trim() : null,
      sizeBytes: size is num && size.isFinite && size >= 0
          ? size.toInt()
          : null,
    );
  }
}

/// 恢复备份时只替换文件引用，保留名称、大小和导入格式的其他 metadata。
Object? replaceDiaryFilePath(Object? data, String path) {
  if (data is Map) {
    return Map<String, dynamic>.from(data)
      ..[data.containsKey('path') ? 'path' : 'url'] = path;
  }
  if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return jsonEncode(replaceDiaryFilePath(decoded, path));
      }
    } on FormatException {
      // 标准 Quill 视频以及早期附件直接存储路径字符串。
    }
    return path;
  }
  return data;
}

/// 提取 Quill 或旧版 AppFlowy 正文中的视频/附件引用，用于托管资源清理。
Set<String> extractDiaryFilePaths(String content) {
  final paths = <String>{};
  void collect(Object? node) {
    if (node is List) {
      for (final child in node) {
        collect(child);
      }
    } else if (node is Map) {
      final insert = node['insert'];
      if (insert is Map) {
        for (final type in ['video', ...diaryFileEmbedTypes]) {
          final file = DiaryFileAttachment.tryDecode(insert[type]);
          if (file != null) paths.add(file.path);
        }
      }
      if (node['type'] == 'video' ||
          diaryFileEmbedTypes.contains(node['type'])) {
        final file = DiaryFileAttachment.tryDecode(node['attributes']);
        if (file != null) paths.add(file.path);
      }
      for (final child in node.values) {
        collect(child);
      }
    }
  }

  try {
    collect(jsonDecode(content));
  } on FormatException {
    // 历史纯文本正文没有需要清理的文件引用。
  }
  return paths;
}
