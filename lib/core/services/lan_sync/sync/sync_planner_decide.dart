part of 'sync_planner.dart';

/// 逐分面判定（规格 §4.1）：祖先关系、真冲突、没有共同祖先、变化时间。
///
/// 只读两侧的清单哈希、历史与（冲突时）记录，不改规划器状态，唯一的副作用
/// 是把“没有共同祖先的冲突”记进 [_Planner.ancestryLess]。

/// 一个分面的判定结果。
enum _Pick {
  /// 取本机的值。
  local,

  /// 取对方的值。
  remote,

  /// 真冲突，按分面各自的规则合并或选取。
  conflict,

  /// 日记的 stamp：取较大值，从不是冲突。
  max,
}

extension _Decide on _Planner {
  /// 判定 [key] 的 [facet]（两侧都有这条记录且该分面哈希不同）。返回 null
  /// 表示对方的历史还没取到（只在 [planSyncFetch] 中出现）。
  ///
  /// - 一侧缺这个分面（只会来自规范形式不同的版本，如更新版本多出的设置键）：
  ///   缺的一侧当作一个“没有内容”的不同值，有值的一侧胜出——取有值的一侧
  ///   从不丢数据，写入层也表达不了“去掉一个分面”；
  /// - R ∈ H_L 取本机，L ∈ H_R 取对方；两者同时成立（改回旧值：A → B → A）时
  ///   按当前值的确立时间（历史头条的 seenAt）较晚者，平手按 deviceId；
  /// - 否则真冲突；两侧历史没有任何共同哈希时记为“没有共同祖先”，“以哪边
  ///   为准”生效且选了一侧时直接取那一侧（顺序列表除外，见下）。
  _Pick? decideFacet(SyncKey key, String facet) {
    final lh = local.manifest[key]![facet];
    final rh = remote.manifest[key]![facet];
    if (lh == null) return _Pick.remote;
    if (rh == null) return _Pick.local;
    if (key.entity == SyncEntity.diary && facet == SyncFacet.stamp) {
      return _Pick.max;
    }
    final hl = history(_Side.local, key, facet)!;
    final hr = history(_Side.remote, key, facet);
    if (hr == null) return null;
    final rInL = hl.any((entry) => entry.hash == rh);
    final lInR = hr.any((entry) => entry.hash == lh);
    if (rInL && lInR) {
      // 两个值在彼此的历史里（来回改过）：谁的当前值确立得更晚谁胜。历史
      // 头条的 seenAt 即当前值在这一侧确立的时间——同步采纳的值继承来源
      // 一侧的确立时间（见 [SyncSidePlan.historySeenAt]），所以这里是按值的
      // 确立时间的“后写者胜”，与经过哪些设备、谁发起同步无关，必然收敛。
      final l = hl.first.seenAt;
      final r = hr.first.seenAt;
      if (l != r) return l > r ? _Pick.local : _Pick.remote;
      return tieWinner == _Side.local ? _Pick.local : _Pick.remote;
    }
    if (rInL) return _Pick.local;
    if (lInR) return _Pick.remote;
    final localHashes = <String>{for (final entry in hl) entry.hash};
    final common = hr.any((entry) => localHashes.contains(entry.hash));
    if (common) return _Pick.conflict;
    // 顺序列表与 prefs 两侧总是都有（新设备上是空书架、空标签顺序、默认的
    // 功能开关），与对方天然没有共同哈希，却谈不上“两边都改过”：不计入、
    // 也不受“以哪边为准”影响。列表（含标签顺序）按列表规则合并（没有祖先
    // 时取并集，选了哪一边最终都要恰好是两边记录的并集，见
    // [_Lists.resolveOrderLists]）；功能开关开着的一侧胜出（只同步“开启”）。
    if (key.entity == SyncEntity.orderList) return _Pick.conflict;
    if (key.entity == SyncEntity.prefs) {
      if (facet == SyncPrefsFacet.tagOrder) return _Pick.conflict;
      if (SyncPrefsFacet.isFeature(facet)) {
        return lh == SyncPrefsFacet.onHash ? _Pick.local : _Pick.remote;
      }
    }
    ancestryLess.add(key);
    if (!sideChoiceActive) return _Pick.conflict;
    return switch (options.sideChoice) {
      SyncSideChoice.keepBoth => _Pick.conflict,
      SyncSideChoice.preferLocal => _Pick.local,
      SyncSideChoice.preferRemote => _Pick.remote,
    };
  }

