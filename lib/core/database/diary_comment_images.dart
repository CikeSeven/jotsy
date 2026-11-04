import 'dart:convert';

/// 留言图片列（`diary_comments.images`）的编解码，纯 Dart，可在后台 isolate
/// 与同步规范化里使用。
///
/// 存储格式：没有图片为 NULL；有图片时为 JSON 字符串数组，元素是托管图片
/// （`diary_images/…`）的绝对路径，按用户添加的顺序。与日记正文一样存绝对
/// 路径：媒体回收、备份重绑与局域网同步都按“最后一个托管目录名及之后的部分”
/// 定位文件，换了数据根目录也认得出。
///
/// 解码一律容错：NULL、空串、不是 JSON 数组的坏数据都按“没有图片”处理；
/// 数组里只认非空字符串（去掉首尾空白），重复的路径只留第一次出现的。编码
/// 与解码互为幂等：`encode(decode(x))` 再解码得到同一个列表——同步要求同一份
/// 数据在每台设备上算出逐字节相同的规范值。

/// 一条留言最多附带的图片张数（写留言面板里限制）。数据库层不截断：备份或
/// 同步来的更多图片原样保留，显示时超出的折进最后一格的“+N”。
const int kDiaryCommentMaxImages = 9;

/// 解码 [raw]（`images` 列的原值）为图片路径列表；没有图片时为空列表。
List<String> decodeDiaryCommentImages(String? raw) {
  if (raw == null) return const <String>[];
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const <String>[];
  final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    return const <String>[];
  }
  if (decoded is! List) return const <String>[];
  return normalizeDiaryCommentImages(decoded.whereType<String>());
}

/// 把 [images] 编码为 `images` 列的值；规整后为空时为 null（不存空数组，
/// 没有图片的行与加图片之前的版本完全相同）。
String? encodeDiaryCommentImages(Iterable<String> images) {
  final normalized = normalizeDiaryCommentImages(images);
  return normalized.isEmpty ? null : jsonEncode(normalized);
}

/// 去掉首尾空白与空项、按首次出现去重，保持原顺序。
List<String> normalizeDiaryCommentImages(Iterable<String> images) {
  final seen = <String>{};
  final result = <String>[];
  for (final image in images) {
    final path = image.trim();
    if (path.isEmpty || !seen.add(path)) continue;
    result.add(path);
  }
  return List<String>.unmodifiable(result);
}
