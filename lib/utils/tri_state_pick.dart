import 'package:flutter/foundation.dart';

/// 批量选择器里一项对“这批条目”的状态：全都有 / 部分有 / 都没有。
///
/// 日记本收录选择器（`NotebookPickState` 即它）与多选日记的标签面板共用：
/// 两者都是“给一批日记整体加上或去掉若干项”，三态的含义与点按循环完全
/// 相同，只是项的 id 类型不同（日记本为业务 id，标签为本地 id）。
enum TriStatePick { all, some, none }

/// 三态选择器的结果：只含有变化的项——[add] 要给这批条目全部加上，
/// [remove] 要从这批条目全部去掉。没碰过的、仍是“部分有”的项都不出现。
@immutable
class TriStatePickResult<K> {
  const TriStatePickResult({this.add = const {}, this.remove = const {}});

  final Set<K> add;
  final Set<K> remove;

  bool get isEmpty => add.isEmpty && remove.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is TriStatePickResult<K> &&
      setEquals(other.add, add) &&
      setEquals(other.remove, remove);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(add),
    Object.hashAllUnordered(remove),
  );

  @override
  String toString() => 'TriStatePickResult(add: $add, remove: $remove)';
}

/// 由每个条目现有的项（[memberships]，每个条目一份集合）算出各项的三态：
/// 每个条目都有的为 all，只有部分条目有的为 some；一个条目都没有的项不出现
/// 在结果里（读取方按 none 处理）。[memberships] 为空时结果也为空。
Map<K, TriStatePick> triStatePicksFor<K>(Iterable<Set<K>> memberships) {
  var total = 0;
  final counts = <K, int>{};
  for (final items in memberships) {
    total++;
    for (final id in items) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return <K, TriStatePick>{
    for (final entry in counts.entries)
      entry.key: entry.value >= total ? TriStatePick.all : TriStatePick.some,
  };
}

/// 三态选择器的勾选状态（不含 UI，便于测试）。
///
/// 点按的循环：部分有 → 全部加上 → 全部去掉 → 全部加上 → …。“部分有”只会
/// 来自初始状态：没点过的项保持原样，结果里不出现，选择器不会把各条目之间
/// 本来不同的状态抹平。
class TriStatePickSelection<K> {
  TriStatePickSelection([Map<K, TriStatePick> initial = const {}])
    : _initial = Map<K, TriStatePick>.unmodifiable(initial),
      _current = <K, TriStatePick>{...initial};

  final Map<K, TriStatePick> _initial;
  final Map<K, TriStatePick> _current;

  TriStatePick stateOf(K id) => _current[id] ?? TriStatePick.none;

  /// 点按一项：全都有时改为都没有，否则（部分有、都没有）改为全都有。
  void toggle(K id) {
    _current[id] = stateOf(id) == TriStatePick.all
        ? TriStatePick.none
        : TriStatePick.all;
  }

  /// 直接设为全都有（刚新建的项出现时即为选中）。
  void select(K id) {
    _current[id] = TriStatePick.all;
  }

  /// 与初始状态相比的变化；没有变化时 [TriStatePickResult.isEmpty]。
  TriStatePickResult<K> get result {
    final add = <K>{};
    final remove = <K>{};
    for (final entry in _current.entries) {
      final before = _initial[entry.key] ?? TriStatePick.none;
      if (entry.value == before) continue;
      if (entry.value == TriStatePick.all) add.add(entry.key);
      if (entry.value == TriStatePick.none) remove.add(entry.key);
    }
    return TriStatePickResult<K>(add: add, remove: remove);
  }
}
