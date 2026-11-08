import 'package:flutter/widgets.dart';

import '../../../core/database/app_database.dart';

/// 记下待办页打开之后才出现的行（新建、同步来的、重复待办完成后的副本），
/// 让它们以 `ListItemPresence(appearing: true)` 展开进场。
///
/// 第一份数据到达时全部记为“已有”；之后每次 [track] 把新 id 放进
/// [appearing]，帧后清空——`ListItemPresence` 只在首次构建或由 false 变
/// true 时展开，清空后换视图、换分组重建同一行时不会再播一遍。
class TodoAppearanceTracker {
  Set<String>? _known;
  final Set<String> _appearing = <String>{};

  /// 本帧要展开进场的行。
  Set<String> get appearing => _appearing;

  /// 在构建时调用（不通知重建）；数据还没到齐时不记。
  void track(List<TodoRow>? open, List<TodoRow>? completed) {
    if (open == null || completed == null) return;
    final known = _known;
    if (known == null) {
      _known = <String>{
        for (final row in open) row.todoId,
        for (final row in completed) row.todoId,
      };
      return;
    }
    var added = false;
    for (final row in <TodoRow>[...open, ...completed]) {
      if (known.add(row.todoId)) {
        _appearing.add(row.todoId);
        added = true;
      }
    }
    if (added) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _appearing.clear());
    }
  }
}
