/// 只有日期、没有时刻的本地日期文本 `YYYY-MM-DD`：纪念日的 `baseDate`、
/// 这天的心情的 `day` 与待办的 `due_date` 共用同一格式。
///
/// 存文本而不是时间戳：时间戳要经时区换算，换设备或时区恢复备份后可能整体
/// 错位一天。独立成库（而不是 `app_database.dart` 的 part），供数据库之外的
/// 纯函数（如待办的重复推算）直接引用。
library;

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
