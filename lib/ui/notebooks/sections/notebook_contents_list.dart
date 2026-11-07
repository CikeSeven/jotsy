import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/viewmodels/diary_card_date_formatter.dart';
import '../../widgets/list_item_presence.dart';
import '../../widgets/reorder_handle.dart';
import '../viewmodels/notebook_book_layout.dart';
import 'notebook_contents_chapter_header.dart';
import 'notebook_contents_rows.dart';

/// 目录页的可拖动列表：章节标题行与日记行的扁平列表（见
/// `buildNotebookContents`），两种行都按住右侧手柄即拖。
///
/// 收起：[hidden] 里的日记行（收起了的章节、正在拖动的章节里的）仍留在
/// 列表里、只经 [ListItemPresence] 收到 0 高度并让出焦点，行的下标因此不随
/// 收起变化，拖动的落点换算照旧按整份书序。[appearing] 里的行在这一帧从
/// 0 高度展开（拖完章节后在新位置重新挂载的日记，不然会直接弹出来）。
///
/// 只负责组装；收起状态、拖动折叠与写库都在页面与
/// `NotebookContentsController`。
class NotebookContentsListSliver extends StatelessWidget {
  const NotebookContentsListSliver({
    super.key,
    required this.items,
    required this.chapters,
    required this.collapsed,
    required this.hidden,
    required this.appearing,
    required this.selecting,
    required this.selected,
    required this.dateMeta,
    required this.now,
    required this.onReorder,
    required this.onReorderStart,
    required this.onReorderEnd,
    required this.onToggleChapter,
    required this.onChapterAction,
    required this.onEntryTap,
  });

  final List<NotebookContentsItem> items;
  final List<NotebookChapter> chapters;

  /// 用户收起了的章节标题行 key（箭头的状态）。
  final Set<String> collapsed;

  /// 这一帧藏起来的日记行 key。
  final Set<String> hidden;

  /// 这一帧从 0 高度展开的日记行 key。
  final Set<String> appearing;
  final bool selecting;
  final Set<String> selected;
  final DiaryCardMetaStyle dateMeta;
  final DateTime now;

  /// onReorderItem 语义：[newIndex] 已按移除 [oldIndex] 后的列表修正。
  final void Function(int oldIndex, int newIndex) onReorder;

  /// 拿起第 index 行。
  final ValueChanged<int> onReorderStart;

  /// 松手，参数为未修正的插入位置（`SliverReorderableList.onReorderEnd`）。
  final ValueChanged<int> onReorderEnd;
  final ValueChanged<NotebookContentsHeader> onToggleChapter;
  final void Function(
    NotebookChapter chapter,
    int count,
    NotebookChapterAction action,
  )
  onChapterAction;

  /// 点按日记行（多选时为切换勾选），参数为日记 id。
  final ValueChanged<String> onEntryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final untitled = l10n.autoT0033;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    return SliverReorderableList(
      itemCount: items.length,
      onReorderItem: onReorder,
      // 拿起条目即生效的瞬间给一次触觉：手柄是立即拖动，不经过长按。
      onReorderStart: (int index) {
        onReorderStart(index);
        unawaited(HapticFeedback.mediumImpact());
      },
      onReorderEnd: onReorderEnd,
      proxyDecorator: _liftProxy,
      itemBuilder: (BuildContext context, int index) {
        final item = items[index];
        switch (item) {
          case NotebookContentsHeader(:final chapter, :final count):
            final chapterIndex = chapter == null
                ? -1
                : chapters.indexOf(chapter);
            return NotebookContentsChapterHeader(
              key: ValueKey<String>(item.key),
              chapter: chapter,
              count: count,
              isFirst: chapterIndex == 0,
              isLast: chapterIndex == chapters.length - 1,
              collapsed: collapsed.contains(item.key),
              onToggle: count == 0 ? null : () => onToggleChapter(item),
              onAction: chapter == null
                  ? null
                  : (action) => onChapterAction(chapter, count, action),
              // “未分章”总在最后，不能拖；多选时与日记行一样收起手柄。
              dragHandle: chapter == null || selecting
                  ? null
                  : ReorderHandle(index: index),
            );
          case NotebookContentsRow(:final entry):
            final rowHidden = hidden.contains(item.key);
            final sealed = TimeCapsuleState.fromFields(
              lockedAt: entry.capsuleLockedAt,
              unlockAt: entry.capsuleUnlockAt,
              now: now,
            ).isLocked;
            return ListItemPresence(
              key: ValueKey<String>(item.key),
              visible: !rowHidden,
              appearing: appearing.contains(item.key),
              duration: duration,
              child: ExcludeFocus(
                excluding: rowHidden,
                child: NotebookContentsEntryTile(
                  dateLabel: DiaryCardDateFormatter.eyebrow(
                    l10n: l10n,
                    meta: dateMeta,
                    createdAt: entry.createdAt,
                    updatedAt: entry.updatedAt,
                    now: now,
                  ),
                  title: entry.title.trim().isEmpty ? untitled : entry.title,
                  archived: entry.isArchived,
                  sealed: sealed,
                  selecting: selecting,
                  selected: selected.contains(entry.diaryId),
                  onTap: () => onEntryTap(entry.diaryId),
                  dragHandle: ReorderHandle(index: index),
                ),
              ),
            );
        }
      },
    );
  }

  /// 拖起时只轻微放大（与模板管理页一致），衬一层页面底色免得透出下方行。
  static Widget _liftProxy(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) => Transform.scale(
        scale: 1 + 0.02 * ExpressiveMotion.effects.transform(animation.value),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: ReorderHandleLift(animation: animation, child: child!),
        ),
      ),
    );
  }
}
