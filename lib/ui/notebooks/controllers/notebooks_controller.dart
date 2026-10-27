import '../../../core/database/app_database.dart';
import '../models/notebook_scope_resolver.dart';
import '../viewmodels/notebook_view.dart';

/// 日记本的书架操作：置顶、合上、排序、换上级、删除与撤销、合并、智能转普通。书架面板与管理页
/// 共用，不构建 UI——确认、提示与撤销条由 `notebook_action_flows.dart` 负责。
///
/// 输入输出一律是业务 id；数据库里找不到时由数据库层抛 [ArgumentError]。
class NotebooksController {
  NotebooksController(this.database);

  final AppDatabase database;

  Future<void> setPinned(String notebookId, bool pinned) =>
      database.updateNotebook(notebookId, isPinned: pinned);

  Future<void> setClosed(String notebookId, bool closed) =>
      database.updateNotebook(notebookId, isClosed: closed);

  /// 删除日记本；[trashDiaries] 时把本子里的日记一并移进回收站。返回撤销用
  /// 的快照，交给 [restore]。
  Future<NotebookDeletion> delete(
    String notebookId, {
    bool trashDiaries = false,
  }) => database.deleteNotebook(notebookId, trashDiaries: trashDiaries);

  Future<void> restore(NotebookDeletion deletion) =>
      database.restoreNotebookDeletion(deletion);

  /// 把普通日记本 [sourceId] 并入 [targetId] 并删除前者（不可撤销，调用前须
  /// 经用户确认）。
  Future<void> merge({required String sourceId, required String targetId}) =>
      database.mergeNotebook(sourceId: sourceId, targetId: targetId);

  /// 智能日记本 [notebook] 现在符合规则的日记（未删除、未归档、非私密），
  /// 按发表时间旧→新：转为普通日记本时按这个顺序收进去。
  Future<List<String>> smartMatches(NotebookView notebook) =>
      database.getActiveDiaryIds(
        scope: notebookStatsScope(notebook),
        sortMode: DiarySortMode.createdAsc,
      );

  /// 把智能日记本转为普通日记本并收进 [diaryIds]（见
  /// `AppDatabase.convertSmartNotebookToManual`）。不可撤销，调用前须确认。
  Future<int> convertToManual(String notebookId, List<String> diaryIds) =>
      database.convertSmartNotebookToManual(notebookId, diaryIds);

  Future<void> reorder(List<String> manualOrder) =>
      database.reorderNotebooks(manualOrder);

  /// 把 [notebookId] 放到 [parentId] 下（null 为放回书架顶层），排在新上级的
  /// 子本最后。不合法（成环、超过三层、上级不是手动本或已不存在）时数据库层
  /// 抛 [ArgumentError]，由调用方提示。
  Future<void> move(String notebookId, String? parentId) =>
      database.moveNotebook(notebookId, parentId);
}

/// 一个分组内拖动排序后的全局顺序。
///
/// [all] 为全部日记本（任意顺序），[sectionOrder] 为拖动后该分组内的新顺序。
/// 返回 `(manual, shelf)`：
/// - `manual` 交给 `reorderNotebooks` 的完整手动顺序：分组成员原本占着的
///   那些位置（按 `sortOrder`）依次换成新顺序，其他分组的相对顺序不变；
/// - `shelf` 是数据库写入后书架流应推送的顺序（置顶在前，再按手动顺序），
///   页面在流追上之前先按它显示，松手时列表不会跳回旧位置。
///
/// 置顶的始终排在前面：把没置顶的拖到置顶的上方，写入后仍会落回置顶之下，
/// `shelf` 已按这一规则给出，与数据库推送的结果一致。
({List<String> manual, List<String> shelf}) notebookOrderAfterReorder(
  List<NotebookView> all,
  List<String> sectionOrder,
) {
  final byManual = all.toList()
    ..sort((a, b) {
      final order = a.row.sortOrder.compareTo(b.row.sortOrder);
      return order != 0 ? order : a.row.id.compareTo(b.row.id);
    });
  // 拖动途中被删掉的本子不在 all 里，跳过，避免位置与成员数对不上。
  final known = <String>{for (final view in all) view.id};
  final ordered = sectionOrder.where(known.contains).toList();
  final members = ordered.toSet();
  final queue = ordered.iterator;
  final manual = <String>[
    for (final view in byManual)
      if (members.contains(view.id)) (queue..moveNext()).current else view.id,
  ];
  final pinned = <String>{
    for (final view in all)
      if (view.isPinned) view.id,
  };
  final shelf = <String>[
    ...manual.where(pinned.contains),
    ...manual.where((id) => !pinned.contains(id)),
  ];
  return (manual: manual, shelf: shelf);
}
