import 'package:drift/drift.dart' show Value;

import '../../../database/app_database.dart';
import 'sync_canonical_support.dart';
import 'sync_model.dart';

/// 专注记录 ↔ 规范记录（规格 §2.2 的 todoFocus 行）。
///
/// - 只有一个 `main` 分面。记录写完即不可变（见 `todo_focus.dart`），两侧的
///   同一条永远相同，实际只会“一侧有、一侧没有”，合并即取并集；
/// - `todoId` 原样搬运、规划器不置空：删除待办时本来就不清空它（撤销删除后
///   累计照旧），指向不存在的待办时按“没有关联”算；
/// - 时间为 UTC 毫秒（库里的秒 × 1000）；`metadata` 取库中原文解析后的对象，
///   解析不成的原文保留为字符串、写回时原样写回。
///
/// 无副作用。

SyncRecord syncTodoFocusRecord(SyncRawTodoFocus row) =>
    SyncRecord(SyncKey(SyncEntity.todoFocus, row.sessionId), <String, Object?>{
      SyncFacet.main: <String, Object?>{
        'todoId': row.todoId,
        'startedAt': syncMillisOfSeconds(row.startedAt),
        'endedAt': syncMillisOfSeconds(row.endedAt),
        'plannedSeconds': row.plannedSeconds,
        'focusedSeconds': row.focusedSeconds,
        'outcome': row.outcome,
        'metadata': syncDecodeJsonObjectColumn(row.metadata),
      },
    });

class SyncTodoFocusColumns {
  const SyncTodoFocusColumns({
    required this.sessionId,
    required this.todoId,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.focusedSeconds,
    required this.outcome,
    required this.metadata,
  });

  factory SyncTodoFocusColumns.fromRecord(SyncRecord record) {
    if (record.key.entity != SyncEntity.todoFocus) {
      throw ArgumentError.value(record.key, 'record', '不是专注记录');
    }
    final value = syncMapOf(record.facets[SyncFacet.main], SyncFacet.main);
    final planned = syncIntOf(value['plannedSeconds'], 'plannedSeconds');
    final focused = syncIntOf(value['focusedSeconds'], 'focusedSeconds');
    if (planned < 0 || focused < 0) {
      throw const FormatException('同步记录的专注时长为负');
    }
    return SyncTodoFocusColumns(
      sessionId: record.key.id,
      todoId: syncStringOrNullOf(value['todoId'], 'todoId'),
      startedAt: syncDateTimeOf(value['startedAt']),
      endedAt: syncDateTimeOf(value['endedAt']),
      plannedSeconds: planned,
      focusedSeconds: focused,
      outcome: syncStringOf(value['outcome'], 'outcome'),
      metadata: syncEncodeJsonObjectColumn(value['metadata'], 'metadata'),
    );
  }

  final String sessionId;
  final String? todoId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedSeconds;
  final int focusedSeconds;
  final String outcome;
  final String metadata;

  TodoFocusSessionsCompanion toCompanion() => TodoFocusSessionsCompanion(
    sessionId: Value<String>(sessionId),
    todoId: Value<String?>(todoId),
    startedAt: Value<DateTime>(startedAt),
    endedAt: Value<DateTime>(endedAt),
    plannedSeconds: Value<int>(plannedSeconds),
    focusedSeconds: Value<int>(focusedSeconds),
    outcome: Value<String>(outcome),
    metadata: Value<String>(metadata),
  );
}
