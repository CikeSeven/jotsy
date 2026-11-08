import 'package:drift/drift.dart' show Value;

import '../../../database/app_database.dart';
import 'sync_canonical_support.dart';
import 'sync_model.dart';

/// 待办清单与待办 ↔ 规范记录（规格 §2.2 的 todoList / todo 行）。
///
/// - 两类都只有一个 `main` 分面、整条后写者胜（与纪念日相同）：待办的各列
///   （完成、截止、步骤、顺序）彼此相关，拆成分面分别取舍会拼出两台设备都
///   没有过的组合，比如一边勾了完成、一边把截止日推到下周；
/// - 手动顺序就是行上的 `sort_order`（REAL，拖动只改被拖的一行），随记录整条
///   同步，不另设 orderList；规范值一律为浮点数（[syncRealOf]）；
/// - JSON 列取库中原文解析后的值：`metadata`、`repeat` 为对象，`reminders`、
///   `steps` 为数组；解析不成的原文保留为字符串、写回时原样写回（见
///   [syncDecodeJsonObjectColumn] / [syncDecodeJsonArrayColumn]）。不经
///   `todo_rules.dart` 的模型重新编码：模型会丢掉新版本的字段与坏条目，同步
///   搬运的必须是原样的数据，两端的规范值才逐字节相同；
/// - 待办与清单不存放媒体，不做媒体路径归一（标题、备注是用户文字）；
/// - 时间为 UTC 毫秒（库里的秒 × 1000），可空的完成 / 稍后提醒时刻为 null。
///
/// 无副作用。

SyncRecord syncTodoListRecord(SyncRawTodoList row) =>
    SyncRecord(SyncKey(SyncEntity.todoList, row.listId), <String, Object?>{
      SyncFacet.main: <String, Object?>{
        'name': syncTruncate(row.name, SyncColumnLimits.todoListName),
        'colorKey': row.colorKey,
        'iconKey': row.iconKey,
        'sortOrder': syncRealOf(row.sortOrder),
        'metadata': syncDecodeJsonObjectColumn(row.metadata),
        'createdAt': syncMillisOfSeconds(row.createdAt),
        'updatedAt': syncMillisOfSeconds(row.updatedAt),
      },
    });