  /// 其余分面冲突：变化发现时间较新的一侧胜出，平手按 deviceId（§4.1 末条）。
  _Side newerChange(
    SyncKey key,
    String facet,
    Map<String, Object?> localFacets,
    Map<String, Object?> remoteFacets,
  ) {
    final l = _changeTime(
      history(_Side.local, key, facet)!,
      key.entity,
      facet,
      localFacets,
    );
    final r = _changeTime(
      history(_Side.remote, key, facet)!,
      key.entity,
      facet,
      remoteFacets,
    );
    if (l != r) return l > r ? _Side.local : _Side.remote;
    return tieWinner;
  }

  /// 两侧历史里最近的共同祖先的值（三方合并用）：同一哈希出现在两边历史里、
  /// 且带值；多个时取两边 `seenAt` 中较大者最新的，再平手按哈希字典序。
  /// 没有时返回 `(found: false)`。
  ({bool found, Object? value}) commonAncestor(SyncKey key, String facet) {
    final hl = history(_Side.local, key, facet)!;
    final hr = history(_Side.remote, key, facet)!;
    final remoteByHash = <String, SyncHistoryEntry>{};
    for (final entry in hr) {
      remoteByHash.putIfAbsent(entry.hash, () => entry);
    }
    SyncHistoryEntry? best;
    var bestTime = 0;
    for (final entry in hl) {
      final other = remoteByHash[entry.hash];
      if (other == null) continue;
      final source = entry.hasValue ? entry : (other.hasValue ? other : null);
      if (source == null) continue;
      final time = entry.seenAt > other.seenAt ? entry.seenAt : other.seenAt;
      if (best == null ||
          time > bestTime ||
          (time == bestTime && entry.hash.compareTo(best.hash) > 0)) {
        best = source;
        bestTime = time;
      }
    }
    return best == null
        ? (found: false, value: null)
        : (found: true, value: best.value);
  }
}

/// 当前值的确立时间：历史头条的 `seenAt`——用户改出这个值时是这一侧第一次
/// 观测到它的时间，经同步采纳的值继承来源一侧的确立时间（规格 §4.1.1）。
/// 没有历史说明这个值从记录出现起就没变过，退回记录自身的时间字段。
int _changeTime(
  List<SyncHistoryEntry> history,
  SyncEntity entity,
  String facet,
  Map<String, Object?> facets,
) {
  if (history.isNotEmpty) return history.first.seenAt;
  return _recordTime(entity, facet, facets);
}

/// 记录自身的时间字段（没有历史时的“变化时间”）；没有可用字段为 0。
int _recordTime(SyncEntity entity, String facet, Map<String, Object?> facets) {
  int? field(String name, String key) => _intOf(_field(facets, name, key));
  final stamp = field(SyncFacet.stamp, 'updatedAt');
  final time = switch (entity) {
    SyncEntity.diary => switch (facet) {
      SyncFacet.archive => field(SyncFacet.archive, 'archivedAt') ?? stamp,
      SyncFacet.trash => field(SyncFacet.trash, 'deletedAt') ?? stamp,
      SyncFacet.capsule => field(SyncFacet.capsule, 'lockedAt') ?? stamp,
      _ => stamp,
    },
    SyncEntity.notebook => field(SyncFacet.definition, 'updatedAt'),
    SyncEntity.membership => field(SyncFacet.main, 'addedAt'),
    SyncEntity.comment =>
      field(SyncFacet.main, 'editedAt') ?? field(SyncFacet.main, 'createdAt'),
    SyncEntity.template ||
    SyncEntity.anniversary ||
    SyncEntity.dayMood => field(SyncFacet.main, 'updatedAt'),
    SyncEntity.tag ||
    SyncEntity.orderList ||
    SyncEntity.settings ||
    SyncEntity.prefs => null,
  };
  return time ?? 0;
}
