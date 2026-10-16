import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../widgets/settings_card_group.dart';

// 卡片样式设置页专用的分组外壳；各样式编辑页通用的外壳、撤销提示与命名
// 对话框见 widgets/style_editor/style_editor_common.dart。

/// 只作用于当前预览布局的“专属”分组；附注提示可在预览上方切换布局。
SettingsCardGroup diaryCardModeGroup(
  BuildContext context, {
  required DiaryCardMode mode,
  required List<Widget> children,
  String? footer,
}) {
  final l10n = context.l10n;
  return SettingsCardGroup(
    title: mode == DiaryCardMode.list
        ? l10n.diaryCardStyleListGroup
        : l10n.diaryCardStyleWaterfallGroup,
    footer: footer ?? l10n.diaryCardStyleModeFootnote,
    children: children,
  );
}
