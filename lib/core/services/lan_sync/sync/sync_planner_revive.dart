part of 'sync_planner.dart';

/// 流水线第二段的复活部分（规格 §4.3）。
///
/// 复活 = 只有一侧有、缺失一侧有墓碑却仍保留的记录（在场一侧删除之后改过）。
/// 复活的日记 / 日记本把它们在保留一侧的从属一并带回：
/// - 日记 → 它在保留一侧的成员关系、留言、引用它的纪念日与待办关联（tags
///   分面随记录本身）；
/// - 日记本 → 它在保留一侧的成员关系、书序列表（`_lists`）、子本的
///   `parentId`（`_notebooks`）；
/// - 待办清单 → 它在保留一侧的待办（应用里删清单会连同其中的待办一起删）。
/// 这些从属在缺失一侧都随删除一并删掉了（有覆盖它们的墓碑），不改判就会被
/// 当成“删除传播”而丢掉。
///
/// 另外，给已被对方删除的日记新增或修改留言算作对日记的修改：保留下来的
/// 留言指向的日记若判为删除，改判为复活（[reviveByComments]）。成员关系、
/// 书序列表、待办的改动不复活日记 / 日记本 / 清单（规格只列了留言），成员
/// 关系与书序随日记 / 日记本不存在而丢弃，待办移到收集箱（`_lists`）。
extension _Revive on _Planner {
  /// 保留下来的留言（值已知、不是两侧原样）指向判为删除的日记时，复活该日记。
  void reviveByComments() {
    for (final key in keys) {
      if (key.entity != SyncEntity.comment) continue;
      if (finals[key]?.kind != _Kind.value) continue;
      final diaryId = _field(finals[key]!.facets, SyncFacet.main, 'diaryId');
      if (diaryId is! String) continue;
      final diaryKey = SyncKey(SyncEntity.diary, diaryId);
      final side = deletedFrom.remove(diaryKey);
      if (side == null) continue;
      revived[diaryKey] = side;
      keepFrom(diaryKey, side);
    }
  }

  /// 复活记录在保留一侧的从属：改判成员关系、留言、清单里的待办与纪念日 /
  /// 待办的日记关联。
  void reviveDependents() {
    final diaries = _revivedIds(SyncEntity.diary);
    final notebooks = _revivedIds(SyncEntity.notebook);
    final todoLists = _revivedIds(SyncEntity.todoList);
    for (final key in keys) {
      final side = deletedFrom[key];
      if (side == null || key.entity != SyncEntity.membership) continue;
      final ids = parseSyncMembershipId(key.id);
      if (ids == null) continue;
      if (diaries[side]!.contains(ids.diaryId) ||
          notebooks[side]!.contains(ids.notebookId)) {
        _undelete(key, side);
      }
    }
    for (final side in _sides) {
      final revivedLists = todoLists[side]!;
      if (revivedLists.isEmpty) continue;
      for (final key in keys) {
        if (key.entity != SyncEntity.todo || deletedFrom[key] != side) continue;
        // 被一并删除的待办：要读出所在清单才知道是不是复活清单里的。
        final value = record(side, key)?.facets;
        final listId = _field(value, SyncFacet.main, 'listId');
        if (revivedLists.contains(listId)) _undelete(key, side);
      }
    }
    for (final side in _sides) {
      final revivedDiaries = diaries[side]!;
      if (revivedDiaries.isEmpty) continue;
      for (final key in keys) {
        if (key.entity == SyncEntity.comment && deletedFrom[key] == side) {
          // 被一并删除的留言：要读出所属日记才知道是不是复活日记的。
          final value = record(side, key)?.facets;
          final diaryId = _field(value, SyncFacet.main, 'diaryId');
          if (revivedDiaries.contains(diaryId)) _undelete(key, side);
        } else if ((key.entity == SyncEntity.anniversary ||
                key.entity == SyncEntity.todo) &&
            presentOn(side, key) &&
            !identicalOnBoth(key)) {
          _relinkDiary(key, side, revivedDiaries);
        }
      }
    }
  }

  /// 保留一侧的纪念日 / 待办指向复活的日记、最终值却没有指向它（缺失一侧删
  /// 日记时清掉了关联）时，恢复关联。待办的清单复活放在日记之前：被一并删除
  /// 的待办改判保留之后，同样要恢复它的日记关联。
  void _relinkDiary(SyncKey key, _Side side, Set<String> revivedDiaries) {
    if (!isPresent(key)) return;
    final linked = _field(
      record(side, key)?.facets,
      SyncFacet.main,
      'linkedDiaryId',
    );
    if (linked is! String || !revivedDiaries.contains(linked)) return;
    final current = finalFacets(key);
    if (current == null) return;
    if (_field(current, SyncFacet.main, 'linkedDiaryId') == linked) return;
    finals[key] = _Final.value(
      _withField(current, SyncFacet.main, 'linkedDiaryId', linked),
    );
  }

  void _undelete(SyncKey key, _Side side) {
    deletedFrom.remove(key);
    revived[key] = side;
    keepFrom(key, side);
  }

  /// 每侧复活的 [entity] 的业务 id。
  Map<_Side, Set<String>> _revivedIds(SyncEntity entity) {
    final result = <_Side, Set<String>>{
      _Side.local: <String>{},
      _Side.remote: <String>{},
    };
    for (final entry in revived.entries) {
      if (entry.key.entity == entity) result[entry.value]!.add(entry.key.id);
    }
    return result;
  }

  /// 日记本层级与成员校验要用到的定义：有任何日记本不是两侧原样时，层级要
  /// 在最终的全体日记本上校验——两侧原样的读本机记录（不走网络）；有日记本
  /// 在某一侧复活时，还要读那一侧所有改过的日记本，找出原本挂在它下面的子本。
  void loadNotebooks() {
    if (!_anyNotebookChanged) return;
    final revivedNotebooks = _revivedIds(SyncEntity.notebook);
    for (final key in keys) {
      if (key.entity != SyncEntity.notebook) continue;
      if (identicalOnBoth(key)) {
        record(_Side.local, key);
        continue;
      }
      for (final side in _sides) {
        if (revivedNotebooks[side]!.isNotEmpty && presentOn(side, key)) {
          record(side, key);
        }
      }
    }
  }

  bool get _anyNotebookChanged => keys.any(
    (key) => key.entity == SyncEntity.notebook && !identicalOnBoth(key),
  );
}
