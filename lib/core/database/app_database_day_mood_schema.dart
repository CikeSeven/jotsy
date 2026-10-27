part of 'app_database.dart';

/// 这天的心情：用户在日历上长按某个日期设定的心情，与日记里各篇的心情相互
/// 独立——没写日记的日子也能记下心情，写了几篇的日子也只有这一个总体心情。
///
/// 设计要点：
/// 1. 以日期 `day` 为主键：一天只有一种心情，再设一次即覆盖。日期存
///    `YYYY-MM-DD` 文本（与纪念日的 `baseDate` 同一格式，经
///    [formatAnniversaryDate] / [parseAnniversaryDate]），不存时间戳，换设备
///    或时区恢复备份后不会错位一天；
/// 2. 不另建业务 id：日期本身就是跨设备唯一的标识，备份合并按日期匹配；
/// 3. `mood` 存 [DayMood] 的枚举名；认不出的值（更新版本写入的新心情）读取
///    时按“没有心情”处理，但行原样保留，备份往返不丢；
/// 4. 每天至多一行，十年也不过几千行：日历整表订阅、在 Dart 里按日期建索引，
///    不建额外的索引。
@DataClassName('DayMoodRow')
class DayMoods extends Table {
  TextColumn get day => text()();

  TextColumn get mood => text()();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{day};
}

/// 这天的心情，由低到高五档。枚举名即持久化值（`mood` 列与备份），改名等同
/// 于改存储格式。
///
/// 五档与日记心情（十档）合并出的五段一一对应（[index] 即段号 0~4，见
/// `MoodBandPalette`），年视图按心情着色时两者同色。
enum DayMood {
  awful,
  bad,
  meh,
  good,
  great;

  /// 解析持久化值；未知值返回 null（按“这天没有心情”显示）。
  static DayMood? parse(String? raw) {
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }
}
