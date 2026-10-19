import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/device_auth_service.dart';
import '../pages/notebook_editor_page.dart';
import '../viewmodels/notebook_view.dart';

/// 打开这本日记本前是否要验证身份。
bool notebookRequiresAuth(NotebookView notebook) =>
    notebook.visibility == NotebookVisibility.locked;

/// 进入日记本前的身份验证（只有上锁的需要）。
///
/// 流程：
/// 1. 不需要验证 → 直接放行；
/// 2. 设备不能验证身份（没有锁屏密码）→ 不放行，弹框说明并建议把隐私改为
///    “不在全部日记中显示”（“去设置”打开日记本编辑页）；
/// 3. 弹出系统验证，取消或失败 → 不放行，调用方停留在原处。
///
/// 验证中途切到后台视为取消（`persistAcrossBackgrounding: false`），回来后
/// 由用户重新点开。
Future<bool> authorizeNotebookEntry(
  BuildContext context,
  WidgetRef ref,
  NotebookView notebook,
) async {
  if (!notebookRequiresAuth(notebook)) {
    return true;
  }
  final auth = ref.read(deviceAuthServiceProvider);
  final supported = await auth.isSupported();
  if (!context.mounted) {
    return false;
  }
  if (!supported) {
    await _showUnsupportedDialog(context, notebook);
    return false;
  }
  return auth.authenticate(
    reason: context.l10n.notebookUnlockReason(notebook.name),
    persistAcrossBackgrounding: false,
  );
}

/// 设备没有锁屏密码：说明无法打开，“去设置”进入这本的编辑页改隐私。
Future<void> _showUnsupportedDialog(
  BuildContext context,
  NotebookView notebook,
) async {
  final l10n = context.l10n;
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(l10n.notebookLockUnsupportedTitle),
        content: Text(l10n.notebookLockUnsupportedMessage),
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
            child: Text(l10n.notebookLockUnsupportedAction),
          ),
        ],
      );
    },
  );
  if (openSettings == true && context.mounted) {
    await Navigator.of(
      context,
    ).push(NotebookEditorPage.route(notebookId: notebook.id));
  }
}
