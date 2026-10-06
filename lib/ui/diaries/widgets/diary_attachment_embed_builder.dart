import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/file_open_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_tile.dart';

/// attachment 为新正文格式，file 别名让导入的既有附件同样可点击打开。
class DiaryAttachmentEmbedBuilder extends quill.EmbedBuilder {
  const DiaryAttachmentEmbedBuilder({
    this.embedType = diaryAttachmentEmbedType,
    this.openService = const FileOpenService(),
  });

  final String embedType;
  final FileOpenService openService;

  @override
  String get key => embedType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final file = DiaryFileAttachment.tryDecode(embedContext.node.value.data);
    if (file == null) {
      return Text(
        context.l10n.attachmentFileMissing,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return DiaryAttachmentTile(
      key: ValueKey(file.path),
      attachment: file,
      openService: openService,
    );
  }
}
