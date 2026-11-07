import 'package:flutter/material.dart';

import '../../notebooks/sections/notebook_rule_sheets.dart';
import '../models/diary_search_filters.dart';
import '../sections/diary_search_tag_sheet.dart';
import 'diary_search_controller.dart';

/// 搜索页筛选胶囊的选择流程：打开 [slot] 对应的规则面板，改动实时写回
/// 搜索会话。
///
/// 时间、心情、媒体、天气、地点直接复用智能日记本的规则编辑面板
/// （[showNotebookRuleEditorSheet]）的实时模式：没有“完成”按钮，点选 / 输入
/// 即生效，草稿不完整（心情全部取消、文字清空）即清除这一项；关闭面板只是
/// 收起。没有初值时面板不预选，打开面板本身不改变筛选。标签面板同样点选
/// 即生效（[pickDiarySearchTags]）。
Future<void> pickDiarySearchFilter(
  BuildContext context,
  DiarySearchController session,
  DiarySearchFilterSlot slot,
) async {
  await showNotebookRuleEditorSheet(
    context,
    type: slot.ruleType,
    initial: session.filters.ruleOf(slot),
    onChanged: (rule) {
      // 面板开着时搜索页不会被弹走；仍防一手页面已释放的情况。
      if (!context.mounted) return;
      session.setFilter(slot, rule);
    },
  );
}

/// 打开标签面板；勾选变化实时写回（语义为“全部都含”）。
Future<void> pickDiarySearchTags(
  BuildContext context,
  DiarySearchController session,
) {
  return showDiarySearchTagSheet(
    context,
    selected: session.tagIds,
    onChanged: (tagIds) {
      if (!context.mounted) return;
      session.setTags(tagIds);
    },
  );
}
