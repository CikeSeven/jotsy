import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../viewmodels/diary_draft_list_item.dart';
import 'diary_list_row_card.dart';

/// 一份草稿的列表行：标题、摘要、“编辑于 … · N 字”，有封面或图片时右侧显示
/// 缩略图。草稿箱页与新建时的草稿选择面板共用。
///
/// [compact] 用于选择面板：摘要只留一行，行距更紧。[selectionMode] 时左侧
/// 出现勾选框。外观与选中态补间见 [DiaryListRowCard]；只负责把草稿换算成
/// 行内容，不读写数据。
class DiaryDraftTile extends StatelessWidget {
  const DiaryDraftTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
    this.selectionMode = false,
    this.selected = false,
    this.now,
  });

  final DiaryDraftListItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;
  final bool selectionMode;
  final bool selected;

  /// 计算“今天 / 同年”的参照时间；测试注入固定时间，默认取当前时间。
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final words = NumberFormat.decimalPattern(
      l10n.localeName,
    ).format(item.wordCount);
    return DiaryListRowCard(
      title: item.displayTitle ?? l10n.autoT0033,
      titleMuted: item.displayTitle == null,
      snippet: item.snippet,
      footer: l10n.diaryDraftEditedAt(
        l10n.formatPreciseDateTime(item.updatedAt, now ?? DateTime.now()),
        words,
      ),
      thumbnail: item.thumbnail,
      onTap: onTap,
      onLongPress: onLongPress,
      compact: compact,
      selectionMode: selectionMode,
      selected: selected,
    );
  }
}
