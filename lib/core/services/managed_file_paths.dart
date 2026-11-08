import 'dart:io';

import 'package:path/path.dart' as p;

/// 与 [source] 同目录、主名相同、扩展名为 [extension]（不带点）的新路径；
/// 已被占用时依次加 `_1`、`_2`…
///
/// 托管媒体的重编码（HEIC 转 JPEG、存储管理的压缩）一律写到新路径再改写
/// 引用，从不覆盖已有文件：那可能是别处引用着的另一张图，原地改写还会让
/// 局域网同步的对端永远拿不到新内容（同步按引用的路径判断要不要传文件）。
String freshSiblingPath(String source, String extension) {
  final directory = p.dirname(source);
  final stem = p.basenameWithoutExtension(source);
  var candidate = p.join(directory, '$stem.$extension');
  for (var index = 1; File(candidate).existsSync(); index++) {
    candidate = p.join(directory, '${stem}_$index.$extension');
  }
  return candidate;
}
