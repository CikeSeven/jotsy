part of 'sync_planner.dart';

/// 标签：改名、被引用的不删、原地改名、设置里的标签顺序（规格 §4.2）。
///
/// 标签以名称为身份，改名在清单里表现为“旧名消失、新名出现”。各侧的
/// `renames` 记录了旧名 → 新名（折叠时已把链压成一跳）。一条改名生效的条件：
/// 记下它的一侧 X 已经没有旧名、有新名。生效的改名：
/// - 作用于全部最终日记的 tags 分面（旧名换成新名）——包括另一侧在改名之后
///   才打上旧名的日记，否则旧名会被这些日记“引用”而在 X 上重新出现；
/// - 另一侧 Y 还有旧名、没有新名，且最终只剩新名时，让 Y 原地改名（保持本地
///   id：编辑器与 `tagOrderRaw` 持有本地 id），代替“删旧名 + 建新名”。
/// Y 在 X 改名之后改过旧名的颜色时，旧名作为“删除后改过”的记录保留，Y 不
/// 原地改名、另建新名；日记上的旧名照样换成新名（改名是对标签称呼的修改，
/// 颜色的修改留在旧名那条记录上）。
extension _Tags on _Planner {
  /// 由两侧的改名记录算出生效的改名表 [renameMap]（只看清单与改名记录）。
  void computeRenames() {
    final raw = <String, ({String to, int at, _Side side})>{};
    for (final key in keys) {
      if (key.entity != SyncEntity.tag) continue;
      for (final side in _sides) {
        final rename = sideOf(side).renameOf(key.id);
        if (rename == null || rename.to == key.id) continue;
        if (presentOn(side, key)) continue;
        if (!presentOn(side, SyncKey(SyncEntity.tag, rename.to))) continue;
        final existing = raw[key.id];
        // 两侧把同一个旧名改成了不同的新名：取改名时间较新的，平手按 deviceId。
        if (existing == null ||
            rename.at > existing.at ||
            (rename.at == existing.at && side == tieWinner)) {
          raw[key.id] = (to: rename.to, at: rename.at, side: side);
        }
      }
    }
    // 沿链解析（X: a → b、Y: b → c 得 a → c）；成环的链整条不生效。
    final names = raw.keys.toList()..sort();
    for (final name in names) {
      final visited = <String>{name};
      String? target = raw[name]!.to;
      while (target != null && raw.containsKey(target)) {
        if (!visited.add(target)) {
          target = null;
          break;
        }
        target = raw[target]!.to;
      }
      if (target != null && target != name) renameMap[name] = target;
    }
  }

  void resolveTags() {
    final referenced = <String>{};
    final diaryKeys = <SyncKey>[
      ...keys.where((key) => key.entity == SyncEntity.diary),
      ...createdKeys.where((key) => key.entity == SyncEntity.diary),
    ];
    for (final key in diaryKeys) {
      final state = finals[key];
      if (state == null || state.kind != _Kind.value) continue;
      final facets = state.facets!;
      final names = _stringList(_field(facets, SyncFacet.tags, 'names'));
      final mapped = <String>{
        for (final name in names) renameMap[name] ?? name,
      }.toList()..sort();
      if (!_listEquals(mapped, names)) {
        finals[key] = _Final.value(
          _withField(facets, SyncFacet.tags, 'names', mapped),
        );
      }
      referenced.addAll(mapped);
    }
    // 两侧原样的日记引用的标签两侧都有，不会被删，不必读它们的值。
    for (final key in keys) {
      if (key.entity != SyncEntity.tag) continue;
      final side = deletedFrom[key];
      if (side == null || !referenced.contains(key.id)) continue;
      // 还被最终日记引用的标签不删（写入层按名称建标签，删了也会被重建，
      // 只是丢了颜色）。
      deletedFrom.remove(key);
      keepFrom(key, side);
    }
    final froms = renameMap.keys.toList()..sort();
    for (final from in froms) {
      final to = renameMap[from]!;
      final fromKey = SyncKey(SyncEntity.tag, from);
      final toKey = SyncKey(SyncEntity.tag, to);
      if (!isPresent(toKey) || isPresent(fromKey)) continue;
      for (final side in _sides) {
        final renames = inPlaceRenames[side]!;
        if (presentOn(side, fromKey) &&
            !presentOn(side, toKey) &&
            !renames.containsValue(to)) {
          renames[from] = to;
        }
      }
    }
  }

  /// settings 的 `tagOrderNames`：写入后各侧由本机标签表重新推出（本地 id →
  /// 名称，查不到的丢掉），所以最终值必须按改名换名、只留最终存在的标签、
  /// 去重，否则写入后的清单与计划不符，下次同步又判成差异。只在有标签只在
  /// 一侧（增删或改名）时才可能变化。
  void resolveSettingsTagOrder() {
    const key = SyncKey(SyncEntity.settings, kSyncSettingsId);
    if (!isPresent(key)) return;
    final tagsMoved = keys.any(
      (tag) =>
          tag.entity == SyncEntity.tag &&
          !(presentOn(_Side.local, tag) && presentOn(_Side.remote, tag)),
    );
    if (!tagsMoved) return;
    final facets = finalFacets(key);
    final order = _mapOf(facets?[kSyncPlannerTagOrderFacet]);
    if (facets == null || order == null || order['value'] is! List) return;
    final names = _stringList(order['value']);
    final seen = <String>{};
    final mapped = <String>[
      for (final name in names)
        if (isPresent(SyncKey(SyncEntity.tag, renameMap[name] ?? name)) &&
            seen.add(renameMap[name] ?? name))
          renameMap[name] ?? name,
    ];
    if (_listEquals(mapped, names)) return;
    finals[key] = _Final.value(
      _withField(facets, kSyncPlannerTagOrderFacet, 'value', mapped),
    );
  }
}
