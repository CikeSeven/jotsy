import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../../widgets/app_modal/app_dialog.dart';

/// 删除媒体前的确认：写明删几个文件、释放多少，会从哪些日记 / 日记本封面
/// / 留言 / 草稿 / AI 对话消息里移除，删除后无法恢复。左灰“取消”，右 error 色“删除”。
Future<bool> confirmStorageDelete(
  BuildContext context,
  List<StorageMediaEntry> entries,
) async {
  final diaries = <int>{};
  final notebooks = <int>{};
  final comments = <int>{};
  final drafts = <int>{};
  final aiMessages = <int>{};
  var capsule = false;
  var bytes = 0;
  for (final entry in entries) {
    bytes += entry.bytes;
    for (final ref in entry.refs) {
      switch (ref) {
        case StorageDiaryRef(:final diaryLocalId, :final visibility):
          diaries.add(diaryLocalId);
          if (visibility == StorageRefVisibility.capsule) capsule = true;
        case StorageNotebookCoverRef(:final notebookLocalId):
          notebooks.add(notebookLocalId);
        case StorageCommentRef(:final commentLocalId):
          comments.add(commentLocalId);
        case StorageDraftRef(:final draftLocalId):
          drafts.add(draftLocalId);
        case StorageAiMessageRef(:final messageLocalId):
          aiMessages.add(messageLocalId);
        case StorageOtherRef():
          break;
      }
    }
  }
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      final places = <String>[
        if (diaries.isNotEmpty)
          l10n.storageMgmtDeleteFromDiaries(diaries.length),
        if (notebooks.isNotEmpty)
          l10n.storageMgmtDeleteFromNotebooks(notebooks.length),
        if (comments.isNotEmpty)
          l10n.storageMgmtDeleteFromComments(comments.length),
        if (drafts.isNotEmpty) l10n.storageMgmtDeleteFromDrafts(drafts.length),
        if (aiMessages.isNotEmpty)
          l10n.storageMgmtDeleteFromAiChats(aiMessages.length),
      ];
      final notes = <String>[
        if (comments.isNotEmpty) l10n.storageMgmtDeleteCommentNote,
        if (aiMessages.isNotEmpty) l10n.storageMgmtDeleteAiChatNote,
        if (capsule) l10n.storageMgmtDeleteCapsuleNote,
        l10n.storageMgmtDeleteIrreversible,
      ];
      return AlertDialog(
        title: Text(l10n.storageMgmtDeleteTitle(entries.length)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.storageMgmtDeleteBody(l10n.formatByteSize(bytes))),
              for (final place in places)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text('· $place'),
                ),
              const SizedBox(height: AppSpacing.m),
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