class SyncTodoListColumns {
  const SyncTodoListColumns({
    required this.listId,
    required this.name,
    required this.colorKey,
    required this.iconKey,
    required this.sortOrder,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncTodoListColumns.fromRecord(SyncRecord record) {
    if (record.key.entity != SyncEntity.todoList) {
      throw ArgumentError.value(record.key, 'record', '不是待办清单记录');
    }
    final value = syncMapOf(record.facets[SyncFacet.main], SyncFacet.main);
    return SyncTodoListColumns(
      listId: record.key.id,
      name: _nonEmpty(
        syncTruncate(
          syncStringOf(value['name'], 'name'),
          SyncColumnLimits.todoListName,
        ),
        'name',
      ),
      colorKey: syncStringOf(value['colorKey'], 'colorKey'),
      iconKey: syncStringOf(value['iconKey'], 'iconKey'),
      sortOrder: syncDoubleOf(value['sortOrder'], 'sortOrder'),
      metadata: syncEncodeJsonObjectColumn(value['metadata'], 'metadata'),
      createdAt: syncDateTimeOf(value['createdAt']),
      updatedAt: syncDateTimeOf(value['updatedAt']),
    );
  }

  final String listId;
  final String name;
  final String colorKey;
  final String iconKey;
  final double sortOrder;
  final String metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  TodoListsCompanion toCompanion() => TodoListsCompanion(
    listId: Value<String>(listId),
    name: Value<String>(name),
    colorKey: Value<String>(colorKey),
    iconKey: Value<String>(iconKey),
    sortOrder: Value<double>(sortOrder),
    metadata: Value<String>(metadata),
    createdAt: Value<DateTime>(createdAt),
    updatedAt: Value<DateTime>(updatedAt),
  );
}

SyncRecord syncTodoRecord(SyncRawTodo row) =>
    SyncRecord(SyncKey(SyncEntity.todo, row.todoId), <String, Object?>{
      SyncFacet.main: <String, Object?>{
        'listId': row.listId,
        'title': syncTruncate(row.title, SyncColumnLimits.todoTitle),
        'note': row.note,
        'priority': row.priority,
        'dueDate': row.dueDate,
        'dueMinute': row.dueMinute,
        'reminders': syncDecodeJsonArrayColumn(row.reminders),
        'repeat': row.repeat == null
            ? null
            : syncDecodeJsonObjectColumn(row.repeat!),
        'steps': syncDecodeJsonArrayColumn(row.steps),
        'completedAt': syncMillisOfSecondsOrNull(row.completedAt),
        'snoozedUntil': syncMillisOfSecondsOrNull(row.snoozedUntil),
        'linkedDiaryId': row.linkedDiaryId,
        'sortOrder': syncRealOf(row.sortOrder),
        'metadata': syncDecodeJsonObjectColumn(row.metadata),
        'createdAt': syncMillisOfSeconds(row.createdAt),
        'updatedAt': syncMillisOfSeconds(row.updatedAt),
      },
    });

class SyncTodoColumns {
  const SyncTodoColumns({
    required this.todoId,
    required this.listId,
    required this.title,
    required this.note,
    required this.priority,
    required this.dueDate,
    required this.dueMinute,
    required this.reminders,
    required this.repeat,
    required this.steps,
    required this.completedAt,
    required this.snoozedUntil,
    required this.linkedDiaryId,
    required this.sortOrder,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncTodoColumns.fromRecord(SyncRecord record) {
    if (record.key.entity != SyncEntity.todo) {
      throw ArgumentError.value(record.key, 'record', '不是待办记录');
    }
    final value = syncMapOf(record.facets[SyncFacet.main], SyncFacet.main);
    final repeat = value['repeat'];
    return SyncTodoColumns(
      todoId: record.key.id,
      listId: syncStringOrNullOf(value['listId'], 'listId'),
      title: _nonEmpty(
        syncTruncate(
          syncStringOf(value['title'], 'title'),
          SyncColumnLimits.todoTitle,
        ),
        'title',
      ),
      note: syncStringOf(value['note'], 'note'),
      priority: syncIntOf(value['priority'], 'priority'),
      dueDate: syncStringOrNullOf(value['dueDate'], 'dueDate'),
      dueMinute: syncIntOrNullOf(value['dueMinute'], 'dueMinute'),
      reminders: syncEncodeJsonArrayColumn(value['reminders'], 'reminders'),
      repeat: repeat == null
          ? null
          : syncEncodeJsonObjectColumn(repeat, 'repeat'),
      steps: syncEncodeJsonArrayColumn(value['steps'], 'steps'),
      completedAt: syncDateTimeOrNullOf(value['completedAt']),
      snoozedUntil: syncDateTimeOrNullOf(value['snoozedUntil']),
      linkedDiaryId: syncStringOrNullOf(
        value['linkedDiaryId'],
        'linkedDiaryId',
      ),
      sortOrder: syncDoubleOf(value['sortOrder'], 'sortOrder'),
      metadata: syncEncodeJsonObjectColumn(value['metadata'], 'metadata'),
      createdAt: syncDateTimeOf(value['createdAt']),
      updatedAt: syncDateTimeOf(value['updatedAt']),
    );
  }

  final String todoId;
  final String? listId;
  final String title;
  final String note;
  final int priority;
  final String? dueDate;
  final int? dueMinute;
  final String reminders;
  final String? repeat;
  final String steps;
  final DateTime? completedAt;
  final DateTime? snoozedUntil;
  final String? linkedDiaryId;
  final double sortOrder;
  final String metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  TodosCompanion toCompanion() => TodosCompanion(
    todoId: Value<String>(todoId),
    listId: Value<String?>(listId),
    title: Value<String>(title),
    note: Value<String>(note),
    priority: Value<int>(priority),
    dueDate: Value<String?>(dueDate),
    dueMinute: Value<int?>(dueMinute),
    reminders: Value<String>(reminders),
    repeat: Value<String?>(repeat),
    steps: Value<String>(steps),
    completedAt: Value<DateTime?>(completedAt),
    snoozedUntil: Value<DateTime?>(snoozedUntil),
    linkedDiaryId: Value<String?>(linkedDiaryId),
    sortOrder: Value<double>(sortOrder),
    metadata: Value<String>(metadata),
    createdAt: Value<DateTime>(createdAt),
    updatedAt: Value<DateTime>(updatedAt),
  );
}

/// 待办标题与清单名在库里至少 1 个字符（Drift `withLength(min: 1)`）：空值
/// 只会来自坏数据，写库时 Drift 的长度校验会在事务里抛错、让整批回滚。在
/// 还原列值时就拒绝，写入层记为 `invalidRecord` 跳过这一条（规格 §2.2）。
String _nonEmpty(String value, String field) {
  if (value.isEmpty) throw FormatException('同步记录字段 $field 为空', value);
  return value;
}
