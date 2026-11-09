// 对话里用户附带的图片与它们的编号（纯函数）。
//
// 每张附图有一个编号 `P1`、`P2`…，整段对话连续。模型靠编号在之后的轮次里
// 指代图片（加进日记、重看），原样回放的提问里也写着这些编号，所以编号
// 必须一经发出就不再变：
// - 编号在发送时定下，记在那条消息的 `meta.imageRefs`（与 `images` 列按
//   位置一一对应）。删掉中间某条消息、存储管理删掉某张图（那一位留墓碑）
//   都不会让别的图片换号；
// - 新图片的编号接着整段对话里最大的编号往后编；
// - meta 缺失或与张数对不上（旧数据、坏数据）时，从当时最大的编号往后按
//   位置补，补出来的编号同样每次一致。

import 'dart:convert';

import '../../../core/database/app_database.dart';

/// 消息 meta 里记编号的键。
const String kAiImageRefsMetaKey = 'imageRefs';

final RegExp _refPattern = RegExp(r'^\s*\[?\s*[Pp](\d{1,6})\s*\]?\s*$');

/// 对话里的一张附图。
class AiChatImage {
  const AiChatImage({
    required this.ref,
    required this.messageId,
    required this.index,
    required this.path,
  });

  /// 编号，如 `P3`。
  final String ref;

  /// 所在用户消息的业务 id。
  final String messageId;

  /// 在那条消息图片列里的位置。
  final int index;

  /// 托管图片的绝对路径；被存储管理删掉时为空串（墓碑）。
  final String path;

  bool get removed => path.isEmpty;
}

/// 编号的数字部分（`P12` → 12）；不是编号时为 null。也认 `[P3]`、`p3`。
int? aiImageRefNumber(String raw) {
  final match = _refPattern.firstMatch(raw);
  return match == null ? null : int.parse(match.group(1)!);
}

/// 规整成 `P3` 的写法；不是编号时为 null。
String? aiNormalizeImageRef(String raw) {
  final number = aiImageRefNumber(raw);
  return number == null || number == 0 ? null : 'P$number';
}

/// 整段对话的附图，按消息顺序、消息内按位置。
List<AiChatImage> aiChatImages(Iterable<AiMessageRow> rows) {
  final result = <AiChatImage>[];
  var highest = 0;
  for (final row in rows) {
    if (row.role != AiMessageRole.user) continue;
    final paths = decodeAiMessageImages(row.images);
    if (paths.isEmpty) continue;
    final stored = _storedRefs(row.meta, paths.length);
    for (final (index, path) in paths.indexed) {
      final ref = stored?[index] ?? 'P${highest + 1}';
      final number = aiImageRefNumber(ref)!;
      if (number > highest) highest = number;
      result.add(
        AiChatImage(
          ref: ref,
          messageId: row.messageId,
          index: index,
          path: path,
        ),
      );
    }
  }
  return result;
}

/// 一条消息的附图（编号按整段对话 [rows] 算，[rows] 须含这条消息）。
List<AiChatImage> aiChatImagesOf(
  Iterable<AiMessageRow> rows,
  String messageId,
) => [
  for (final image in aiChatImages(rows))
    if (image.messageId == messageId) image,
];

/// 新附 [count] 张图片的编号：接着整段对话里最大的编号往后编。
List<String> aiNextImageRefs(Iterable<AiMessageRow> rows, int count) {
  var highest = 0;
  for (final image in aiChatImages(rows)) {
    final number = aiImageRefNumber(image.ref)!;
    if (number > highest) highest = number;
  }
  return [for (var i = 1; i <= count; i++) 'P${highest + i}'];
}

/// 按编号找附图；没有这个编号时为 null。
AiChatImage? aiChatImageByRef(Iterable<AiChatImage> images, String raw) {
  final ref = aiNormalizeImageRef(raw);
  if (ref == null) return null;
  for (final image in images) {
    if (image.ref == ref) return image;
  }
  return null;
}

/// 用户消息的 meta：发送时的编号（没有图片时不写）。
Map<String, Object?> aiImageRefsMeta(List<String> refs) => <String, Object?>{
  if (refs.isNotEmpty) kAiImageRefsMetaKey: refs,
};

/// meta 里记的编号；缺失、张数不对或有不合规 / 重复的编号时为 null。
List<String>? _storedRefs(String meta, int count) {
  final Object? decoded;
  try {
    decoded = jsonDecode(meta);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final raw = decoded[kAiImageRefsMetaKey];
  if (raw is! List || raw.length != count) return null;
  final refs = <String>[];
  for (final item in raw) {
    final ref = item is String ? aiNormalizeImageRef(item) : null;
    if (ref == null || refs.contains(ref)) return null;
    refs.add(ref);
  }
  return refs;
}
