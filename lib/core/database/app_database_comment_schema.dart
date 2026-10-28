part of 'app_database.dart';

/// 日记留言表：重读旧日记时写给这一篇的回应或批注，与正文相互独立。
///
/// 设计要点：
/// 1. `commentId` 是业务唯一标识（UUID v4），备份合并按它判定“同一条”；
///    `id` 只用于本地；
/// 2. `diaryId` 存日记的**业务 id**、不建外键（与纪念日的 `linkedDiaryId`
///    同理）：备份恢复与合并时日记的本地 id 会变、业务 id 不变，合并时不必
///    换算；彻底删除日记时由删除事务一并删掉它的留言，软删除不动（从回收站
///    恢复后留言还在）；
/// 3. 只存纯文本与可选心情：`mood` 为日记心情选项里的 emoji 原文（与日记
///    metadata 的心情同一口径），用户之后改了心情选项，旧留言仍显示原来的
///    emoji；
/// 4. `createdAt` 是写下的时间，编辑不改它（时间线按它排序、相对时间从它
///    算起）；`editedAt` 非空即“已编辑”；
/// 5. 预览页按日记读、卡片按日记计数、搜索按日记 EXISTS，都以 `diary_id`
///    开头，建 `(diary_id, created_at)` 索引。
@DataClassName('DiaryCommentRow')
@TableIndex(
  name: 'idx_diary_comments_diary',
  columns: <Symbol>{#diaryId, #createdAt},
)
class DiaryComments extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get commentId => text().named('comment_id').unique()();

  TextColumn get diaryId => text().named('diary_id')();

  TextColumn get content => text()();

  TextColumn get mood => text().nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get editedAt => dateTime().named('edited_at').nullable()();
}

/// 一条留言最多的字数（输入框 `maxLength`，按字形簇计）。只在写留言的面板
/// 限制：数据库层只拒绝空白留言，备份里更长的留言原样恢复。
const int kDiaryCommentMaxLength = 1000;
