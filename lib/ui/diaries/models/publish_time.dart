/// 由打开者带来的请求值推出新日记的发表时间。
///
/// 新建日记默认在“发表那一刻”发表；日历按日新建或恢复的草稿可以带来一个
/// 请求值 [requested]：
/// - null：取 [now]；
/// - 只含日期（当天 00:00:00.000000）：补上 [now] 的时分秒，日记落在那天、
///   时刻取发表时；
/// - 晚于 [now]：回退到 [now]，不产生未来的发表时间。
///
/// 发布页在提交那一刻调用，而不是打开时算好一个固定值：否则在发布页停留、
/// 或往返编辑页继续写之后，日记仍记着第一次打开发布页的时间。
DateTime resolvePublishAt(DateTime? requested, {required DateTime now}) {
  if (requested == null) {
    return now;
  }
  final local = requested.toLocal();
  final isDateOnly =
      local.hour == 0 &&
      local.minute == 0 &&
      local.second == 0 &&
      local.millisecond == 0 &&
      local.microsecond == 0;
  final resolved = isDateOnly
      ? DateTime(
          local.year,
          local.month,
          local.day,
          now.hour,
          now.minute,
          now.second,
          now.millisecond,
          now.microsecond,
        )
      : local;
  return resolved.isAfter(now) ? now : resolved;
}
