import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';

/// 全部日子的心情，按本地零点日期索引；drift watch 驱动，设定、清除与备份
/// 恢复后自动推送。
///
/// 整表订阅而不是按月查询：每天至多一行，十年也只有几千行，月视图、年视图
/// 与长按面板共用同一份索引，翻月、进出年视图都不用重新查库。
final dayMoodsProvider = StreamProvider<Map<DateTime, DayMood>>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchDayMoods().map(indexDayMoods);
});

/// 把数据库行整理成按日期查找的索引。日期格式不对或心情名认不出（更新版本
/// 写入）的行跳过，不让一行坏数据挡住整张日历。
Map<DateTime, DayMood> indexDayMoods(List<DayMoodRow> rows) {
  final index = <DateTime, DayMood>{};
  for (final row in rows) {
    final day = parseAnniversaryDate(row.day);
    final mood = DayMood.parse(row.mood);
    if (day != null && mood != null) {
      index[DateUtils.dateOnly(day)] = mood;
    }
  }
  return Map<DateTime, DayMood>.unmodifiable(index);
}
