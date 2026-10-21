import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/viewmodels/diary_card_view_data.dart';
import '../../diaries/widgets/diary_list_row_card.dart';

/// 回收站里的一篇日记：始终带勾选框，点按或长按切换勾选。
///
/// 内容：标题（没写时为“无标题”）、两行摘要与缩略图（封面优先，否则取正文
/// 第一张图），底行“{日记日期} · 删除于 {时间}”。两种情况隐去内容：
/// - 私密日记本里的日记：标题换成占位、带锁，不显示摘要、缩略图与日期，
///   只留删除时间；
/// - 未解封的时间胶囊：带锁，只显示标题与日期。
class RecycleBinTile extends StatelessWidget {
  const RecycleBinTile({
    super.key,
    required this.diary,
    required this.isPrivate,
    required this.selected,
    required this.onTap,
    this.now,
  });

  final Diary diary;
  final bool isPrivate;
  final bool selected;
  final VoidCallback onTap;

  /// 判断胶囊是否解封、计算“今天 / 同年”的参照时间；默认取当前时间。
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = this.now ?? DateTime.now();
    final sealed = TimeCapsuleState.fromFields(
      lockedAt: diary.capsuleLockedAt,
      unlockAt: diary.capsuleUnlockAt,
      now: now,
    ).isLocked;
    final title = diary.title.trim();
    final view = isPrivate || sealed ? null : DiaryCardViewData.of(diary);
    final deletedAt = diary.deletedAt;
    final deleted = deletedAt == null
        ? l10n.autoT0025
        : l10n.autoT0194(l10n.formatPreciseDateTime(deletedAt, now));
    return DiaryListRowCard(
      title: isPrivate
          ? l10n.notebookPrivateDiaryPlaceholder
          : title.isEmpty
          ? l10n.autoT0033
          : title,
      titleMuted: !isPrivate && title.isEmpty,
      titleIcon: isPrivate || sealed ? FontAwesomeIcons.lock : null,
      snippet: view?.previewText ?? '',
      thumbnail: view?.previewCover,
      footer: isPrivate
          ? deleted
          : l10n.recycleBinEntryFooter(
              l10n.formatFullDate(diary.createdAt),
              deleted,
            ),
      selectionMode: true,
      selected: selected,
      onTap: onTap,
      onLongPress: onTap,
    );
  }
}
