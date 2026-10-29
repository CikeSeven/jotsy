part of 'sync_planner.dart';

/// 流水线第一段：逐键判定（规格 §4.1、§4.2）。
///
/// - 两侧哈希全同：same，不取任何数据；
/// - 两侧都有：逐分面判定（[_Decide.decideFacet]），只为“确实要用到值”的
///   一侧取记录——全部分面都取同一侧时只取那一侧；
/// - 只有一侧有：缺失一侧有墓碑且墓碑覆盖在场一侧的每个分面 → 删除（不取
///   记录）；否则保留并复制（取在场一侧的记录）。
///
/// 对方的历史、墓碑详情没取到时，这个键的判定悬而未决（unknown），也不为它
/// 取记录：等数据到了再定，避免猜着取。
extension _Keys on _Planner {
  void resolveKeys() {
    for (final key in keys) {
      final l = local.manifest[key];
      final r = remote.manifest[key];
      if (l != null && r != null) {
        finals[key] = _sameHashes(l, r) ? _Final.same : _resolveTwoSided(key);
      } else {
        _resolveOneSided(key, l != null ? _Side.local : _Side.remote);
      }
    }
  }

  _Final _resolveTwoSided(SyncKey key) {
    final l = local.manifest[key]!;
    final r = remote.manifest[key]!;
    final names = <String>{...l.keys, ...r.keys}.toList()..sort();
    final picks = <String, _Pick>{};
    var waiting = false;
    for (final facet in names) {
      if (l[facet] == r[facet]) continue;
      final pick = decideFacet(key, facet);
      if (pick == null) {
        waiting = true;
      } else {
        picks[facet] = pick;
      }
    }
    if (waiting) return _Final.unknown;

    final needLocal = picks.values.any((pick) => pick != _Pick.remote);
    final needRemote = picks.values.any((pick) => pick != _Pick.local);
    final localRecord = needLocal ? record(_Side.local, key) : null;
    final remoteRecord = needRemote ? record(_Side.remote, key) : null;
    if ((needLocal && localRecord == null) ||
        (needRemote && remoteRecord == null)) {
      return _Final.unknown;
    }
    final lf = localRecord?.facets;
    final rf = remoteRecord?.facets;
    final out = <String, Object?>{};
    for (final facet in names) {
      final pick = picks[facet];
      if (pick == null) {
        out[facet] = (lf ?? rf)![facet];
      } else if (pick == _Pick.local) {
        out[facet] = lf![facet];
      } else if (pick == _Pick.remote) {
        out[facet] = rf![facet];
      } else if (pick == _Pick.conflict) {
        out[facet] = _resolveConflict(key, facet, lf!, rf!);
      }
    }
    if (key.entity == SyncEntity.diary) _resolveStamp(key, out, lf, rf);
    _recordInherited(key, names, out, lf, rf);
    return _Final.value(out);
  }

  /// 最终值恰为某一侧原值的分面：另一侧是“采纳”，记下这个值在来源一侧的
  /// 确立时间（[SyncSidePlan.historySeenAt]）。两侧都有该分面、且不是 stamp
  /// 时才记——这时两侧的历史都已取到，来源一侧的记录也已取到。
  void _recordInherited(
    SyncKey key,
    List<String> names,
    Map<String, Object?> out,
    Map<String, Object?>? lf,
    Map<String, Object?>? rf,
  ) {
    final l = local.manifest[key]!;
    final r = remote.manifest[key]!;
    for (final facet in names) {
      final lh = l[facet];
      final rh = r[facet];
      if (lh == null || rh == null || lh == rh) continue;
      if (key.entity == SyncEntity.diary && facet == SyncFacet.stamp) continue;
      final hash = syncHashValue(out[facet]);
      final source = hash == lh
          ? _Side.local
          : (hash == rh ? _Side.remote : null);
      if (source == null) continue;
      final time = _changeTime(
        history(source, key, facet)!,
        key.entity,
        facet,
        (source == _Side.local ? lf : rf)!,
      );
      (inherited[source.other]![key] ??= <String, int>{})[facet] = time;
    }
  }

