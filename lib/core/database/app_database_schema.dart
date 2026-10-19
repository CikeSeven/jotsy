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
/// 8. `capsuleUnlockAt/capsuleLockedAt` 标记时间胶囊，未到期前只展示锁定壳；
/// 9. 采用软删除字段，便于恢复与审计。
///
/// 索引设计：
/// - `updated_at`：列表默认按更新时间倒序排序；
/// - `created_at`：日历按日范围扫描、“那年今日”按创建时间过滤；
/// - `capsule_unlock_at`：时间胶囊到期过滤。
/// - 活跃列表的复合索引：覆盖置顶 + 时间 + id 的常用倒序分页；只索引
///   未归档、未删除记录，避免为回收站与归档增加不必要的写入和存储成本。
@TableIndex(name: 'idx_diaries_updated_at', columns: <Symbol>{#updatedAt})
@TableIndex(name: 'idx_diaries_created_at', columns: <Symbol>{#createdAt})
@TableIndex(
  name: 'idx_diaries_capsule_unlock_at',
  columns: <Symbol>{#capsuleUnlockAt},
)
@TableIndex.sql(
  'CREATE INDEX idx_diaries_active_updated '
  'ON diaries (is_pinned DESC, updated_at DESC, id DESC) '
  'WHERE is_deleted = 0 AND is_archived = 0',
)
@TableIndex.sql(
  'CREATE INDEX idx_diaries_active_created '
  'ON diaries (is_pinned DESC, created_at DESC, id DESC) '
  'WHERE is_deleted = 0 AND is_archived = 0',
)
class Diaries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get diaryId => text().named('diary_id').unique()();

  TextColumn get title =>
      text().withLength(min: 0, max: 200).withDefault(const Constant(''))();

  TextColumn get content => text()();

  TextColumn get contentText => text().named('content_text')();

  TextColumn get cover => text().nullable()();

  TextColumn get metadata => text().withDefault(const Constant('{}'))();

  // created_at 建索引：日历按日范围扫描、“那年今日”等查询都以创建时间为条件。
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  // updated_at 建索引：日记列表默认按更新时间倒序排序，建索引避免排序时全表扫描。
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();

  DateTimeColumn get archivedAt => dateTime().named('archived_at').nullable()();

  /// 置顶标记：用于让重要日记固定出现在列表前部。
  BoolColumn get isPinned =>
      boolean().named('is_pinned').withDefault(const Constant(false))();

  DateTimeColumn get capsuleUnlockAt =>
      dateTime().named('capsule_unlock_at').nullable()();

  DateTimeColumn get capsuleLockedAt =>
      dateTime().named('capsule_locked_at').nullable()();

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
///
/// `tag_id` 单列索引：支持“按标签反查日记”（复合主键前缀只覆盖 diary_id）。
@TableIndex(name: 'idx_diary_tags_tag_id', columns: <Symbol>{#tagId})
class DiaryTags extends Table {
  IntColumn get diaryId => integer()
      .named('diary_id')
      .references(Diaries, #id, onDelete: KeyAction.cascade)();

  IntColumn get tagId => integer()
      .named('tag_id')
      .references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{diaryId, tagId};
}

/// 日记列表的排序依据。
enum DiarySortField {
  /// 最后更新时间（`updated_at`）。
  updatedAt,

  /// 发表时间（`created_at`）：发表页选定的时间，时间胶囊为解封时间。
  createdAt,

  /// 标题：忽略首尾空格与 ASCII 大小写，无标题的日记固定排在最后。
  title,
}

/// 排序方向。
enum DiarySortDirection { descending, ascending }

/// 日记列表排序模式：排序依据 × 方向，置顶日记始终排在最前。
///
/// 放在数据库层是为了让首页/搜索的分页查询直接在 SQL 中排序（见
/// `watchDiaries`），避免先加载全量结果再在 UI 层截断造成首屏卡顿；UI 不再
/// 二次排序，排序口径只有 SQL 这一处。
///
/// 枚举名即持久化值（设置项与备份中的 `diarySortModeRaw`），沿用旧版的
/// `updatedDesc` / `updatedAsc` / `titleAsc`；改名会让已保存的选择失效。
enum DiarySortMode {
  updatedDesc(DiarySortField.updatedAt, DiarySortDirection.descending),
  updatedAsc(DiarySortField.updatedAt, DiarySortDirection.ascending),
  createdDesc(DiarySortField.createdAt, DiarySortDirection.descending),
  createdAsc(DiarySortField.createdAt, DiarySortDirection.ascending),
  titleAsc(DiarySortField.title, DiarySortDirection.ascending),
  titleDesc(DiarySortField.title, DiarySortDirection.descending);

  const DiarySortMode(this.field, this.direction);

  final DiarySortField field;
  final DiarySortDirection direction;

  /// 由排序依据与方向组合出对应模式（每种组合都有且仅有一个枚举值）。
  static DiarySortMode of(DiarySortField field, DiarySortDirection direction) {
    return values.firstWhere(
      (DiarySortMode mode) =>
          mode.field == field && mode.direction == direction,
    );
  }

  /// 换排序依据并保留方向：正/倒序是独立于排序依据的开关。
  DiarySortMode withField(DiarySortField field) => of(field, direction);

  /// 换方向并保留排序依据。
  DiarySortMode withDirection(DiarySortDirection direction) =>
      of(field, direction);
}

/// 业务聚合模型：日记 + 其标签列表。
class DiaryWithTags {
  const DiaryWithTags({required this.diary, required this.tags});

  final Diary diary;
  final List<Tag> tags;
}

/// 探索页轻量日记概览。
///
/// 相比 [DiaryWithTags] 不携带富文本 Delta `content`，只保留探索页统计、
/// 趋势、标签云与回顾卡片所需字段，避免切入探索页时解析/传输大正文。
class ExploreDiaryOverview {
  const ExploreDiaryOverview({
    required this.diaryId,
    required this.title,
    required this.contentText,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    this.cover,
  });

  final String diaryId;
  final String title;
  final String contentText;
  final String metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Tag> tags;
  final String? cover;
}

/// 日历月份打点聚合模型（轻量版）。
///
/// 用于日历网格渲染与月度概览：只带日期格各种样式要画的标量字段（心情、
/// 字数、显式封面、天气、标签色与 id、胶囊解封时间），不带富文本正文，避免把
/// 完整日记内容加载到月视图造成额外开销。字数由查询读出的纯文本在映射时
/// 算好（纯文本不保留在打点里）。正文首图按需另行查询
/// （见 `watchDiaryImageCandidatesInRange`）。
class DiaryCalendarMarker {
  const DiaryCalendarMarker({
    required this.diaryId,
    required this.createdAt,
    this.moodEmoji,
    this.wordCount = 0,
    this.cover,
    this.weather,
    this.weatherIconCode,
    this.capsuleUnlockAt,
    this.tagColors = const <int>[],
    this.tagIds = const <int>[],
    this.notebookIds = const <String>[],
  });

  final String diaryId;
  final DateTime createdAt;
  final String? moodEmoji;

  /// 正文字数（口径见 `TextStats`）。
  final int wordCount;

  /// 显式封面（发布页选定）；未设置时为 null，正文首图不在此字段。
  final String? cover;
  final String? weather;
  final String? weatherIconCode;

  /// 时间胶囊解封时间；非胶囊为 null。
  final DateTime? capsuleUnlockAt;

  /// 所挂标签的颜色（ARGB），按标签 id 升序。
  final List<int> tagColors;

  /// 所挂标签的 id，升序（日历按标签筛选用）。
  final List<int> tagIds;

  /// 所在普通日记本的业务 id，升序（日历按日记本筛选用）；智能日记本按规则
  /// 现算，不在其中。
  final List<String> notebookIds;

  /// 在 [now] 时刻是否仍是未解封的时间胶囊：未解封前不得泄露心情、封面、
  /// 字数等内容信息（与时间线只显示倒计时一致）。
  bool isLockedCapsuleAt(DateTime now) {
    final unlockAt = capsuleUnlockAt;
    return unlockAt != null && now.isBefore(unlockAt);
  }
}

/// 日历照片样式的正文首图候选：无显式封面、正文里出现图片嵌入的日记。
///
/// 只携带解析首图所需的正文与缓存键（`diaryId + updatedAt`），由 UI 层
/// 复用日记卡片的取图规则解析，数据库层不依赖 UI 模型。
class DiaryImageCandidate {
  const DiaryImageCandidate({
    required this.diaryId,
    required this.updatedAt,
    required this.content,
  });

  final String diaryId;
  final DateTime updatedAt;
  final String content;
}
