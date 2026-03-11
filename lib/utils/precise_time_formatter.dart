/// 精确到分钟的时间格式化工具（用于更新时间展示）。
///
/// 规则：
/// - 同一天：`HH:mm`（示例：`12:22`）
/// - 同一年不同天：`M月d日 HH:mm`（示例：`3月11日 21:30`）
/// - 跨年：`yyyy年 M月d日 HH:mm`（示例：`2013年 3月23日 12:13`）
class PreciseTimeFormatter {
  const PreciseTimeFormatter._();

  static String format({
    required DateTime target,
    required DateTime now,
  }) {
    final localTarget = target.toLocal();
    final localNow = now.toLocal();
    final hm = _formatHourMinute(localTarget);

    if (_isSameDay(localTarget, localNow)) {
      return hm;
    }
    if (localTarget.year == localNow.year) {
      return '${localTarget.month}月${localTarget.day}日 $hm';
    }
    return '${localTarget.year}年 ${localTarget.month}月${localTarget.day}日 $hm';
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatHourMinute(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
