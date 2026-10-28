import 'package:intl/intl.dart';

/// 按天的图表（趋势、节奏）柱下的标签：7 天写星期，14 / 30 天每隔几天写
/// 日期（最后一天总写），更长时只在每月 1 日写月份；其余为空，避免挤在一起。
List<String> exploreDayAxisLabels(List<DateTime> days, String localeName) {
  final count = days.length;
  final weekday = DateFormat.E(localeName);
  final month = DateFormat.MMM(localeName);
  final every = count <= 14 ? 2 : 5;
  return <String>[
    for (var i = 0; i < count; i++)
      if (count <= 7)
        weekday.format(days[i])
      else if (count <= 31)
        (i == count - 1 || (count - 1 - i) % every == 0) ? '${days[i].day}' : ''
      else
        days[i].day == 1 || i == 0 ? month.format(days[i]) : '',
  ];
}