  /// 真冲突（两侧记录都已取到）。
  Object? _resolveConflict(
    SyncKey key,
    String facet,
    Map<String, Object?> lf,
    Map<String, Object?> rf,
  ) {
    if (key.entity == SyncEntity.diary && facet == SyncFacet.content) {
      // 正文：stamp 较新者留在原 id，败方另成冲突副本（_copies）。
      final winner = _stampWinner(lf, rf);
      contentLosers[key] = winner.other;
      return (winner == _Side.local ? lf : rf)[facet];
    }
    if (SyncFacet.tracksValue(key.entity, facet)) {
      return _mergeTracked(key, facet, lf, rf);
    }
    final winner = newerChange(key, facet, lf, rf);
    return (winner == _Side.local ? lf : rf)[facet];
  }

  /// tags / orderList 的三方合并；值形如 `{"names": […]}` / `{"ids": […]}`，
  /// 其余键（目前没有）沿用主侧的。
  Object? _mergeTracked(
    SyncKey key,
    String facet,
    Map<String, Object?> lf,
    Map<String, Object?> rf,
  ) {
    final field = key.entity == SyncEntity.diary ? 'names' : 'ids';
    final ancestor = commonAncestor(key, facet);
    final ancestorList = ancestor.found
        ? _stringList(_mapOf(ancestor.value)?[field])
        : null;
    final primary = newerChange(key, facet, lf, rf);
    final p = (primary == _Side.local ? lf : rf)[facet];
    final s = (primary == _Side.local ? rf : lf)[facet];
    final pList = _stringList(_mapOf(p)?[field]);
    final sList = _stringList(_mapOf(s)?[field]);
    final merged = key.entity == SyncEntity.diary
        ? _mergeNameSets(ancestorList, pList, sList)
        : _mergeIdLists(ancestorList, pList, sList);
    return <String, Object?>{...?_mapOf(p), field: merged};
  }

  /// 正文冲突的胜方：stamp 较新者，平手按 deviceId。
  _Side _stampWinner(Map<String, Object?> lf, Map<String, Object?> rf) {
    final ls = _stampOf(lf);
    final rs = _stampOf(rf);
    if (ls != rs) return ls > rs ? _Side.local : _Side.remote;
    return tieWinner;
  }

  /// stamp：取较大值；最终正文与某一侧当前正文不同、而最终 stamp 恰好等于
  /// 那一侧的当前值时再 +1 秒——各处按 `diaryId + updatedAt` 缓存的界面
  /// （卡片、预览、字数）只有看到 updatedAt 变了才会重新读正文。
  void _resolveStamp(
    SyncKey key,
    Map<String, Object?> out,
    Map<String, Object?>? lf,
    Map<String, Object?>? rf,
  ) {
    final l = local.manifest[key]!;
    final r = remote.manifest[key]!;
    final sameStamp = l[SyncFacet.stamp] == r[SyncFacet.stamp];
    final ls = _stampOf(lf ?? rf!);
    final rs = _stampOf(sameStamp ? (lf ?? rf!) : rf!);
    var stamp = ls > rs ? ls : rs;
    final source = (ls >= rs ? (lf ?? rf) : rf)!;
    final finalContent = syncHashValue(out[SyncFacet.content]);
    for (final side in _sides) {
      final current = hashesOn(side, key)!;
      final currentStamp = side == _Side.local ? ls : rs;
      if (current[SyncFacet.content] != finalContent && stamp == currentStamp) {
        stamp += kSyncStampBumpMillis;
      }
    }
    out[SyncFacet.stamp] = <String, Object?>{
      ...?_mapOf(source[SyncFacet.stamp]),
      'updatedAt': stamp,
    };
  }

  void _resolveOneSided(SyncKey key, _Side present) {
    final missing = present.other;
    if (sideOf(missing).hasTombstone(key)) {
      final grave = tombstone(missing, key);
      if (grave == null) {
        finals[key] = _Final.unknown;
        return;
      }
      final hashes = hashesOn(present, key)!;
      final covered = hashes.entries.every(
        (facet) => grave.knows(facet.key, facet.value),
      );
      if (covered) {
        finals[key] = _Final.absent;
        deletedFrom[key] = present;
        return;
      }
      revived[key] = present;
    }
    keepFrom(key, present);
  }

  /// 保留 [present] 一侧的 [key]（复制给另一侧）。
  void keepFrom(SyncKey key, _Side present) {
    final found = record(present, key);
    finals[key] = found == null ? _Final.unknown : _Final.value(found.facets);
  }
}

/// 日记 stamp 分面的 `updatedAt`（毫秒）；缺失按 0。
int _stampOf(Map<String, Object?> facets) =>
    _intOf(_field(facets, SyncFacet.stamp, 'updatedAt')) ?? 0;
