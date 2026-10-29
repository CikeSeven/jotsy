part of 'sync_planner.dart';

/// 三方合并（规格 §4.1）：diary.tags（集合）与 orderList.items（列表）。纯函数。
///
/// 两侧之分只用“主 / 次”（[primary] / [secondary]），不用“本机 / 对方”：主侧
/// 由变化时间决定（平手按 deviceId），与谁发起同步无关——同一对数据不论
/// 哪边发起都合并出同一个结果。

/// 集合三方合并：祖先 ∪ 双方新增 − 任一方删除，即
/// `(A ∩ L ∩ R) ∪ (L − A) ∪ (R − A)`；没有祖先时取并集。结果排序去重（与
/// tags 分面的规范形式一致）。
List<String> _mergeNameSets(
  List<String>? ancestor,
  List<String> left,
  List<String> right,
) {
  final l = left.toSet();
  final r = right.toSet();
  final Set<String> merged;
  if (ancestor == null) {
    merged = <String>{...l, ...r};
  } else {
    final a = ancestor.toSet();
    merged = <String>{
      ...a.where((name) => l.contains(name) && r.contains(name)),
      ...l.difference(a),
      ...r.difference(a),
    };
  }
  return merged.toList()..sort();
}

/// 列表三方合并。
///
/// - 没有祖先：主侧顺序 + 次侧独有项按次侧顺序追加；
/// - 有祖先：先去掉任一方删除的项。双方都保留的项的相对顺序——只有一方
///   改过（与祖先不同）就用那一方的，双方都改过用主侧的，都没改即祖先
///   顺序；再把主侧新增项、次侧新增项依次按各自的相对位置插入（插在它在
///   自己列表里最近的、已在结果中的前一项之后，没有前一项就放到最前）。
///
/// 规格原文“保留祖先顺序”在只有一方调整了顺序时会丢掉那次拖动；这里把它
/// 解释为“保留未被调整的顺序”，规格 §4.1 已同步说明。
List<String> _mergeIdLists(
  List<String>? ancestor,
  List<String> primary,
  List<String> secondary,
) {
  if (ancestor == null) {
    final seen = <String>{};
    return <String>[
      for (final id in primary)
        if (seen.add(id)) id,
      for (final id in secondary)
        if (seen.add(id)) id,
    ];
  }
  final a = ancestor.toSet();
  final p = primary.toSet();
  final s = secondary.toSet();
  bool kept(String id) => p.contains(id) && s.contains(id);
  List<String> commonOf(List<String> list) {
    final seen = <String>{};
    return <String>[
      for (final id in list)
        if (a.contains(id) && kept(id) && seen.add(id)) id,
    ];
  }

  final ancestorOrder = commonOf(ancestor);
  final primaryOrder = commonOf(primary);
  final secondaryOrder = commonOf(secondary);
  final primaryMoved = !_listEquals(primaryOrder, ancestorOrder);
  final secondaryMoved = !_listEquals(secondaryOrder, ancestorOrder);
  final result = primaryMoved
      ? primaryOrder
      : (secondaryMoved ? secondaryOrder : ancestorOrder);
  _insertAdditions(result, primary, a);
  _insertAdditions(result, secondary, a);
  return result;
}

/// 把 [source] 里不在 [ancestor] 中的项按 [source] 里的相对位置插进 [result]。
void _insertAdditions(
  List<String> result,
  List<String> source,
  Set<String> ancestor,
) {
  final present = result.toSet();
  for (var i = 0; i < source.length; i++) {
    final id = source[i];
    if (ancestor.contains(id) || present.contains(id)) continue;
    var at = 0;
    for (var j = i - 1; j >= 0; j--) {
      final index = result.indexOf(source[j]);
      if (index >= 0) {
        at = index + 1;
        break;
      }
    }
    result.insert(at, id);
    present.add(id);
  }
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
