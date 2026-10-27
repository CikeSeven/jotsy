import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/app_modal/app_dialog.dart';

/// 确认删除远程的一份备份（不可撤销，部分网盘会进入其回收站）。
Future<bool> confirmCloudBackupDelete(BuildContext context, String fileName) {
  final l10n = context.l10n;
  return _confirmDestructive(
    context,
    title: l10n.cloudBackupDeleteConfirmTitle,
    content: l10n.cloudBackupDeleteConfirmContent(fileName),
    action: l10n.cloudBackupDeleteAction,
  );
}

/// 确认移除备份位置：只清除本机保存的连接与授权，网盘里的备份文件保留。
Future<bool> confirmCloudBackupRemoveTarget(BuildContext context) {
  final l10n = context.l10n;
  return _confirmDestructive(
    context,
    title: l10n.cloudBackupRemoveTargetTitle,
    content: l10n.cloudBackupRemoveTargetContent,
    action: l10n.cloudBackupRemoveTargetAction,
  );
}

Future<bool> _confirmDestructive(
  BuildContext context, {
  required String title,
  required String content,
  required String action,
}) async {
  final result = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      );
    },
  );
  return result == true;
}
