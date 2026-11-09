import 'dart:convert';

/// AI 对话里用户附图列（`ai_messages.images`，v22）的编解码，纯 Dart，可在
/// 后台 isolate（存储扫描、媒体回收）里使用。
///
/// 存储格式：没有图片为 NULL；有图片时为 JSON 字符串数组，元素是托管图片
/// （`diary_images/…`）的绝对路径，按用户添加的顺序。与留言图片一样存绝对
/// 路径，媒体回收、存储管理与备份重绑都按“最后一个托管目录名及之后的部分”
/// 定位文件。
///
/// 与留言图片的区别：**位置有意义**。对话里的图片按位置编号（P1、P2…，见
/// `aiChatImageRefs`），模型在之后的轮次里按编号引用它们（加进日记、重看），
/// 原样回放的提问里也写着这些编号。存储管理删掉一张图时不能把它从数组里
/// 拿掉（后面的编号会整体前移、指向别的图），而是把那一位写成空串
/// [kAiMessageImageRemoved]（“墓碑”）：编号不变，引用没了、文件可以删。
/// 因此这里的解码不去重、不丢空项。
///
/// 解码一律容错：NULL、空串、不是 JSON 数组的坏数据都按“没有图片”处理；
/// 数组里不是字符串的元素按墓碑处理（同样占一个位置）。

/// 一条消息最多附带的图片张数（输入栏里限制）。数据库层不截断。
const int kAiMessageMaxImages = 9;

/// 被删掉的图片在数组里留下的占位。
const String kAiMessageImageRemoved = '';

/// 解码 [raw]（`images` 列的原值）为按位置排列的路径；被删掉的位置为
/// [kAiMessageImageRemoved]。没有图片时为空列表。
List<String> decodeAiMessageImages(String? raw) {
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
  return List<String>.unmodifiable([
    for (final item in decoded)
      item is String ? item.trim() : kAiMessageImageRemoved,
  ]);
}

/// 把 [images]（按位置，可含墓碑）编码为 `images` 列的值；一张都没有时为
/// null。全是墓碑时仍然编码：位置要留着，编号才不会变。
String? encodeAiMessageImages(Iterable<String> images) {
  final list = [for (final image in images) image.trim()];
  return list.isEmpty ? null : jsonEncode(list);
}

/// 还在的图片（去掉墓碑），按位置顺序。
List<String> liveAiMessageImages(Iterable<String> images) => [
  for (final image in images)
    if (image.isNotEmpty) image,
];
