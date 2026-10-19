part of 'app_database.dart';

/// 日记本：把日记归成一本本，一篇日记可以同时在多本里（相册模型）。
///
/// 设计要点：
/// 1. `id` 只用于本地关联；`notebookId` 是业务唯一标识（UUID v4，
///    [AppDatabase.newBusinessId]），对外 API 一律用它：备份恢复与合并时本地
///    id 会变，业务 id 不变（与纪念日、模板同理）；
/// 2. `kind` / `visibility` 是独立列而不放进 payload：日记列表要在 SQL 里按
///    “是否手动、是否私密”过滤（私密本里的日记不出现在“全部日记”），放在
///    JSON 里就只能取出来逐行解析。存枚举的 [Enum.name]，认不出的值按
///    [NotebookKind.fromName] / [NotebookVisibility.fromName] 回退；
/// 3. 只有手动日记本可以私密：智能日记本的成员是规则现算的，藏起整本会让
///    任何符合规则的日记“消失”，写入时一律存成 normal；
/// 4. `payload` 存其余可演进的设置（简介、图标、颜色、封面、章节、排序、目标、
///    默认模板、智能规则），格式与容错见 [NotebookPayload]；
/// 5. `sortOrder` 是书架上的手动顺序，`isPinned` 置顶的排在最前；`isClosed`
///    为“合上”（写完了、不再常用），仍可正常增删日记；
/// 6. 日记本通常只有几个到几十个，全表读取，不建索引。
@DataClassName('NotebookRow')
class Notebooks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get notebookId => text().named('notebook_id').unique()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  TextColumn get kind => text().withDefault(const Constant('manual'))();

  TextColumn get visibility => text().withDefault(const Constant('normal'))();

  TextColumn get payload => text().withDefault(const Constant('{}'))();

  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();

  BoolColumn get isPinned =>
      boolean().named('is_pinned').withDefault(const Constant(false))();

  BoolColumn get isClosed =>
      boolean().named('is_closed').withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}

/// 日记-日记本关联表（多对多），只有手动日记本有关联行。
///
/// 设计要点：
/// 1. 两端都存本地 id：列表按日记本过滤时直接与 `diaries.id` 连接，比按业务
///    id 文本连接快；对外 API 仍只收发业务 id，本地 id 只在数据库层内部换算；
/// 2. 不声明 REFERENCES：本库从不开启 `PRAGMA foreign_keys`，外键声明不会
///    生效，每条删除路径（彻底删除日记、删除/合并日记本）都在同一事务里手动
///    清理关联行；另外 v1 升级分支会把 diaries 改名重建，SQLite 会顺带把别的
///    表里指向 diaries 的外键改写成指向临时表，不声明就不受影响；
/// 3. `chapterId` 引用 [NotebookPayload.chapters] 里的章节 id，为 null 或章节
///    已删除时归到“未分章”；
/// 4. `position` 是本子内的成书顺序（目录页手动排序），新加入的排在最后；
///    `addedAt` 是加入本子的时间；
/// 5. 复合主键前缀覆盖“某篇日记在哪些本子里”；`idx_diary_notebooks_notebook`
///    覆盖“某本里有哪些日记、按成书顺序”。
@DataClassName('DiaryNotebookRow')
@TableIndex(
  name: 'idx_diary_notebooks_notebook',
  columns: <Symbol>{#notebookId, #position},
)
class DiaryNotebooks extends Table {
  IntColumn get diaryId => integer().named('diary_id')();

  IntColumn get notebookId => integer().named('notebook_id')();

  TextColumn get chapterId => text().named('chapter_id').nullable()();

  IntColumn get position => integer().withDefault(const Constant(0))();

  DateTimeColumn get addedAt => dateTime().named('added_at')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{diaryId, notebookId};
}

/// 读取日记本行里按名字存储的枚举与 payload。
extension NotebookRowFields on NotebookRow {
  NotebookKind get notebookKind => NotebookKind.fromName(kind);

  NotebookVisibility get notebookVisibility =>
      NotebookVisibility.fromName(visibility);

  /// 每次调用都会解析一遍 JSON，频繁读取时由调用方缓存。
  NotebookPayload get parsedPayload => NotebookPayload.decode(payload);

  /// 是否接受手动增删日记：只认列里的原始值，更新版本写入的未知类型一律拒绝，
  /// 不往一个不认识的本子里写关联行。
  bool get acceptsManualEntries => kind == NotebookKind.manual.name;
}
