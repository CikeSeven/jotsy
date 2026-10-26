import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../providers/notebook_providers.dart';
import '../sections/notebook_picker_sheet.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_membership_ops.dart';

/// 单篇日记的“收进日记本”：预览页“更多”与桌面列表卡片的右键菜单共用。
///
/// 选择器的初始勾选为这篇现在所在的本子，确认后经 [NotebookMembershipOps]
/// 一次写入全部变化并提示（收进私密日记本时说明它只在那本里显示）；写入
/// 失败时只提示，不改动数据（事务整体回滚）。
Future<void> pickNotebooksForDiary(
  BuildContext context,
  WidgetRef ref, {
  required String diaryId,
}) async {
  final database = ref.read(appDatabaseProvider);
  final current = await database.getDiaryNotebookIds(diaryId);
  if (!context.mounted) return;
  final result = await showNotebookPickerSheet(
    context,
    initial: <String, NotebookPickState>{
      for (final id in current) id: NotebookPickState.all,
    },
  );
  if (result == null || !context.mounted) return;
  final l10n = context.l10n;
  final notebooks = ref.read(notebooksProvider).value ?? const <NotebookView>[];
  String message;
  try {
    await NotebookMembershipOps(database).apply(result, <String>[diaryId]);
    ref.invalidate(diaryNotebooksProvider(diaryId));
    message =
        notebookPrivateAddedHint(l10n, result.add, notebooks) ??
        (result.remove.isEmpty
            ? l10n.notebookAddedToCount(result.add.length)
            : l10n.notebookMembershipUpdated);
  } catch (error) {
    debugPrint('Updating diary notebooks failed: $error');
    message = l10n.notebookActionFailed;
  }
  if (!context.mounted) return;
  await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ),
  );
}
