import 'dart:async';

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../models/anniversary_draft.dart';
import '../pages/anniversary_edit_page.dart';
import 'anniversary_edit_controller.dart';

/// 撤销提示的停留时间（非动画计时）；无障碍下也到时关闭。
const Duration _undoDuration = Duration(seconds: 5);

/// 打开纪念日编辑页（新建或编辑），关闭后在 [context] 所在页面给出提示：
/// 新建 → “已添加”；删除 → 可撤销的“已删除”。返回编辑页带回的结果。
///
/// 提示用打开方的 context：编辑页已出栈，它的 ScaffoldMessenger 位置不再
/// 可见。[database] 用于撤销删除。
Future<AnniversaryEditResult?> openAnniversaryEditor(
  BuildContext context, {
  required AppDatabase database,
  required AnniversaryDraft draft,
  Anniversary? editing,
}) async {
  final result = await Navigator.of(context).push<AnniversaryEditResult>(
    MaterialPageRoute<AnniversaryEditResult>(
      builder: (BuildContext context) =>
          AnniversaryEditPage(initialDraft: draft, editing: editing),
    ),
  );
  if (result == null || !context.mounted) {
    return result;
  }
  switch (result) {
    case AnniversaryCreated():
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(content: Text(context.l10n.anniversaryCreated)),
        ),
      );
    case AnniversaryDeleted(:final row):
      unawaited(showAnniversaryDeletedUndo(context, database, row));
    case AnniversaryUpdated():
      break;
  }
  return result;
}

/// “已删除纪念日”提示，点撤销把整行原样写回。
Future<void> showAnniversaryDeletedUndo(
  BuildContext context,
  AppDatabase database,
  Anniversary row,
) async {
  var undo = false;
  final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(context.l10n.anniversaryDeleted),
      duration: _undoDuration,
      action: SnackBarAction(
        label: context.l10n.commonUndo,
        onPressed: () => undo = true,
      ),
    ),
    forceCloseAfter: _undoDuration,
  );
  if (undo || reason == SnackBarClosedReason.action) {
    await database.restoreAnniversary(row);
  }
}
