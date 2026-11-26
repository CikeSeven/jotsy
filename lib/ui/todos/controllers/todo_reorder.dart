import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/editing_session_registry.dart';

/// 收集箱与清单里的拖动排序（待办页持有）。
///
/// - 拿起到写完登记为局域网同步的阻塞者（[ReorderEditingGuard]）：期间同步
///   改了顺序，松手时按旧下标算出的邻居就不对了；
/// - 写库只改被拖的那一行（取两邻居的中点，见 `moveTodo`），邻居只取仍在库
///   里的行（正在退场的已删行不算）；
/// - 写库是异步的：松手那一帧若仍按库里的旧顺序排，被拖的那一行会先弹回
///   原处、等推送到了再跳到新位置。所以松手时先按新的顺序排（[order]，页面
///   构建时经 [apply] 排），库里的顺序跟上了（[settle] 看到推送来的顺序已一
///   致），或写完之后又来了一次推送（写失败、别处也改了顺序），就撤掉本地
///   顺序、以库为准；换视图时 [clear]。
class TodoReorder {
  TodoReorder({required this.onChanged});

  /// 本地顺序变了（页面重建）。
  final VoidCallback onChanged;

  final ReorderEditingGuard _drag = ReorderEditingGuard('todos-reorder');

  List<String>? _order;
  bool _written = false;

  /// 写完时看到的那份未完成列表；之后来了别的一份即以库为准。
  List<TodoRow>? _seenWhenWritten;

  /// 正在用的本地顺序（待办 id）；没有时为 null。实例在每次松手时换新，
  /// 页面可按它的实例判断要不要重新分组。
  List<String>? get order => _order;

  /// 拿起第 [index] 行。
  void start(int index) => _drag.start(index);

  /// 松手，[insertIndex] 为列表未修正的插入位置（落回原位时结束登记）。
  void dropped(int insertIndex) => _drag.dropped(insertIndex);

  /// 把 [rows]（这一组此刻显示的顺序）里第 [oldIndex] 条拖到 [newIndex]
  /// （已修正的插入位置）：先按新顺序排，再写库。[readOpen] 读此刻库里的
  /// 未完成待办。
  void drop(
    AppDatabase database,
    List<TodoRow> rows,
    int oldIndex,
    int newIndex, {
    required List<TodoRow>? Function() readOpen,
  }) {
    final live = <String>{
      for (final row in readOpen() ?? const <TodoRow>[]) row.todoId,
    };
    final next = List<TodoRow>.of(rows);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    String? neighbor(int from, int step) {
      for (var i = from; i >= 0 && i < next.length; i += step) {
        final id = next[i].todoId;
        if (live.contains(id)) return id;
      }
      return null;
    }

    final held = List<String>.unmodifiable(<String>[
      for (final row in next)
        if (live.contains(row.todoId)) row.todoId,
    ]);
    _order = held;
    _written = false;
    _seenWhenWritten = null;
    onChanged();
    unawaited(
      _drag
          .holdUntil(
            database.moveTodo(
              moved.todoId,
              aboveId: neighbor(newIndex - 1, -1),
              belowId: neighbor(newIndex + 1, 1),
            ),
          )
          .whenComplete(() {
            if (!identical(_order, held)) return;
            _written = true;
            _seenWhenWritten = readOpen();
          }),
    );
  }

  void clear() {
    _order = null;
    _written = false;
    _seenWhenWritten = null;
  }

  /// 按最新的未完成列表 [open] 决定还要不要本地顺序（页面每次构建前调用，
  /// 不通知重建）。
  void settle(List<TodoRow> open) {
    final order = _order;
    if (order == null) return;
    if (_written && !identical(open, _seenWhenWritten)) {
      clear();
      return;
    }
    final rank = _rankOf(order);
    var last = -1;
    for (final row in open) {
      final at = rank[row.todoId];
      if (at == null) continue;
      if (at < last) return;
      last = at;
    }
    // 库里的先后已与本地顺序一致。
    clear();
  }

  /// 把 [open] 里属于本地顺序的行按它重排，其余行留在原位；没有本地顺序
  /// 时原样返回。
  List<TodoRow> apply(List<TodoRow> open) {
    final order = _order;
    if (order == null) return open;
    final rank = _rankOf(order);
    final ranked = <TodoRow>[
      for (final row in open)
        if (rank.containsKey(row.todoId)) row,
    ]..sort((a, b) => rank[a.todoId]!.compareTo(rank[b.todoId]!));
    var next = 0;
    return <TodoRow>[
      for (final row in open)
        if (rank.containsKey(row.todoId)) ranked[next++] else row,
    ];
  }

  /// 页面卸载：结束还没交出的拖动登记。
  void dispose() => _drag.end();

  static Map<String, int> _rankOf(List<String> order) => <String, int>{
    for (var i = 0; i < order.length; i++) order[i]: i,
  };
}
