import 'dart:io';

import 'package:flutter/widgets.dart';

/// 应用内置图片的来源前缀（设置页示例日记的封面）：`asset:<资源路径>`。
const String diaryAssetImageScheme = 'asset:';

/// 日记图片来源（封面、正文图）对应的 [ImageProvider]：`asset:` 为应用内置
/// 资源，http(s) 为网络图片，其余为本地文件路径。来源两端的空白会被忽略。
ImageProvider diaryImageProvider(String source) {
  final trimmed = source.trim();
  if (trimmed.startsWith(diaryAssetImageScheme)) {
    return AssetImage(trimmed.substring(diaryAssetImageScheme.length));
  }
  final uri = Uri.tryParse(trimmed);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return NetworkImage(trimmed);
  }
  return FileImage(File(trimmed));
}
