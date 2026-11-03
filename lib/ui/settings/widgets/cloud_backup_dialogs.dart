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

/// 确认删除一份增量备份（只被它用到的媒体一并清理）。
Future<bool> confirmCloudIncrementalDelete(BuildContext context, String time) {
  final l10n = context.l10n;
  return _confirmDestructive(
    context,
    title: l10n.cloudIncrementalDeleteTitle,
    content: l10n.cloudIncrementalDeleteContent(time),
    action: l10n.cloudBackupDeleteAction,
  );
}

/// 确认忘记本机记住的增量备份密码。[content] 默认是主动“重新设置密码”的
/// 说明；记住的密码已打不开网盘上的备份时传入对应说明。
Future<bool> confirmCloudIncrementalForget(
  BuildContext context, {
  String? content,
}) {
  final l10n = context.l10n;
  return _confirmDestructive(
    context,
    title: content == null
        ? l10n.cloudIncrementalForgetTitle
        : l10n.cloudIncrementalWrongPasswordTitle,
    content: content ?? l10n.cloudIncrementalForgetContent,
    action: l10n.cloudIncrementalForgetChain,
  );
}

/// 接上已有增量备份时的二选一：沿用（右侧主色）或开始新的一串（左侧）。
enum CloudIncrementalChainAnswer { continueExisting, startNew }

/// 网盘上已有不加密的增量备份：接着备份，还是开始新的一串（以便加密）。
/// 点外面关闭为 null，即取消这次备份。
Future<CloudIncrementalChainAnswer?> askCloudIncrementalExistingPlain(
  BuildContext context,
) {
  final l10n = context.l10n;
  return _askChain(
    context,
    title: l10n.cloudIncrementalExistingPlainTitle,
    content: l10n.cloudIncrementalExistingPlainContent,
    continueLabel: l10n.cloudIncrementalContinueExisting,
  );
}

/// 输入的密码打不开已有的增量备份：重新输入，还是开始新的一串。
Future<CloudIncrementalChainAnswer?> askCloudIncrementalWrongPassword(
  BuildContext context,
) {
  final l10n = context.l10n;
  return _askChain(
    context,
    title: l10n.cloudIncrementalWrongPasswordTitle,
    content: l10n.cloudIncrementalWrongPasswordContent,
    continueLabel: l10n.cloudIncrementalRetry,
  );
}

Future<CloudIncrementalChainAnswer?> _askChain(
  BuildContext context, {
  required String title,
  required String content,
  required String continueLabel,
}) {
  return showAppDialog<CloudIncrementalChainAnswer>(
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
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(CloudIncrementalChainAnswer.startNew),
            child: Text(dialogContext.l10n.cloudIncrementalStartNew),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(CloudIncrementalChainAnswer.continueExisting),
            child: Text(continueLabel),
          ),
        ],
      );
    },
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
