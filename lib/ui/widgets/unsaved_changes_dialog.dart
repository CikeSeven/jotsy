import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'app_modal/app_dialog.dart';

/// 离开页面时对“未保存改动”的处理选择。
enum UnsavedChangesDecision { cancel, discard, saveAndExit }

/// 统一的未保存改动确认框（编辑页、设置排序页等共用）。
///
/// 按钮遵循对话框规范：左侧灰色“取消”，中间危险色“放弃”，右侧主色
/// “保存并退出”。点击遮罩关闭视为取消。
Future<UnsavedChangesDecision> showUnsavedChangesDialog(
  BuildContext context,
) async {
  final decision = await showAppDialog<UnsavedChangesDecision>(
    context: context,
    builder: (BuildContext dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;
      final l10n = dialogContext.l10n;
      return AlertDialog(
        title: Text(l10n.autoT0131),
        content: Text(l10n.autoT0207),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
            onPressed: () =>
                Navigator.of(dialogContext).pop(UnsavedChangesDecision.cancel),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () =>
                Navigator.of(dialogContext).pop(UnsavedChangesDecision.discard),
            child: Text(l10n.autoT0132),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(UnsavedChangesDecision.saveAndExit),
            child: Text(l10n.editSaveAndExit),
          ),
        ],
      );
    },
  );
  return decision ?? UnsavedChangesDecision.cancel;
}
