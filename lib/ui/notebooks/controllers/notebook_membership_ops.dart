import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../models/notebook_pick_selection.dart';
import '../viewmodels/notebook_book_layout.dart';

/// 一次收录变更的撤销信息：[added] 为每本新加入的日记（原本已在的不算，
/// 撤销时不会把它们移出），[removed] 为被删的关联行（含章节与成书位置，
/// 撤销时原样写回），[previousChapters] 为原本已在本子里且本次改过章节的
/// 日记的原章节（日记本 id → 日记 id → 原章节 id）。
@immutable
class NotebookMembershipUndo {
  const NotebookMembershipUndo({
    this.added = const <String, List<String>>{},
    this.removed = const <DiaryNotebookRow>[],
    this.previousChapters = const <String, Map<String, String?>>{},
  });

  final Map<String, List<String>> added;
  final List<DiaryNotebookRow> removed;
  final Map<String, Map<String, String?>> previousChapters;

  bool get isEmpty =>
      removed.isEmpty &&
      added.values.every((ids) => ids.isEmpty) &&
      previousChapters.values.every((chapters) => chapters.isEmpty);
}

/// 日记本收录的批量读写：首页多选、预览页“收进日记本”与“移出 / 移动到”
/// 共用，撤销信息在写入时一并取得。
///
/// 输入为日记与日记本的业务 id；只做数据库读写，不碰界面。每个操作在一个
/// 事务里完成：中途失败时整体回滚，调用方只需提示。
class NotebookMembershipOps {
  const NotebookMembershipOps(this.database);

  final AppDatabase database;

  /// 按选择器的结果改写 [diaryIds] 的收录：[NotebookPickerResult.add] 里的
  /// 每本把这批日记都收进（接在本子最后；[chapterIds] 指定了章节时落入该章，
  /// 否则落入未分章），[NotebookPickerResult.remove] 里的每本把它们都移出。
  /// [chapterIds] 也可为原本已在本子里的日记更新章节（值为 null 表示移回未分章）。
  Future<NotebookMembershipUndo> apply(
    NotebookPickerResult result,
    List<String> diaryIds, {
    Map<String, String?> chapterIds = const <String, String?>{},
  }) {
    final hasChapterChanges = chapterIds.keys.any(
      (id) => !result.remove.contains(id),
    );
    if ((result.isEmpty && !hasChapterChanges) || diaryIds.isEmpty) {
      return Future<NotebookMembershipUndo>.value(
        const NotebookMembershipUndo(),
      );
    }
    return database.transaction(() async {
      final before = await database.getNotebookIdsForDiaries(diaryIds);
      final added = <String, List<String>>{};
      for (final notebookId in result.add) {
        final fresh = <String>[
          for (final diaryId in diaryIds)
            if (!(before[diaryId]?.contains(notebookId) ?? false)) diaryId,
        ];
        if (fresh.isEmpty) continue;
        await database.addDiariesToNotebook(
          notebookId,
          fresh,
          chapterId: chapterIds[notebookId],
        );
        added[notebookId] = fresh;
      }
      final removed = <DiaryNotebookRow>[];
      for (final notebookId in result.remove) {
        removed.addAll(
          await database.removeDiariesFromNotebook(notebookId, diaryIds),
        );
      }
      final previousChapters = <String, Map<String, String?>>{};
      for (final entry in chapterIds.entries) {
        final notebookId = entry.key;
        if (result.remove.contains(notebookId)) continue;
        final freshlyAdded = added[notebookId]?.toSet() ?? const <String>{};
        final existingIds = <String>[
          for (final diaryId in diaryIds)
            if (!freshlyAdded.contains(diaryId) &&
                (before[diaryId]?.contains(notebookId) ?? false))
              diaryId,
        ];
        if (existingIds.isEmpty) continue;
        final row = await database.getNotebook(notebookId);
        final chapters =
            row?.parsedPayload.chapters ?? const <NotebookChapter>[];
        final targetChapter = validNotebookChapterId(chapters, entry.value);
        final current = await database.getNotebookEntryChapters(
          notebookId,
          existingIds,
        );
        final changed = <String, String?>{};
        for (final diaryId in existingIds) {
          if (!current.containsKey(diaryId)) continue;
          final effective = validNotebookChapterId(chapters, current[diaryId]);
          if (effective != targetChapter) {
            changed[diaryId] = effective;
          }
        }
        if (changed.isNotEmpty) {
          await database.setNotebookEntriesChapter(
            notebookId,
            changed.keys,
            targetChapter,
          );
          previousChapters[notebookId] = changed;
        }
      }
      return NotebookMembershipUndo(
        added: added,
        removed: removed,
        previousChapters: previousChapters,
      );
    });
  }

