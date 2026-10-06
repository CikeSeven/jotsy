import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/core/database/file_embed_codec.dart';

/// PDF 无法播放视频或拉起私有附件，将文件块转成可读名称，保留原正文和图片。
/// 远程文件保留链接；本地文件名不会泄露导出设备的应用私有目录。
quill.Document buildDiaryPdfExportDocument(quill.Document document) {
  final ops = document.toDelta().toJson().map((original) {
    final op = Map<String, dynamic>.from(original);
    final insert = op['insert'];
    if (insert is! Map) return op;
    for (final type in ['video', ...diaryFileEmbedTypes]) {
      final file = DiaryFileAttachment.tryDecode(insert[type]);
      if (file == null) continue;
      op['insert'] = file.displayName;
      final uri = Uri.tryParse(file.path);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        op['attributes'] = {
          if (op['attributes'] is Map) ...op['attributes'] as Map,
          'link': file.path,
        };
      }
      break;
    }
    return op;
  }).toList();
  return quill.Document.fromJson(ops);
}
