part of 'sync_planner.dart';

/// 悬空引用与顺序列表（规格 §4.3、§2.2 orderList）。
///
/// 顺序列表的内容是“由别的记录推出的集合”：书架 = 全部日记本，我的模板 =
/// 全部用户模板，书序 = 这本手动日记本的成员。写入后各侧会按本机的行重新
/// 推出列表（重排位置时列表里没有的项排在末尾），所以最终列表必须恰好是
/// 最终集合：去掉最终不存在的 id，补上新出现的 id（新冲突副本排在原日记
/// 之后，其余按 id 排序追加到末尾），否则写入后的清单与计划不符。
///
/// 两侧原样、且最终集合与两侧现有集合（由清单的键算出，不必读值）都相同的
/// 列表不动；需要读值时两侧原样的读本机记录。
extension _Lists on _Planner {
  /// 留言所属日记最终不存在时丢弃；纪念日关联的日记最终不存在时置 null。
  /// 只看不是两侧原样的记录：两侧原样的留言 / 纪念日所引用的日记在两侧都在
  /// （删日记时会一并删留言、清关联），最终也一定还在。
  void resolveCommentsAndAnniversaries() {
    for (final key in keys) {
      final isComment = key.entity == SyncEntity.comment;
      if (!isComment && key.entity != SyncEntity.anniversary) continue;
      if (identicalOnBoth(key) || finals[key]?.kind != _Kind.value) continue;
      final facets = finals[key]!.facets!;
      if (isComment) {
        final diaryId = _field(facets, SyncFacet.main, 'diaryId');
        if (diaryId is! String ||
            !isPresent(SyncKey(SyncEntity.diary, diaryId))) {
          finals[key] = _Final.absent;
        }
        continue;
      }
      final linked = _field(facets, SyncFacet.main, 'linkedDiaryId');
      if (linked is String && !isPresent(SyncKey(SyncEntity.diary, linked))) {
        finals[key] = _Final.value(
          _withField(facets, SyncFacet.main, 'linkedDiaryId', null),
        );
      }
    }
  }

  void resolveOrderLists() {
    final revivedNotebooks = _revivedIds(SyncEntity.notebook);
    final finalMembers = _membersByNotebook(isPresent);
    final current = <_Side, _ListSets>{
      for (final side in _sides) side: _listSetsOf(side),
    };
    for (final key in keys) {
      if (key.entity != SyncEntity.orderList) continue;
      final notebookId = SyncOrderListId.notebookOf(key.id);
      final Set<String> members;
      _Side? revivedOn;
      if (key.id == SyncOrderListId.shelf) {
        members = _presentIds(SyncEntity.notebook, isPresent);
      } else if (key.id == SyncOrderListId.templates) {
        members = _presentIds(SyncEntity.template, isPresent);
      } else if (notebookId != null) {
        final notebookKey = SyncKey(SyncEntity.notebook, notebookId);
        if (!isPresent(notebookKey)) {
          finals[key] = _Final.absent;
          continue;
        }
        // 两侧原样的日记本类型不变：它出现在某侧的清单里就说明是手动本。
        if (!identicalOnBoth(notebookKey)) {
          final notebook = finalFacets(notebookKey);
          if (notebook == null) continue;
          if (_field(notebook, SyncFacet.definition, 'kind') != _kManualKind) {
            finals[key] = _Final.absent;
            continue;
          }
        }
        members = finalMembers[notebookId] ?? <String>{};
        for (final side in _sides) {
          if (revivedNotebooks[side]!.contains(notebookId)) revivedOn = side;
        }
      } else {
        continue; // 认不出的列表：按逐键判定的结果，不做集合校正。
      }
      _resolveList(key, members, revivedOn, current);
    }
  }

  void _resolveList(
    SyncKey key,
    Set<String> members,
    _Side? revivedOn,
    Map<_Side, _ListSets> current,
  ) {
    final state = finals[key]!;
    final unchanged =
        state.kind == _Kind.same &&
        revivedOn == null &&
        _sides.every((side) => _setEquals(current[side]!.idsOf(key), members));
    if (unchanged) return;
    final Map<String, Object?>? base;
    if (revivedOn != null && presentOn(revivedOn, key)) {
      // 复活的日记本：书序以保留它的一侧为准。
      base = currentFacets(revivedOn, key);
    } else if (state.kind == _Kind.value || state.kind == _Kind.same) {
      base = finalFacets(key);
    } else {
      // 判为删除、但日记本最终仍是手动本：以在场一侧的列表为底。
      base = currentFacets(
        presentOn(_Side.local, key) ? _Side.local : _Side.remote,
        key,
      );
    }
    if (base == null) return;
    final ids = _arrange(
      _stringList(_field(base, SyncFacet.items, 'ids')),
      members,
    );
    finals[key] = _Final.value(_withField(base, SyncFacet.items, 'ids', ids));
  }

  /// 只留 [members] 里的 id（去重、保持原顺序），再补上缺的：新冲突副本插在
  /// 原日记之后（同一原日记的多份副本按 id 排序），其余按 id 排序追加。
  List<String> _arrange(List<String> base, Set<String> members) {
    final seen = <String>{};
    final result = <String>[
      for (final id in base)
        if (members.contains(id) && seen.add(id)) id,
    ];
    final missing = members.difference(seen).toList()..sort();
    final copies = <String>[];
    for (final id in missing) {
      if (copyOriginals.containsKey(id)) {
        copies.add(id);
      } else {
        result.add(id);
      }
    }
    for (final id in copies) {
      final original = copyOriginals[id]!;
      final at = result.indexOf(original);
      if (at < 0) {
        result.add(id);
        continue;
      }
      var index = at + 1;
      while (index < result.length &&
          copyOriginals[result[index]] == original) {
        index++;
      }
      result.insert(index, id);
    }
    return result;
  }

  /// [side] 上各列表现有的 id 集合（由清单的键推出，不读值）。
  _ListSets _listSetsOf(_Side side) {
    bool here(SyncKey other) => presentOn(side, other);
    return _ListSets(
      _presentIds(SyncEntity.notebook, here),
      _presentIds(SyncEntity.template, here),
      _membersByNotebook(here),
    );
  }

  /// 满足 [test] 的 [entity] 键的 id（模板不含内置模板）。
  Set<String> _presentIds(SyncEntity entity, bool Function(SyncKey) test) =>
      <String>{
        for (final key in keys)
          if (key.entity == entity &&
              test(key) &&
              !(entity == SyncEntity.template &&
                  key.id.startsWith(kSyncBuiltInTemplatePrefix)))
            key.id,
      };

  /// 满足 [test] 的成员关系（含新生成的副本成员），按日记本分组的日记 id。
  Map<String, Set<String>> _membersByNotebook(bool Function(SyncKey) test) {
    final result = <String, Set<String>>{};
    for (final key in <SyncKey>[...keys, ...createdKeys]) {
      if (key.entity != SyncEntity.membership || !test(key)) continue;
      final ids = parseSyncMembershipId(key.id);
      if (ids == null) continue;
      (result[ids.notebookId] ??= <String>{}).add(ids.diaryId);
    }
    return result;
  }
}

/// 一侧各顺序列表应有的 id 集合。
class _ListSets {
  const _ListSets(this.notebooks, this.templates, this.members);

  final Set<String> notebooks;
  final Set<String> templates;
  final Map<String, Set<String>> members;

  Set<String> idsOf(SyncKey list) {
    if (list.id == SyncOrderListId.shelf) return notebooks;
    if (list.id == SyncOrderListId.templates) return templates;
    return members[SyncOrderListId.notebookOf(list.id)] ?? const <String>{};
  }
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
