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
/// - 清单有分区时拖过了分区：顺序与分区在同一个事务里写
///   （`moveTodoToSection`），松手时同样先按新的分区排（[sections]），库里
///   的分区也跟上了才撤掉。
class TodoReorder {
  TodoReorder({required this.onChanged});

  /// 本地顺序变了（页面重建）。
  final VoidCallback onChanged;

  final ReorderEditingGuard _drag = ReorderEditingGuard('todos-reorder');

  List<String>? _order;
  Map<String, String?> _sections = const <String, String?>{};
  bool _written = false;

  /// 写完时看到的那份未完成列表；之后来了别的一份即以库为准。
  List<TodoRow>? _seenWhenWritten;

  /// 正在用的本地顺序（待办 id）；没有时为 null。实例在每次松手时换新，
  /// 页面可按它的实例判断要不要重新分组。
  List<String>? get order => _order;

  /// 拖过分区、库里还没跟上的行：待办 id → 新的分区（null 为未分区）。实例
  /// 只在松手时换新。
  Map<String, String?> get sections => _sections;

  /// 拿起第 [index] 行。
  void start(int index) => _drag.start(index);

  /// 松手，[insertIndex] 为列表未修正的插入位置（落回原位时结束登记）。
  void dropped(int insertIndex) => _drag.dropped(insertIndex);

  /// 把 [rows]（这一组此刻显示的顺序）里第 [oldIndex] 条拖到 [newIndex]
  /// （已修正的插入位置）：先按新顺序排，再写库。[readOpen] 读此刻库里的
  /// 未完成待办。[section] 给出时（清单有分区）同时放进这个分区（值为
  /// null 即未分区）。
  void drop(
    AppDatabase database,
    List<TodoRow> rows,
    int oldIndex,
    int newIndex, {
    required List<TodoRow>? Function() readOpen,
    ({String? id})? section,
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
    _sections = section == null
        ? const <String, String?>{}
        : <String, String?>{moved.todoId: section.id};
    _written = false;
    _seenWhenWritten = null;
    onChanged();
    final aboveId = neighbor(newIndex - 1, -1);
    final belowId = neighbor(newIndex + 1, 1);
    unawaited(
      _drag
          .holdUntil(
            section == null
                ? database.moveTodo(
                    moved.todoId,
                    aboveId: aboveId,
                    belowId: belowId,
                  )
                : database.moveTodoToSection(
                    moved.todoId,
                    section.id,
                    aboveId: aboveId,
                    belowId: belowId,
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
    _sections = const <String, String?>{};
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
      // 拖过分区的：库里的分区也要跟上（只换了分区、先后没变时，只看顺序
      // 会过早撤掉，这一行先回到原分区再跳过去）。
      if (_sections.containsKey(row.todoId) &&
          TodoSections.idOfTodo(row.metadata) != _sections[row.todoId]) {
        return;
      }
    }
    // 库里的先后与分区已与本地一致。
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
