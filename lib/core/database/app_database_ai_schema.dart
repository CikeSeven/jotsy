part of 'app_database.dart';

/// AI 助手的本机记录（schema v17）：对话、对话里的消息、读后回应与回顾。
///
/// 设计要点：
/// 1. 三张表都以业务 id（UUID v4）为唯一标识，备份合并按它判定“同一条”；
///    `id` 只用于本地；
/// 2. 引用日记一律存日记的**业务 id**、不建外键（与留言同理）：彻底删除
///    日记时由删除事务删掉它的回应；对话里引用的日记只存在 `citations`
///    JSON 里，日记删了显示“不存在”，不改写历史对话；
/// 3. 只随完整备份导出与恢复，**不参与局域网同步**（与草稿箱同一口径）：
///    AI 记录是“在这台设备上和 AI 聊过什么”，同步引擎不读这三张表；
/// 4. 可演进的字段放 JSON 文本列（`scope` / `citations` / `meta`），解析
///    逐字段容错，新增设置不必再升 schema。

/// 一次对话。
@DataClassName('AiConversationRow')
@TableIndex(name: 'idx_ai_conversations_updated', columns: <Symbol>{#updatedAt})
class AiConversations extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get conversationId => text().named('conversation_id').unique()();

  /// 标题（用户改名或自动起名）；空为“新对话”。
  TextColumn get title => text().withDefault(const Constant(''))();

  /// 对话使用的人设 id；null 为对话的默认人设。
  TextColumn get personaId => text().named('persona_id').nullable()();

  /// 检索范围 JSON（时间、日记本、标签、固定的日记、检索方式、模型）。
  TextColumn get scope => text().withDefault(const Constant('{}'))();

  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}

/// 对话里的一条消息。
@DataClassName('AiMessageRow')
@TableIndex(
  name: 'idx_ai_messages_conversation',
  columns: <Symbol>{#conversationId, #createdAt},
)
class AiMessages extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get messageId => text().named('message_id').unique()();

  TextColumn get conversationId => text().named('conversation_id')();

  /// `user` 或 `assistant`。
  TextColumn get role => text()();

  /// Markdown 正文。
  TextColumn get content => text().withDefault(const Constant(''))();

  /// 模型的思考过程（有的话）。
  TextColumn get reasoning => text().withDefault(const Constant(''))();

  /// 这条回答参考的日记 JSON 数组（业务 id、标题、日期、编号）。
  TextColumn get citations => text().withDefault(const Constant('[]'))();

  /// 服务商名、模型、用量、错误等 JSON。
  TextColumn get meta => text().withDefault(const Constant('{}'))();

  /// `done` / `error` / `stopped`。
  TextColumn get status => text().withDefault(const Constant('done'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
}

/// 一份 AI 生成的结果：某篇日记的读后回应，或一段时间的回顾。
@DataClassName('AiResultRow')
@TableIndex(
  name: 'idx_ai_results_diary',
  columns: <Symbol>{#diaryId, #createdAt},
)
@TableIndex(name: 'idx_ai_results_kind', columns: <Symbol>{#kind, #createdAt})
class AiResults extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get resultId => text().named('result_id').unique()();

  /// `reply`（读后回应）或 `recap`（回顾）。
  TextColumn get kind => text()();

  /// 回应所属日记的业务 id；回顾为 null。
  TextColumn get diaryId => text().named('diary_id').nullable()();

  /// 回顾覆盖的时间范围（含起点、不含终点）。
  DateTimeColumn get periodStart =>
      dateTime().named('period_start').nullable()();

  DateTimeColumn get periodEnd => dateTime().named('period_end').nullable()();

  /// 回顾的范围 JSON（日记本、章节选择、篇数等）。
  TextColumn get scope => text().withDefault(const Constant('{}'))();

  TextColumn get title => text().withDefault(const Constant(''))();

  /// Markdown 正文。
  TextColumn get content => text()();

  TextColumn get personaId => text().named('persona_id').nullable()();

  /// 服务商名、模型、用量、人设名快照等 JSON。
  TextColumn get meta => text().withDefault(const Constant('{}'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
}

/// AI 结果的类别。
abstract final class AiResultKind {
  static const String reply = 'reply';
  static const String recap = 'recap';
}

/// AI 消息的角色与状态。
abstract final class AiMessageRole {
  static const String user = 'user';
  static const String assistant = 'assistant';
}

abstract final class AiMessageStatus {
  static const String done = 'done';
  static const String error = 'error';
  static const String stopped = 'stopped';
}