  /// 把 [diaryIds] 移出 [notebookId]。
  Future<NotebookMembershipUndo> remove(
    String notebookId,
    List<String> diaryIds,
  ) async {
    final removed = await database.removeDiariesFromNotebook(
      notebookId,
      diaryIds,
    );
    return NotebookMembershipUndo(removed: removed);
  }

  /// 把 [diaryIds] 从 [fromId] 移到 [toId]（接在目标本最后；[chapterId] 指定
  /// 目标章节，null 为未分章；已在目标本里的只从原本移出，若指定了 [chapterId]
  /// 一并移到该章）。与 `moveDiariesBetweenNotebooks` 的效果相同，另外记下
  /// 原本的关联行与目标本新加入的日记，供撤销。
  Future<NotebookMembershipUndo> move({
    required String fromId,
    required String toId,
    required List<String> diaryIds,
    String? chapterId,
  }) {
    if (fromId == toId) {
      throw ArgumentError.value(toId, 'toId', '不能移到同一个日记本');
    }
    return database.transaction(() async {
      final before = await database.getNotebookIdsForDiaries(diaryIds);
      final removed = await database.removeDiariesFromNotebook(
        fromId,
        diaryIds,
      );
      final fresh = <String>[
        for (final diaryId in diaryIds)
          if (!(before[diaryId]?.contains(toId) ?? false)) diaryId,
      ];
      await database.addDiariesToNotebook(toId, fresh, chapterId: chapterId);
      final previousChapters = <String, Map<String, String?>>{};
      if (chapterId != null) {
        final alreadyInTarget = <String>[
          for (final diaryId in diaryIds)
            if (before[diaryId]?.contains(toId) ?? false) diaryId,
        ];
        if (alreadyInTarget.isNotEmpty) {
          final row = await database.getNotebook(toId);
          final chapters =
              row?.parsedPayload.chapters ?? const <NotebookChapter>[];
          final targetChapter = validNotebookChapterId(chapters, chapterId);
          if (targetChapter != null) {
            final current = await database.getNotebookEntryChapters(
              toId,
              alreadyInTarget,
            );
            final changed = <String, String?>{};
            for (final diaryId in alreadyInTarget) {
              if (!current.containsKey(diaryId)) continue;
              final effective = validNotebookChapterId(
                chapters,
                current[diaryId],
              );
              if (effective != targetChapter) {
                changed[diaryId] = effective;
              }
            }
            if (changed.isNotEmpty) {
              await database.setNotebookEntriesChapter(
                toId,
                changed.keys,
                targetChapter,
              );
              previousChapters[toId] = changed;
            }
          }
        }
      }
      return NotebookMembershipUndo(
        added: <String, List<String>>{toId: fresh},
        removed: removed,
        previousChapters: previousChapters,
      );
    });
  }

  /// 撤销：移出新加入的，还原改过的章节，再原样写回被删的关联行。
  Future<void> undo(NotebookMembershipUndo undo) {
    if (undo.isEmpty) return Future<void>.value();
    return database.transaction(() async {
      for (final entry in undo.added.entries) {
        if (entry.value.isEmpty) continue;
        try {
          await database.removeDiariesFromNotebook(entry.key, entry.value);
        } on ArgumentError {
          // 日记本已被删除或转成智能本：它的关联行已经不在了。
        }
      }
      for (final entry in undo.previousChapters.entries) {
        if (entry.value.isEmpty) continue;
        await database.restoreNotebookEntryChapters(entry.key, entry.value);
      }
      await database.restoreNotebookMemberships(undo.removed);
    });
  }
}
