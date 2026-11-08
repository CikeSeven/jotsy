import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import 'todo_actions.dart';

/// 列表里勾选完成的“先收起、再写库”队列（待办页持有）。
///
/// 时序：行内勾选动效播完 → [start] 把这一行记进 [leaving]（列表据此经
/// `ListItemPresence` 收起，`medium`）→ 收起结束后经 [toggleTodoDone] 写库并
/// 弹可撤销提示 → 页面拿到新数据时 [prune] 把已经写进去的去掉：这一行已
/// 不在未完成里，或（重复待办推到下一次）`updated_at` 变了。不在写完的那
/// 一刻去掉：drift 的推送晚一帧到，旧数据里这一行还在，会先展开回来再消失。
/// 减少动画时收起时长为 0，直接写库。
///
/// 页面卸载（切走 Tab 不会卸载，关掉功能或退出首页会）时 [dispose] 把还在
/// 计时的直接写库（不再弹提示），勾掉的待办不会因为离开而没完成。
class TodoCompletionQueue {
  TodoCompletionQueue({required this.onChanged});

  /// [leaving] 变化时通知页面重建。
  final VoidCallback onChanged;

  /// 收起中的行 → 开始时这一行的 `updated_at`。
  final Map<String, DateTime> _leaving = <String, DateTime>{};

  /// 已经写库、等新数据到达再去掉的行。
  final Set<String> _written = <String>{};
  final Map<String, ({Timer timer, AppDatabase database})> _pending =
      <String, ({Timer timer, AppDatabase database})>{};

  /// 正在收起（含已写库、新数据还没到）的行。
  Iterable<String> get leaving => _leaving.keys;

  bool isLeaving(String todoId) => _leaving.containsKey(todoId);

  void start(BuildContext context, AppDatabase database, TodoRow row) {
    final id = row.todoId;
    if (_leaving.containsKey(id)) return;
    final collapse = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    _leaving[id] = row.updatedAt;
    onChanged();
    _pending[id] = (
      timer: Timer(collapse, () async {
        _pending.remove(id);
        void written() {
          if (_written.add(id)) onChanged();
        }

        try {
          if (context.mounted) {
            await toggleTodoDone(context, database, row, onWritten: written);
          } else {
            await database.completeTodo(id);
          }
        } finally {
          written();
        }
      }),
      database: database,
    );
  }

  /// 按最新的未完成列表 [open] 去掉已经写进去的行（页面每次构建前调用，
  /// 不通知重建）。
  void prune(List<TodoRow> open) {
    if (_written.isEmpty) return;
    final byId = <String, TodoRow>{for (final row in open) row.todoId: row};
    _written.removeWhere((String id) {
      final current = byId[id];
      final settled = current == null || current.updatedAt != _leaving[id];
      if (settled) _leaving.remove(id);
      return settled;
    });
  }

  void dispose() {
    for (final entry in _pending.entries) {
      entry.value.timer.cancel();
      unawaited(entry.value.database.completeTodo(entry.key));
    }
    _pending.clear();
    _leaving.clear();
    _written.clear();
  }
}
