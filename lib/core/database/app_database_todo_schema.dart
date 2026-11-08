part of 'app_database.dart';

/// 待办（schema v19）：独立于日记的待办事项与清单。
///
/// 设计要点：
/// 1. 两张表都以业务 id（UUID v4）为唯一标识，备份合并与局域网同步按它判定
///    “同一条”；`id` 只用于本地；
/// 2. 待办所在的清单存清单的业务 id、不建外键（库里从不开外键）：`list_id`
///    为 NULL 即在“收集箱”，收集箱不是一行数据；删清单时由删除事务一并删掉
///    其中的待办；
/// 3. 截止日 `due_date` 存本地日期文本 `YYYY-MM-DD`（与纪念日、这天的心情
///    同一格式），截止时刻 `due_minute` 另存一天中的分钟数，NULL 为全天：
///    不存时间戳，换设备或时区后“周五 15:00 交”仍是周五 15:00；
/// 4. 步骤、提醒、重复规则与扩展字段是 JSON 文本列（模型与容错解码见
///    `todo_rules.dart`），新增字段不必再升 schema；
/// 5. `sort_order` 是 REAL：拖动排序只把被拖的那一行改为两邻居的中点，
///    不重写整张清单——排序就跟着这一行同步，两台设备各自拖动也不会互相
///    覆盖整串顺序；间隔小到浮点分不开时整清单重新编号；
/// 6. 重复待办完成一次时，原行推到下一次，另插一条“已完成的副本”记下这一
///    次（副本 id 由原 id 与这一次的日期决定，两台设备离线各自完成同一次，
///    同步后也只有一条；见 `_AppDatabaseTodoCompleteOps`）；
/// 7. `linked_diary_id` 存日记的业务 id、不建外键（与纪念日同理），彻底删除
///    日记时由删除事务清空。

/// 一个待办清单。
@DataClassName('TodoListRow')
class TodoLists extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get listId => text().named('list_id').unique()();

  TextColumn get name => text().withLength(min: 1, max: 50)();

  /// 强调色的色板键（见界面层的清单色板）；认不出时按默认色显示。
  TextColumn get colorKey =>
      text().named('color_key').withDefault(const Constant(''))();

  /// 图标键（见界面层的清单图标集合）；认不出时按默认图标显示。
  TextColumn get iconKey =>
      text().named('icon_key').withDefault(const Constant(''))();

  RealColumn get sortOrder =>
      real().named('sort_order').withDefault(const Constant(0))();

  /// 扩展字段（JSON 对象字符串）。
  TextColumn get metadata => text().withDefault(const Constant('{}'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}

/// 一条待办。
@DataClassName('TodoRow')
@TableIndex(
  name: 'idx_todos_completed_due',
  columns: <Symbol>{#completedAt, #dueDate},
)
@TableIndex(name: 'idx_todos_list', columns: <Symbol>{#listId})
class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get todoId => text().named('todo_id').unique()();

  /// 所在清单的业务 id；NULL 为收集箱。
  TextColumn get listId => text().named('list_id').nullable()();

  TextColumn get title => text().withLength(min: 1, max: 500)();

  /// 备注（纯文本）。
  TextColumn get note => text().withDefault(const Constant(''))();

  /// 优先级（[TodoPriority] 的下标）。
  IntColumn get priority => integer().withDefault(const Constant(0))();

  /// 截止日 `YYYY-MM-DD`；NULL 为没有日期。
  TextColumn get dueDate => text().named('due_date').nullable()();

  /// 截止时刻（一天中的分钟数）；NULL 为全天。没有截止日时总是 NULL。
  IntColumn get dueMinute => integer().named('due_minute').nullable()();

  /// 提醒 JSON 数组（[TodoReminder]）。
  TextColumn get reminders => text().withDefault(const Constant('[]'))();

  /// 重复规则 JSON（[TodoRepeatRule]）；NULL 为不重复。
  TextColumn get repeat => text().nullable()();

  /// 步骤 JSON 数组（[TodoStep]）。
  TextColumn get steps => text().withDefault(const Constant('[]'))();

  /// 完成时刻；NULL 为未完成。
  DateTimeColumn get completedAt =>
      dateTime().named('completed_at').nullable()();

  /// 稍后提醒到的时刻（通知上点“稍后提醒”）；过了即失效。
  DateTimeColumn get snoozedUntil =>
      dateTime().named('snoozed_until').nullable()();

  TextColumn get linkedDiaryId => text().named('linked_diary_id').nullable()();

  RealColumn get sortOrder =>
      real().named('sort_order').withDefault(const Constant(0))();

  /// 扩展字段（JSON 对象字符串）：来源日记、重复副本的原待办、已完成次数。
  TextColumn get metadata => text().withDefault(const Constant('{}'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}

/// `metadata` 里用到的键。
abstract final class TodoMetadataKeys {
  /// 从哪篇日记转来（日记业务 id）。
  static const String sourceDiaryId = 'sourceDiaryId';

  /// 重复待办的已完成副本：原待办的业务 id。
  static const String repeatOf = 'repeatOf';

  /// 重复待办：已经完成的次数（含已结束的那次），用于“一共重复 N 次”。
  static const String repeatDone = 'repeatDone';
}
