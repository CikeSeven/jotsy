import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/device_auth_service.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../pages/notebook_editor_page.dart';
import '../viewmodels/notebook_view.dart';

/// 打开这本日记本前是否要验证身份。
bool notebookRequiresAuth(NotebookView notebook) =>
    notebook.visibility == NotebookVisibility.locked;

/// 进入日记本前的身份验证（只有上锁的需要）。
///
/// 流程：
/// 1. 不需要验证 → 直接放行；
/// 2. 设备不能验证身份（没有锁屏密码）→ 不放行，弹框说明上锁的日记本在这台
///    设备上打不开、建议先设置锁屏密码。弹框只有“知道了”：此前的“去设置”
///    直接打开编辑页，等于绕过验证就能把隐私改回正常；
/// 3. 弹出系统验证，取消或失败 → 不放行，调用方停留在原处。
///
/// 不只是“进入”：打开上锁日记本的编辑页、合并、删除（两种删法都会让日记
/// 重新出现在全部日记里）同样先经过这里，见 `runNotebookAction` 与
/// [openNotebookEditor]。
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
    await _showUnsupportedDialog(context);
    return false;
  }
  return auth.authenticate(
    reason: context.l10n.notebookUnlockReason(notebook.name),
    persistAcrossBackgrounding: false,
  );
}

/// 打开 [notebook] 的编辑页。上锁的先验证（编辑页能改隐私、看到设置），
/// 未通过时什么也不做；[authorized] 为 true 表示调用方已在这本的解锁范围里
/// （首页头部卡片的“更多”），不再重复验证。
Future<void> openNotebookEditor(
  BuildContext context,
  WidgetRef ref,
  NotebookView notebook, {
  bool authorized = false,
}) async {
  if (!authorized) {
    final allowed = await authorizeNotebookEntry(context, ref, notebook);
    if (!allowed || !context.mounted) {
      return;
    }
  }
  await Navigator.of(
    context,
  ).push(NotebookEditorPage.route(notebookId: notebook.id));
}

/// 设备没有锁屏密码：说明上锁的日记本在这台设备上打不开，只有“知道了”。
Future<void> _showUnsupportedDialog(BuildContext context) {
  final l10n = context.l10n;
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(l10n.notebookLockUnsupportedTitle),
      content: Text(l10n.notebookLockUnsupportedMessage),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.notebookLockUnsupportedAction),
        ),
      ],
    ),
  );
}
