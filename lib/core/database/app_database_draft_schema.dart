part of 'app_database.dart';

/// 草稿箱：还没发布的新建日记，每次新建对应一行。
///
/// 设计要点：
/// 1. 不放进 `diaries` 表：日历、探索、导出、纪念日等十几处查询各自写了
///    “未删除”的过滤，草稿混进去要逐个补条件，漏一处就会出现在列表或统计
///    里；独立成表后日记查询完全不用改；
/// 2. `draftId` 是业务唯一标识（UUID v4），编辑页按它续写同一份，备份按它
///    判定同一条；`id` 只用于本地；
/// 3. `payload` 存编辑页的完整草稿 JSON（`NewDiaryDraft.toJson`：正文 Delta、
///    封面、标签、位置、天气、心情、胶囊等），数据库层不解析它，字段演进只
///    在草稿模型一处；`title` / `contentText` 是冗余镜像，草稿箱列表与字数
///    不必为每行解析整份正文；
/// 4. 正文里的媒体与封面是托管目录下的绝对路径，媒体清理把 `payload` 当作
///    引用来源，备份恢复时改写其中的路径；
/// 5. 草稿通常只有几份到几十份，按更新时间倒序全表读取，不建索引。
@DataClassName('DiaryDraftRow')
class DiaryDrafts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get draftId => text().named('draft_id').unique()();

  TextColumn get title => text().withDefault(const Constant(''))();

  TextColumn get contentText =>
      text().named('content_text').withDefault(const Constant(''))();

  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}
