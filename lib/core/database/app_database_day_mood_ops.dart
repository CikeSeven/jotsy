part of 'app_database.dart';

/// 这天的心情读写。
///
/// 输入：日历页长按面板选定的日期与心情；输出：drift watch 流。清除是硬删除，
/// 撤销由调用方持有被删的整行、经 [restoreDayMood] 原样写回。
mixin _AppDatabaseDayMoodOps on _$AppDatabase {
  /// 全部日子的心情（顺序无意义，调用方按日期建索引）。
  Stream<List<DayMoodRow>> watchDayMoods() => select(dayMoods).watch();

  /// 设定 [day] 这天的心情；已有心情时覆盖。只取 [day] 的年月日。
  Future<void> setDayMood(DateTime day, DayMood mood) {
    return into(dayMoods).insertOnConflictUpdate(
      DayMoodsCompanion.insert(
        day: formatAnniversaryDate(day),
        mood: mood.name,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// 清除 [day] 这天的心情并返回被删的整行（供撤销）；这天本来没有心情时
  /// 返回 null。
  Future<DayMoodRow?> clearDayMood(DateTime day) {
    final key = formatAnniversaryDate(day);
    return transaction(() async {
      final row = await (select(
        dayMoods,
      )..where((t) => t.day.equals(key))).getSingleOrNull();
      if (row != null) {
        await (delete(dayMoods)..where((t) => t.day.equals(key))).go();
      }
      return row;
    });
  }

  /// 撤销清除：整行写回（含原来的更新时间）；这期间又设了新心情时以撤销为准。
  Future<void> restoreDayMood(DayMoodRow row) {
    return into(dayMoods).insertOnConflictUpdate(row.toCompanion(false));
  }
}
