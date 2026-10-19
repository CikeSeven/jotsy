import 'package:intl/intl.dart';

/// 一段日期首尾两端共用的日期格式：首尾跨年或不在今年（[now] 所在年）时带上
/// 年份，否则只写月日，窄屏上一行放得下。
///
/// 日历的范围统计标题、智能日记本“固定区间”规则的摘要与由日期范围新建的
/// 日记本默认名称共用，三处写法保持一致。
DateFormat dateRangeEndpointFormat(
  String locale, {
  required DateTime first,
  required DateTime last,
  required DateTime now,
}) {
  final withYear = first.year != last.year || first.year != now.year;
  return withYear ? DateFormat.yMMMd(locale) : DateFormat.MMMd(locale);
}
