import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../notebooks/sections/notebook_rule_sheets.dart';
import '../models/diary_search_filters.dart';
import '../sections/diary_search_tag_sheet.dart';
import 'diary_search_controller.dart';

/// 搜索页筛选胶囊的选择流程：打开对应的面板，把结果写回搜索会话。
///
/// 时间、心情、媒体、天气、地点直接复用智能日记本的规则编辑面板
/// （[showNotebookRuleEditorSheet]），选好点“完成”才生效；关闭面板（返回
/// null）不改动，清除走胶囊行尾的 ×。标签面板点选即生效。

/// 打开 [slot] 的规则面板，以当前规则为初值。
Future<void> pickDiarySearchFilter(
  BuildContext context,
  DiarySearchController session,
  DiarySearchFilterSlot slot,
) async {
  final NotebookRule? picked = await showNotebookRuleEditorSheet(
    context,
    type: slot.ruleType,
    initial: session.filters.ruleOf(slot),
  );
  if (picked == null) return;
  session.setFilter(slot, picked);
}

/// 打开标签面板；勾选变化实时写回。
Future<void> pickDiarySearchTags(
  BuildContext context,
  DiarySearchController session,
) {
  return showDiarySearchTagSheet(
    context,
    selected: session.tagIds,
    onChanged: session.setTags,
  );
}
