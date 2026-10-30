part of 'sync_planner.dart';

/// 日记本层级（规格 §4.4）与成员关系（§4.3）。
///
/// 层级口径与 `NotebookHierarchy`（`app_database_notebook_hierarchy.dart`）
/// 一致——那个类基于 Drift 的 `NotebookRow`，纯 Dart 的规划器用不了，这里
/// 按同一规则重写（测试与它对拍）：
/// - 有效上级：`parentId` 指向的本子在最终集合里、`kind` 原始值为 manual、
///   不是自己；否则断开；
/// - 成环：环上的每一本都断开（挂在环下面的仍跟着各自的上级）；
/// - 层数：上面两步之后，层数超过 [kSyncNotebookMaxDepth] 且上级恰在最深一层
///   的本子断开（只断开真正放不下的那一层，下面的跟着它上移）。
/// 结果与遍历顺序无关；断开即把 `parentId` 精确地写成 null（写入层不调用会
/// 改动子本的 `deleteNotebook` / `mergeNotebook`，层级只以计划为准）。
///
/// 只在有日记本不是两侧原样时校验：全都原样时最终集合就是两侧现状。
extension _Notebooks on _Planner {
  void resolveNotebookHierarchy() {
    if (!_anyNotebookChanged) return;
    _restoreRevivedChildren();
    final definitions = <String, Map<String, Object?>>{};
    var complete = true;
    for (final key in keys) {
      if (key.entity != SyncEntity.notebook || !isPresent(key)) continue;
      final facets = finalFacets(key);
      if (facets == null) {
        complete = false;
        continue;
      }
      definitions[key.id] =
          _mapOf(facets[SyncFacet.definition]) ?? const <String, Object?>{};
    }
    if (!complete) return;
    final broken = _brokenParents(definitions).toList()..sort();
    for (final id in broken) {
      final key = SyncKey(SyncEntity.notebook, id);
      finals[key] = _Final.value(
        _withField(finalFacets(key)!, SyncFacet.definition, 'parentId', null),
      );
    }
  }

  /// 复活的日记本在保留一侧的子本：缺失一侧删除它时把子本提到了上一层，
  /// 这里按保留一侧把 `parentId` 改回来。
  void _restoreRevivedChildren() {
    final revivedNotebooks = _revivedIds(SyncEntity.notebook);
    for (final side in _sides) {
      final parents = revivedNotebooks[side]!;
      if (parents.isEmpty) continue;
      for (final key in keys) {
        if (key.entity != SyncEntity.notebook ||
            !presentOn(side, key) ||
            identicalOnBoth(key) ||
            !isPresent(key)) {
          continue;
        }
        final parent = _field(
          record(side, key)?.facets,
          SyncFacet.definition,
          'parentId',
        );
        if (parent is! String || !parents.contains(parent)) continue;
        final current = finalFacets(key);
        if (current == null ||
            _field(current, SyncFacet.definition, 'parentId') == parent) {
          continue;
        }
        finals[key] = _Final.value(
          _withField(current, SyncFacet.definition, 'parentId', parent),
        );
      }
    }
  }

  /// 成员关系：日记或日记本最终不存在、日记本不是手动本的丢弃；章节不在
  /// 日记本最终的章节里时写 null。两侧原样、所在日记本也两侧原样的成员关系
  /// 不必检查（两侧现状本来就合法，不读它们的值）。
  void resolveMemberships() {
    final memberships = <SyncKey>[
      ...keys.where((key) => key.entity == SyncEntity.membership),
      ...createdKeys.where((key) => key.entity == SyncEntity.membership),
    ];
    for (final key in memberships) {
      if (!isPresent(key)) continue;
      final ids = parseSyncMembershipId(key.id);
      if (ids == null) continue;
      final notebookKey = SyncKey(SyncEntity.notebook, ids.notebookId);
      final diaryKey = SyncKey(SyncEntity.diary, ids.diaryId);
      if (!createdKeys.contains(key) &&
          identicalOnBoth(key) &&
          identicalOnBoth(notebookKey)) {
        continue;
      }
      if (!isPresent(diaryKey) || !isPresent(notebookKey)) {
        finals[key] = _Final.absent;
        continue;
      }
      final notebook = finalFacets(notebookKey);
      if (notebook == null) continue;
      final definition = _mapOf(notebook[SyncFacet.definition]);
      if (definition?['kind'] != _kManualKind) {
        finals[key] = _Final.absent;
        continue;
      }
      final value = finalFacets(key);
      if (value == null) continue;
      final chapter = _field(value, SyncFacet.main, 'chapterId');
      if (chapter != null && !_chapterIds(definition!).contains(chapter)) {
        finals[key] = _Final.value(
          _withField(value, SyncFacet.main, 'chapterId', null),
        );
      }
    }
  }
}

/// 只有手动日记本有成员（按 `kind` 原始值判断，与 `acceptsManualEntries`
/// 同一口径）。
const String _kManualKind = 'manual';

/// 要断开上级的日记本 id（见文件顶部的口径）。
Set<String> _brokenParents(Map<String, Map<String, Object?>> definitions) {
  final ids = definitions.keys.toList()..sort();
  final raw = <String, String?>{
    for (final id in ids)
      id: definitions[id]!['parentId'] is String
          ? definitions[id]!['parentId'] as String
          : null,
  };
  final parents = <String, String?>{};
  for (final id in ids) {
    final parent = raw[id];
    final valid =
        parent != null &&
        parent != id &&
        definitions[parent]?['kind'] == _kManualKind;
    parents[id] = valid ? parent : null;
  }
  final settled = <String>{};
  for (final start in ids) {
    final path = <String>[];
    final onPath = <String>{};
    String? current = start;
    while (current != null && !settled.contains(current)) {
      if (!onPath.add(current)) {
        for (final member in path.sublist(path.indexOf(current))) {
          parents[member] = null;
        }
        break;
      }
      path.add(current);
      current = parents[current];
    }
    settled.addAll(path);
  }
  final depths = <String, int>{};
  int depthOf(String id) {
    final known = depths[id];
    if (known != null) return known;
    final parent = parents[id];
    return depths[id] = parent == null ? 1 : depthOf(parent) + 1;
  }

  final broken = <String>{
    for (final id in ids)
      if (raw[id] != null && parents[id] != raw[id]) id,
  };
  for (final id in ids) {
    final parent = parents[id];
    if (parent != null &&
        depthOf(id) > kSyncNotebookMaxDepth &&
        depthOf(parent) == kSyncNotebookMaxDepth) {
      broken.add(id);
    }
  }
  return broken;
}

/// 日记本定义里有效章节的 id，与 `NotebookPayload.chapterIds` 同一口径：
/// `payload.chapters` 里 id 与标题都是去掉首尾空白后非空的字符串，取去掉
/// 空白后的 id。
Set<String> _chapterIds(Map<String, Object?> definition) {
  final chapters = _mapOf(definition['payload'])?['chapters'];
  if (chapters is! List) return const <String>{};
  return <String>{
    for (final item in chapters)
      if (item is Map &&
          item['id'] is String &&
          item['title'] is String &&
          (item['id'] as String).trim().isNotEmpty &&
          (item['title'] as String).trim().isNotEmpty)
        (item['id'] as String).trim(),
  };
}
