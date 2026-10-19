import 'package:flutter/foundation.dart';

/// 一本日记本对“这批日记”的收录状态：全都在 / 部分在 / 都不在。
enum NotebookPickState { all, some, none }

/// 收录选择器的结果：只含有变化的日记本——[add] 要把这批日记全部收进，
/// [remove] 要把这批日记全部移出。没碰过的、仍是“部分在”的本子都不出现。
@immutable
class NotebookPickerResult {
  const NotebookPickerResult({
    this.add = const <String>{},
    this.remove = const <String>{},
  });

  final Set<String> add;
  final Set<String> remove;

  bool get isEmpty => add.isEmpty && remove.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is NotebookPickerResult &&
      setEquals(other.add, add) &&
      setEquals(other.remove, remove);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(add),
    Object.hashAllUnordered(remove),
  );

  @override
  String toString() => 'NotebookPickerResult(add: $add, remove: $remove)';
}

/// 由每篇日记所在的本子（`getNotebookIdsForDiaries` 的结果）算出各本子的
/// 三态：这批日记全在某本里为 all，只有部分在为 some；一篇都不在的本子不
/// 出现在结果里（读取方按 none 处理）。[membership] 为空时结果也为空。
Map<String, NotebookPickState> notebookPickStatesFor(
  Map<String, Set<String>> membership,
) {
  final total = membership.length;
  final counts = <String, int>{};
  for (final notebookIds in membership.values) {
    for (final id in notebookIds) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return <String, NotebookPickState>{
    for (final entry in counts.entries)
      entry.key: entry.value >= total
          ? NotebookPickState.all
          : NotebookPickState.some,
  };
}

/// 收录选择器的勾选状态（不含 UI，便于测试）。
///
/// 点按的循环：部分在 → 全部收进 → 全部移出 → 全部收进 → …。“部分在”只会
/// 来自初始状态：没点过的本子保持原样，结果里不出现，选择器不会把别处的
/// 收录关系抹平。
class NotebookPickSelection {
  NotebookPickSelection([Map<String, NotebookPickState> initial = const {}])
    : _initial = Map<String, NotebookPickState>.unmodifiable(initial),
      _current = <String, NotebookPickState>{...initial};

  final Map<String, NotebookPickState> _initial;
  final Map<String, NotebookPickState> _current;

  NotebookPickState stateOf(String notebookId) =>
      _current[notebookId] ?? NotebookPickState.none;

  /// 点按一本：全都在时改为都不在，否则（部分在、都不在）改为全都在。
  void toggle(String notebookId) {
    _current[notebookId] = stateOf(notebookId) == NotebookPickState.all
        ? NotebookPickState.none
        : NotebookPickState.all;
  }

  /// 直接设为全都在（刚新建的日记本出现时即为选中）。
  void select(String notebookId) {
    _current[notebookId] = NotebookPickState.all;
  }

  /// 与初始状态相比的变化；没有变化时 [NotebookPickerResult.isEmpty]。
  NotebookPickerResult get result {
    final add = <String>{};
    final remove = <String>{};
    for (final entry in _current.entries) {
      final before = _initial[entry.key] ?? NotebookPickState.none;
      if (entry.value == before) continue;
      if (entry.value == NotebookPickState.all) add.add(entry.key);
      if (entry.value == NotebookPickState.none) remove.add(entry.key);
    }
    return NotebookPickerResult(add: add, remove: remove);
  }
}
