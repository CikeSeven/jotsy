import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/storage/storage_duplicates.dart';
import '../../widgets/app_modal/app_dialog.dart';

/// 合并重复文件前的确认：删掉几个副本、释放多少，日记看到的不变；再提醒
/// 合并之后在存储管理里删除保留的那份，会从所有用到它的地方一起移除。
/// 合并不丢内容，确认按钮用主色（不是删除的 error 色）。
Future<bool> confirmStorageMerge(
  BuildContext context,
  List<StorageDuplicateGroup> groups,
) async {
  var copies = 0;
  var bytes = 0;
  for (final group in groups) {
    copies += group.copies.length;
    bytes += group.savedBytes;
  }
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      return AlertDialog(
        title: Text(l10n.storageMgmtMergeTitle(copies)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.storageMgmtMergeBody(l10n.formatByteSize(bytes))),
              const SizedBox(height: AppSpacing.m),
              Text(
                l10n.storageMgmtMergeNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
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
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.storageMgmtMerge),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
