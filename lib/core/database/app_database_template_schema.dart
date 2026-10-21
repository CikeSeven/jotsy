part of 'app_database.dart';

/// 内置模板 id 的前缀；用户模板的 id 是 UUID，永远不会以它开头。
const String builtInDiaryTemplateIdPrefix = 'builtin.';

/// 用户自建的日记模板，以及用户改过的内置模板，每个模板一行；内置模板的
/// 默认内容由 ARB 文案在运行时编译，不落库。
///
/// 设计要点：
/// 1. `templateId` 是业务唯一标识（UUID v4），备份合并按它判定同一个模板；
///    以 `builtin.` 开头的行是改过的内置模板，以同一 id 替换编译出的默认
///    内容（最近使用、自动套用、日记本默认模板都不用改指向），删掉这一行
///    即恢复默认；
/// 2. `payload` 存模板的完整 JSON（`DiaryTemplateJson.toPayload`：名称、图标、
///    标题格式、正文 Delta、预设标签与心情、推荐规则等），数据库层不解析它，
///    字段演进只在模板模型一处；`name` 是冗余镜像，便于排查与将来按名称排序；
/// 3. 正文只允许文字与分隔线（写入前经 `sanitizeDiaryTemplateDelta`），不含
///    任何设备路径，因此媒体清理与备份路径改写都不用关心这张表；
/// 4. `sortOrder` 是“我的模板”的手动排序，新模板排在最后；改过的内置模板
///    仍按内置顺序显示，不看这一列；
/// 5. 模板通常只有几个到几十个，全表读取，不建索引。
@DataClassName('DiaryTemplateRow')
class DiaryTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get templateId => text().named('template_id').unique()();

  TextColumn get name => text().withDefault(const Constant(''))();

  TextColumn get payload => text()();

  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}
