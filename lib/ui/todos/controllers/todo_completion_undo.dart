import 'package:flutter/widgets.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../widgets/todo_labels.dart';
import 'todo_actions.dart';

/// 列表里接连勾选完成的撤销提示合并成一条（待办页持有，勾选、右滑与右键
/// 菜单的“完成”共用）。
///
/// 上一条完成的提示还在时又完成一条：新提示顶替旧的，写“已完成 N 条”，
/// 撤销把这一批按完成的倒序全部恢复。提示被顶替时旧的那次等待直接作废
/// （[_generation] 已变），不算撤销也不收尾；提示自己消失（超时、被别的
/// 提示顶掉）时这一批就此作数、清空，下一次完成重新从 1 条数起。
///
/// 只有一条时与单条提示一致：重复待办写明下一次的日子（经 `todayOf`）。
class TodoCompletionUndo {
  TodoCompletionUndo({required this.todayOf});

  /// 此刻的“今天”（下一次的相对日期）。
  final DateTime Function() todayOf;

  final List<TodoCompletion> _batch = <TodoCompletion>[];
  int _generation = 0;

  /// 记下一次完成并弹出（或顶替成）合并后的提示，用户撤销时整批恢复。
  Future<void> add(
    BuildContext context,
    AppDatabase database,
    TodoCompletion completion,
  ) async {
    _batch.add(completion);
    final generation = ++_generation;
    final l10n = context.l10n;
    final String message;
    if (_batch.length > 1) {
      message = l10n.todoBatchCompleted(_batch.length);
    } else {
      final next = completion.nextDue;
      message = next == null
          ? l10n.todoCompletedNotice
          : l10n.todoCompletedNextNotice(
              TodoLabels.relativeDay(l10n, next, todayOf()),
            );
    }
    final undone = await showTodoUndoHint(context, message);
    // 被后来的完成顶替：那一条提示接着管这一批。
    if (generation != _generation) return;
    final batch = List<TodoCompletion>.of(_batch);
    _batch.clear();
    if (!undone) return;
    for (final item in batch.reversed) {
      await database.undoTodoCompletion(item);
    }
  }
}
