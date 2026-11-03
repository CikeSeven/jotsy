import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';

/// AI 模块的确认对话框：左侧灰色“取消”，右侧主色确认；[destructive] 时
/// 右侧为 error 色（AGENTS.md §6 对话框按钮规则）。
Future<bool> confirmAiAction(
  BuildContext context, {
  required String title,
  required String action,
  String? content,
  bool destructive = false,
}) async {
  final result = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: content == null ? null : Text(content),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: destructive ? colors.error : colors.primary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// 显示一段可复制的原文（错误详情、请求内容等）。
Future<void> showAiDetailDialog(
  BuildContext context, {
  required String title,
  required String text,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
              contextMenuBuilder: appTextContextMenuBuilder,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.commonClose),
          ),
        ],
      );
    },
  );
}
