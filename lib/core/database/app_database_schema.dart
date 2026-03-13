part of 'app_database.dart';

/// 日记主表。
///
/// 设计要点：
/// 1. `id` 是本地数据库自增主键，仅用于本地表关联；
/// 2. `diaryId` 是业务层真正的唯一标识，跨设备同步也保持唯一；
/// 3. `content` 存 Delta JSON（可扩展富文本）；
/// 4. `contentText` 存纯文本镜像（用于关键词检索）；
/// 5. `cover` 存封面地址（可空，支持本地路径或远程 URL）；
/// 6. `metadata` 存 JSON 对象字符串（用于扩展字段）；
/// 7. 归档与删除分离：归档用于隐藏到归档列表，删除用于回收站语义；
/// 8. 采用软删除字段，便于恢复与审计。
class Diaries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get diaryId => text().named('diary_id').unique()();

  TextColumn get title =>
      text().withLength(min: 0, max: 200).withDefault(const Constant(''))();

  TextColumn get content => text()();

  TextColumn get contentText => text().named('content_text')();

  TextColumn get cover => text().nullable()();

  TextColumn get metadata => text().withDefault(const Constant('{}'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();

  DateTimeColumn get archivedAt =>
      dateTime().named('archived_at').nullable()();

  /// 置顶标记：用于让重要日记固定出现在列表前部。
  BoolColumn get isPinned =>
      boolean().named('is_pinned').withDefault(const Constant(false))();

  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
}

/// 标签表：维护全量标签词典。
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 40).unique()();

  IntColumn get color => integer()();
}

/// 日记-标签关联表（多对多）。
///
/// 通过复合主键保证同一日记不会重复绑定同一标签，
/// 并对日记/标签删除开启级联清理。
class DiaryTags extends Table {
  IntColumn get diaryId =>
      integer()
          .named('diary_id')
          .references(Diaries, #id, onDelete: KeyAction.cascade)();

  IntColumn get tagId =>
      integer()
          .named('tag_id')
          .references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{diaryId, tagId};
}

/// 业务聚合模型：日记 + 其标签列表。
class DiaryWithTags {
  const DiaryWithTags({required this.diary, required this.tags});

  final Diary diary;
  final List<Tag> tags;
}

/// 日历月份打点聚合模型（轻量版）。
///
/// 用于日历网格渲染：仅保留“日期 + 心情”最小信息，
/// 避免把完整日记内容加载到月视图造成额外开销。
class DiaryCalendarMarker {
  const DiaryCalendarMarker({
    required this.diaryId,
    required this.createdAt,
    this.moodEmoji,
  });

  final String diaryId;
  final DateTime createdAt;
  final String? moodEmoji;
}
