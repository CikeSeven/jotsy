import '../audio_embed_codec.dart';
import '../file_embed_codec.dart';
import 'diary_blocks_codec.dart';
import 'diary_blocks_schema.dart';
import 'diary_blocks_walk.dart';

/// 正文媒体引用的统一入口：兼容解码后按块顺序扫描，或原地改写媒体路径。
/// 不读取文件；备份层传入路径映射并负责检查文件是否存在。只访问明确的媒体
/// 字段，不把正文文字、链接或 metadata 中恰好同名的键当作媒体。

enum DiaryBlockMediaKind { image, video, audio, attachment }

class DiaryBlockMedia {
  const DiaryBlockMedia(this.kind, this.path);

  final DiaryBlockMediaKind kind;

  /// 损坏的录音/附件仍计入媒体数量，但没有可提取或重绑的路径。
  final String? path;
}

Iterable<DiaryBlockMedia> diaryContentMedia(String content) =>
    diaryBlocksMedia(decodeStoredDiaryBlocks(content));

Iterable<DiaryBlockMedia> diaryBlocksMedia(
  Map<String, Object?> document,
) sync* {
  for (final (node, _) in walkDiaryBlocks(document)) {
    final data = diaryBlockData(node);
    final type = node[kDiaryBlockTypeKey];
    if (type == kDiaryBlockUnknownEmbed) {
      // 无法完整解析的历史嵌入仍保留在 value 中；统计与路径提取不能因此
      // 漏掉其中可识别的媒体，尤其是旧版多键嵌入。
      final value = data[kDiaryBlockValueKey];
      if (value is Map) {
        for (final entry in value.entries) {
          final media = _media(entry.key, entry.value);
          if (media != null) yield media;
        }
      }
    } else {
      final media = _media(type, data);
      if (media != null) yield media;
    }
  }
}

DiaryBlockMedia? _media(Object? type, Object? data) {
  final kind = switch (type) {
    kDiaryBlockImage => DiaryBlockMediaKind.image,
    kDiaryBlockVideo => DiaryBlockMediaKind.video,
    kDiaryBlockAudio => DiaryBlockMediaKind.audio,
    kDiaryBlockAttachment || 'file' => DiaryBlockMediaKind.attachment,
    _ => null,
  };
  if (kind == null) return null;
  final path = kind == DiaryBlockMediaKind.audio
      ? DiaryAudioAttachment.tryDecode(data)?.path
      : DiaryFileAttachment.tryDecode(data)?.path;
  if (kind == DiaryBlockMediaKind.image && path == null) return null;
  return DiaryBlockMedia(kind, path);
}

/// 按正文顺序返回图片来源，保留重复项，由调用方决定是否去重。
Iterable<String> extractDiaryImageSources(String content) sync* {
  for (final media in diaryContentMedia(content)) {
    if (media.kind == DiaryBlockMediaKind.image && media.path != null) {
      yield media.path!;
    }
  }
}

Set<String> extractDiaryAudioPaths(String content) => <String>{
  for (final media in diaryContentMedia(content))
    if (media.kind == DiaryBlockMediaKind.audio && media.path != null)
      media.path!,
};

/// 视频和附件都属于托管文件；图片、录音由各自的存储服务管理。
Set<String> extractDiaryFilePaths(String content) => <String>{
  for (final media in diaryContentMedia(content))
    if ((media.kind == DiaryBlockMediaKind.video ||
            media.kind == DiaryBlockMediaKind.attachment) &&
        media.path != null)
      media.path!,
};

/// 原地重绑文档中的路径，完整保留媒体的显示属性及未知 metadata。
/// 调用方应传入本次解码得到的独立文档；异步映射依次执行，备份层据此记录
/// 实际引用的暂存文件，避免遗漏嵌套块或重复搬运共享文件。
Future<void> rewriteDiaryBlocksMediaPaths(
  Map<String, Object?> document,
  Future<String> Function(DiaryBlockMediaKind kind, String path) rewrite,
) async {
  for (final (node, _) in walkDiaryBlocks(document)) {
    final data = diaryBlockData(node);
    if (node[kDiaryBlockTypeKey] == kDiaryBlockUnknownEmbed) {
      final value = data[kDiaryBlockValueKey];
      if (value is! Map) continue;
      final updated = Map<String, Object?>.from(value);
      for (final entry in updated.entries.toList()) {
        final media = _media(entry.key, entry.value);
        if (media?.path case final path?) {
          final target = await rewrite(media!.kind, path);
          if (target != path) {
            updated[entry.key] = replaceDiaryFilePath(entry.value, target);
          }
        }
      }
      node[kDiaryBlockDataKey] = Map<String, Object?>.of(data)
        ..[kDiaryBlockValueKey] = updated;
      continue;
    }
    final media = _media(node[kDiaryBlockTypeKey], data);
    if (media?.path case final path?) {
      final target = await rewrite(media!.kind, path);
      if (target != path) {
        node[kDiaryBlockDataKey] = replaceDiaryFilePath(data, target);
      }
    }
  }
}
