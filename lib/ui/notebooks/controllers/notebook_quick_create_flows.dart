import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../pages/notebook_editor_page.dart';
import 'notebook_editor_controller.dart';
import '../sections/notebook_save_range_sheet.dart';
import '../viewmodels/notebook_rule_labels.dart';

/// 从别处“存为日记本”的快捷新建：都打开预填好的日记本编辑页，由用户确认
/// 名称与外观后保存，不在这里直接写库（收进日记除外，见下）。
///
/// - 日历范围：先算出这段日期里现在的日记（未删除、未归档、非私密，口径与
///   智能日记本相同），面板二选一：智能（日期区间规则）或普通（保存后按
///   发表时间旧→新收进这些日记）；两种都预填同一条区间规则——编辑页里改选
///   类型时规则仍在，保存为普通时编辑页不写规则；
/// - 搜索页：关键词 + 标签（全部都含）规则，名称取关键词或第一个标签。
///
/// 返回新建的日记本 id；取消或失败为 null（失败时提示）。

/// 由日历选中的一段日期（[first]..[last]，含首尾）新建日记本。
Future<String?> runSaveDateRangeAsNotebook(
  BuildContext context,
  WidgetRef ref, {
  required DateTime first,
  required DateTime last,
  DateTime? now,
}) async {
  final l10n = context.l10n;
  final database = ref.read(appDatabaseProvider);
  final rule = NotebookDateRule.between(first, last);
  final rules = NotebookRuleSet(rules: <NotebookRule>[rule]);
  final List<String> diaryIds;
  try {
    diaryIds = await database.getActiveDiaryIds(
      scope: DiarySmartScope(
        notebookId: '_range_',
        predicate: compileNotebookRules(rules, now: now),
      ),
      sortMode: DiarySortMode.createdAsc,
    );
  } catch (error) {
    debugPrint('Reading diaries in range failed: $error');
    if (context.mounted) {
      showStyleEditorMessage(context, l10n.notebookActionFailed);
    }
    return null;
  }
  if (!context.mounted) return null;
  final kind = await showNotebookSaveRangeSheet(
    context,
    count: diaryIds.length,
  );
  if (kind == null || !context.mounted) return null;
  final notebookId = await Navigator.of(context).push(
    NotebookEditorPage.route(
      initialKind: kind,
      initialName: notebookDateRangeLabel(
        l10n,
        rule.from!,
        rule.to!,
        now: now ?? DateTime.now(),
      ),
      initialPayload: NotebookPayload(rules: rules.encode()),
    ),
  );
  if (notebookId == null) return null;
  try {
    // 编辑页里可能改成了智能：只往普通日记本里收。
    final row = await database.getNotebook(notebookId);
    if (row != null && row.acceptsManualEntries && diaryIds.isNotEmpty) {
      await database.addDiariesToNotebook(notebookId, diaryIds);
    }
  } catch (error) {
    debugPrint('Adding range diaries to notebook failed: $error');
    if (context.mounted) {
      showStyleEditorMessage(context, l10n.notebookActionFailed);
    }
  }
  return notebookId;
}

/// 把搜索条件（[keyword] 与必须都带的 [tagNames]）存为智能日记本。两者都
/// 为空时什么也不做。
Future<String?> runSaveSearchAsSmartNotebook(
  BuildContext context, {
  required String keyword,
  required List<String> tagNames,
}) async {
  final text = keyword.trim();
  final rules = <NotebookRule>[
    if (text.isNotEmpty)
      NotebookTextRule(field: NotebookTextField.keyword, text: text),
    if (tagNames.isNotEmpty)
      NotebookTagsRule(mode: NotebookTagMatch.all, names: tagNames),
  ];
  if (rules.isEmpty) return null;
  // 名称框有长度上限，长关键词截到上限（按码点，不切开表情）。
  final name = String.fromCharCodes(
    (text.isNotEmpty ? text : tagNames.first).runes.take(
      NotebookEditorController.maxNameLength,
    ),
  );
  return Navigator.of(context).push(
    NotebookEditorPage.route(
      initialKind: NotebookKind.smart,
      initialName: name,
      initialPayload: NotebookPayload(
        rules: NotebookRuleSet(rules: rules).encode(),
      ),
    ),
  );
}
