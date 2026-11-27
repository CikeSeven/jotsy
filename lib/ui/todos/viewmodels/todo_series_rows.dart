import '../../../core/database/app_database.dart';

/// 列表里的一行，以及收进这一行的已完成次数（只有重复待办的原待办才可能
/// 不为 0）。
typedef TodoSeriesEntry = ({TodoRow row, int doneCount});

/// 重复待办的一串：原待办推到下一次，每完成一次另存一条已完成副本（见
/// `completeTodo`）。副本是独立的行，按行列出时一串会摊成好几条（#382）。
abstract final class TodoSeriesRows {
  /// 已完成副本所属那一串的原待办业务 id；不是已完成副本时为 null（取消
  /// 完成后的副本已是一条普通待办，也为 null）。
  static String? seriesOf(TodoRow row) {
    if (row.completedAt == null) return null;
    final id = decodeTodoMetadata(row.metadata)[TodoMetadataKeys.repeatOf];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// 把 [rows] 里的已完成副本收进同在 [rows] 里的原待办：副本不再单列，原待办
  /// 记下收进了几次。原待办不在 [rows] 里（被删了，或关联到了别处）的副本
  /// 照常单列。其余顺序不变。
  static List<TodoSeriesEntry> collapse(List<TodoRow> rows) {
    final present = <String>{for (final row in rows) row.todoId};
    final counts = <String, int>{};
    final kept = <TodoRow>[];
    for (final row in rows) {
      final series = seriesOf(row);
      if (series != null && present.contains(series)) {
        counts[series] = (counts[series] ?? 0) + 1;
      } else {
        kept.add(row);
      }
    }
    return <TodoSeriesEntry>[
      for (final row in kept) (row: row, doneCount: counts[row.todoId] ?? 0),
    ];
  }
}
