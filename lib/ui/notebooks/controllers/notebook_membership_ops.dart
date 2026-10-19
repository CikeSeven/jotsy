import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../models/notebook_pick_selection.dart';

/// 一次收录变更的撤销信息：[added] 为每本新加入的日记（原本已在的不算，
/// 撤销时不会把它们移出），[removed] 为被删的关联行（含章节与成书位置，
/// 撤销时原样写回）。
@immutable
class NotebookMembershipUndo {
  const NotebookMembershipUndo({
    this.added = const <String, List<String>>{},
    this.removed = const <DiaryNotebookRow>[],
  });

  final Map<String, List<String>> added;
  final List<DiaryNotebookRow> removed;

  bool get isEmpty =>
      removed.isEmpty && added.values.every((ids) => ids.isEmpty);
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
  /// 每本把这批日记都收进（接在本子最后、未分章），[NotebookPickerResult.remove]
  /// 里的每本把它们都移出。
  Future<NotebookMembershipUndo> apply(
    NotebookPickerResult result,
    List<String> diaryIds,
  ) {
    if (result.isEmpty || diaryIds.isEmpty) {
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
        await database.addDiariesToNotebook(notebookId, fresh);
        added[notebookId] = fresh;
      }
      final removed = <DiaryNotebookRow>[];
      for (final notebookId in result.remove) {
        removed.addAll(
          await database.removeDiariesFromNotebook(notebookId, diaryIds),
        );
      }
      return NotebookMembershipUndo(added: added, removed: removed);
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

  /// 把 [diaryIds] 从 [fromId] 移到 [toId]（接在目标本最后、未分章；已在目标
  /// 本里的只从原本移出）。与 `moveDiariesBetweenNotebooks` 的效果相同，另外
  /// 记下原本的关联行与目标本新加入的日记，供撤销。
  Future<NotebookMembershipUndo> move({
    required String fromId,
    required String toId,
    required List<String> diaryIds,
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
      await database.addDiariesToNotebook(toId, fresh);
      return NotebookMembershipUndo(
        added: <String, List<String>>{toId: fresh},
        removed: removed,
      );
    });
  }

  /// 撤销：移出新加入的，再原样写回被删的关联行。
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
      await database.restoreNotebookMemberships(undo.removed);
    });
  }
}
