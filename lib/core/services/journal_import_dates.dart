/// 第三方导入的日期与时间戳校验。所有结果都使用本地时间；没有时区的
/// 日期按来源记录的墙钟解释，不为非法日期猜测下一月或为越界时间戳抛异常。
library;

final _isoDate = RegExp(
  r'^([+-]?\d{4,6})-?(\d{2})-?(\d{2})'
  r'(?:[ Tt](\d{2})(?::?(\d{2}))?(?::?(\d{2}))?'
  r'(?:[.,](\d+))?\s*(?:([Zz])|([+-])(\d{2})(?::?(\d{2}))?)?)?$',
);

/// ISO 8601（包括无分隔符的 ENEX 时间）。Dart 默认会把 2 月 30 日
/// 解析成 3 月，必须先校验来源的日历字段再做时区换算。
DateTime? parseJournalDateTime(Object? raw) {
  if (raw is! String) return null;
  final text = raw.trim();
  final match = _isoDate.firstMatch(text);
  if (match == null) return null;
  int field(int index) => int.tryParse(match.group(index) ?? '') ?? 0;
  if (!isJournalCalendarDate(field(1), field(2), field(3)) ||
      field(4) > 23 ||
      field(5) > 59 ||
      field(6) > 59 ||
      field(10) > 23 ||
      field(11) > 59) {
    return null;
  }
  final parsed = DateTime.tryParse(text);
  return parsed == null
      ? null
      : parsed.isUtc
      ? parsed.toLocal()
      : parsed;
}

bool isJournalCalendarDate(int year, int month, int day) {
  if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
    return false;
  }
  return day <= DateTime.utc(year, month + 1, 0).day;
}

/// Unix 毫秒或微秒，兼容数字字符串。先判断有限值与 DateTime 的范围，
/// 否则导出中的哨兵值（例如 1.79e308）会在转换时终止整个导入。
DateTime? journalEpochTime(Object? raw, {bool microseconds = false}) {
  final number = raw is num
      ? raw
      : raw is String
      ? num.tryParse(raw.trim())
      : null;
  if (number == null || !number.isFinite) return null;
  final limit = microseconds ? 8640000000000000000 : 8640000000000000;
  if (number.abs() > limit) return null;
  final time = microseconds
      ? DateTime.fromMicrosecondsSinceEpoch(number.toInt())
      : DateTime.fromMillisecondsSinceEpoch(number.toInt());
  return time.year >= 1 && time.year <= 9999 ? time : null;
}
