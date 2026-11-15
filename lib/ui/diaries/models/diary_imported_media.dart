import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:path/path.dart' as p;

import 'recording_insertion.dart';

/// 正文图片块能显示的格式；其余按扩展名分到视频、音频或附件。
const Set<String> diaryImportImageExtensions = <String>{
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.bmp',
};

const Set<String> diaryImportVideoExtensions = <String>{
  '.mp4',
  '.mov',
  '.m4v',
  '.3gp',
  '.avi',
  '.webm',
  '.mkv',
};

/// 可能做成录音块的音频（#251，系统录音机、通话录音、音乐等常见格式）。
/// 只是候选：导入时还要用播放器读出时长（见 probeAudioDuration），读不出
/// （本机播不了，如 Windows 上的 AMR / Opus）的照旧当附件。
const Set<String> diaryImportAudioExtensions = <String>{
  '.m4a',
  '.mp3',
  '.aac',
  '.amr',
  '.awb',
  '.3ga',
  '.wav',
  '.ogg',
  '.oga',
  '.opus',
  '.flac',
  '.wma',
};

bool isDiaryImportAudioName(String name) =>
    diaryImportAudioExtensions.contains(p.extension(name).toLowerCase());

/// 导入的一份文件：复制进哪个托管目录（[kind]）、复制后的文件，以及做成
/// 录音块时读出的时长。
class DiaryImportedMedia {
  const DiaryImportedMedia({
    required this.kind,
    required this.file,
    this.duration,
  });

  final DiaryMediaKind kind;
  final DiaryFileAttachment file;

  /// 只有 [kind] 为音频时有值。
  final Duration? duration;

  /// 插进正文的块（图片另走 insertDiaryImages，不经这里）。
  af.Node toNode() => switch (kind) {
    DiaryMediaKind.video => af.Node(
      type: 'video',
      attributes: {'url': file.path},
    ),
    // 录音块的名称取文件名（去掉扩展名），没有声纹：正文卡片按路径与时长
    // 合成一条示意声纹，与导入第三方日记的录音相同。
    DiaryMediaKind.audio => diaryAudioNode(
      DiaryAudioAttachment(
        path: file.path,
        duration: duration ?? Duration.zero,
        name: p.basenameWithoutExtension(file.displayName),
      ),
    ),
    DiaryMediaKind.image || DiaryMediaKind.attachment => af.Node(
      type: diaryAttachmentEmbedType,
      attributes: {
        'path': file.path,
        if (file.name != null) 'name': file.name,
        if (file.sizeBytes != null) 'sizeBytes': file.sizeBytes,
      },
    ),
  };
}
