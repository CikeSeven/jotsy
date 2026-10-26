import 'dart:convert';

import '../audio_embed_codec.dart';
import '../divider_embed_codec.dart';
import '../file_embed_codec.dart';
import 'diary_blocks_schema.dart';

/// 历史 Quill 嵌入与块数据的字段映射；保留媒体 metadata 与未知嵌入。
/// 这里只转换单个嵌入，不决定块顺序、缩进或媒体文件的存储位置。

Map<String, Object?> diaryBlockFromQuillEmbed(
  Map<Object?, Object?> embed,
  Map<String, Object?> attributes,
  Map<String, Object?> lineAttributes,
) {
  final align = lineAttributes['align'];
  Map<String, Object?> node(String type, Map<String, Object?> data) {
    return <String, Object?>{
      kDiaryBlockTypeKey: type,
      if (data.isNotEmpty) kDiaryBlockDataKey: data,
    };
  }

  final image = embed['image'];
  if (embed.length == 1 && image is String) {
    return node(kDiaryBlockImage, <String, Object?>{
      kDiaryBlockUrlKey: image,
      // 显示上限写在嵌入的行内属性上（HTML 导入的宽高、缩放菜单的 style）。
      for (final key in const ['width', 'height', 'style'])
        if (attributes[key] case final value?) key: value,
      if (align is String && align.isNotEmpty) kDiaryBlockAlignKey: align,
    });
  }
  final video = embed['video'];
  if (embed.length == 1 && video is String) {
    return node(kDiaryBlockVideo, <String, Object?>{
      ...attributes,
      kDiaryBlockUrlKey: video,
    });
  }
  if (embed.length == 1 && embed.containsKey(diaryDividerEmbedType)) {
    return node(kDiaryBlockDivider, const <String, Object?>{});
  }
  if (embed.length == 1 &&
      DiaryAudioAttachment.tryDecode(embed[diaryAudioEmbedType]) != null) {
    final raw = embed[diaryAudioEmbedType];
    final decoded = raw is String ? jsonDecode(raw) as Map : raw as Map;
    return node(kDiaryBlockAudio, _stringKeyed(decoded));
  }
  for (final type in diaryFileEmbedTypes) {
    if (embed.length != 1 || !embed.containsKey(type)) continue;
    if (DiaryFileAttachment.tryDecode(embed[type]) == null) break;
    return node(kDiaryBlockAttachment, _attachmentData(embed[type]));
  }
  return node(kDiaryBlockUnknownEmbed, <String, Object?>{
    kDiaryBlockValueKey: _stringKeyed(embed),
  });
}

/// 附件数据保留来源里的全部字段（导入格式可能带名称、大小以外的
/// metadata），只把早期直接存路径字符串的写法补成 `{"path": …}`。
Map<String, Object?> _attachmentData(Object? raw) {
  Object? value = raw;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.startsWith('{')) {
      try {
        value = jsonDecode(trimmed);
      } on FormatException {
        value = null;
      }
    } else {
      return <String, Object?>{kDiaryBlockPathKey: trimmed};
    }
  }
  if (value is Map) return _stringKeyed(value);
  final file = DiaryFileAttachment.tryDecode(raw)!;
  return <String, Object?>{kDiaryBlockPathKey: file.path};
}

Map<String, Object?> _stringKeyed(Map<Object?, Object?> map) {
  return <String, Object?>{
    for (final entry in map.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}
