part of 'app_database.dart';

/// 纪念日表：生日、恋爱纪念、倒数日等“记住一个日子”的条目。
///
/// 设计要点：
/// 1. `id` 只用于本地；`anniversaryId` 是业务唯一标识（UUID v4），备份合并按它
///    判定“同一条”，与日记的 `diaryId` 同理；
/// 2. `baseDate` 存 `YYYY-MM-DD` 文本而不是时间戳：纪念日只有日期没有时刻，
///    时间戳要经时区换算，换设备或时区恢复备份后可能整体错位一天；
/// 3. `recurrence` 一列表达“按什么历法重复”（见 [AnniversaryRecurrence]），
///    不拆成“历法 + 是否重复”两列——“农历但不重复”没有意义，单列从结构上
///    排除这种组合；
/// 4. 农历重复时把首次那天的农历月日存成快照（`lunar*`，闰月为负数，沿用
///    tyme 的约定）：重复规则由快照决定，换算库升级也不会把用户的农历生日
///    挪走，也保留“闰四月初一”这类闰月语义；快照缺失或非法（如损坏的导入）
///    时由日期推算按 `baseDate` 重新换算；
/// 5. `linkedDiaryId` 存日记的业务 id、不建外键：备份恢复与合并时日记的本地
///    id 会变，业务 id 不变；日记被彻底删除时由删除事务清空关联；
/// 6. 条目数量通常是几十到几百条，日期推算在 Dart 里对整表进行，不建索引。
@DataClassName('Anniversary')
class Anniversaries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get anniversaryId => text().named('anniversary_id').unique()();

  TextColumn get title => text().withLength(min: 1, max: 100)();

  TextColumn get baseDate => text().named('base_date')();

  TextColumn get recurrence =>
      text().withDefault(const Constant('solarYearly'))();

  IntColumn get lunarYear => integer().named('lunar_year').nullable()();

  IntColumn get lunarMonth => integer().named('lunar_month').nullable()();

  IntColumn get lunarDay => integer().named('lunar_day').nullable()();

  TextColumn get linkedDiaryId => text().named('linked_diary_id').nullable()();

  TextColumn get note => text().withDefault(const Constant(''))();

  BoolColumn get isPinned =>
      boolean().named('is_pinned').withDefault(const Constant(false))();

  /// 扩展字段（JSON 对象字符串），预留给图标、颜色等以后的展示选项。
  TextColumn get metadata => text().withDefault(const Constant('{}'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}

/// 纪念日的重复规则。枚举名即持久化值（`recurrence` 列与备份），改名等同于
/// 改存储格式。
enum AnniversaryRecurrence {
  /// 不重复：只记一个日子，之前倒数“还有 X 天”，之后正数“已经 X 天”。
  once,

  /// 每年按公历同月同日重复（生日、纪念日）。
  solarYearly,

  /// 每年按农历同月同日重复（农历生日、忌日）。
  lunarYearly;

  /// 解析持久化值；未知值（如更新版本写入的新规则）按 [once] 处理——只按
  /// 记下的那一天显示，是对未知规则最不会出错的理解。
  static AnniversaryRecurrence parse(String? raw) {
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return once;
  }
}

/// 纪念日日期的持久化格式 `YYYY-MM-DD`（只取年月日）。
String formatAnniversaryDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 解析 `YYYY-MM-DD`，返回本地零点；格式不对或日期不存在（如 2月30日）时为
/// null，备份校验据此拒绝坏行。
DateTime? parseAnniversaryDate(String raw) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (match == null) {
    return null;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}
