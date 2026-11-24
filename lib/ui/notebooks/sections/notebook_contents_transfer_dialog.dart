import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../viewmodels/notebook_view.dart';

/// 转移后日记的私密可见性会怎么变：只看普通 ↔ 私密（隐藏与上锁都不在全部
/// 日记里出现，两者之间转移不影响全部日记）。没有日记要搬时不提示。
enum NotebookTransferPrivacyChange {
  none,

  /// 普通本 → 私密子本：移入的日记不再出现在全部日记里。
  becomesPrivate,

  /// 私密本 → 普通上级：移入的日记会出现在全部日记里。
  becomesPublic;

  static NotebookTransferPrivacyChange of({
    required NotebookView source,
    required NotebookView target,
    required int entryCount,
  }) {
    if (entryCount == 0 || source.isPrivate == target.isPrivate) return none;
    return target.isPrivate ? becomesPrivate : becomesPublic;
  }
}

/// 转移确认框：写明即将搬运的章节数、日记篇数与目标本；私密可见性会变时附带
/// 说明。确认键为主色（不删除任何日记，且转移后可撤销）。
Future<bool> showNotebookContentsTransferDialog(
  BuildContext context, {
  required NotebookView source,
  required NotebookView target,
  required int chapterCount,
  required int entryCount,
  NotebookChapter? chapter,
}) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      final message = _confirmMessage(
        l10n,
        sourceName: source.name,
        targetName: target.name,
        chapterCount: chapterCount,
        entryCount: entryCount,
        chapter: chapter,
      );
      final privacyNote = switch (NotebookTransferPrivacyChange.of(
        source: source,
        target: target,
        entryCount: entryCount,
      )) {
        NotebookTransferPrivacyChange.none => null,
        NotebookTransferPrivacyChange.becomesPrivate =>
          l10n.notebookContentsTransferPrivateNote(target.name),
        NotebookTransferPrivacyChange.becomesPublic =>
          l10n.notebookContentsTransferPublicNote(target.name),
      };
      return AlertDialog(
        title: Text(l10n.notebookContentsTransferConfirmTitle),
        content: privacyNote == null
            ? Text(message)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(message),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    privacyNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.notebookContentsTransferAction),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

String _confirmMessage(
  AppLocalizations l10n, {
  required String sourceName,
  required String targetName,
  required int chapterCount,
  required int entryCount,
  required NotebookChapter? chapter,
}) {
  if (chapter != null) {
    return entryCount > 0
        ? l10n.notebookChapterTransferConfirm(
            chapter.title,
            entryCount,
            sourceName,
            targetName,
          )
        : l10n.notebookChapterTransferConfirmEmpty(
            chapter.title,
            sourceName,
            targetName,
          );
  }
  if (chapterCount > 0 && entryCount > 0) {
    return l10n.notebookContentsTransferConfirmAll(
      sourceName,
      chapterCount,
      entryCount,
      targetName,
    );
  }
  if (chapterCount > 0) {
    return l10n.notebookContentsTransferConfirmChaptersOnly(
      sourceName,
      chapterCount,
      targetName,
    );
  }
  return l10n.notebookContentsTransferConfirmEntriesOnly(
    sourceName,
    entryCount,
    targetName,
  );
}
