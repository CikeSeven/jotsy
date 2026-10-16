import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../viewmodels/anniversary_calendar.dart';
import '../viewmodels/anniversary_calendar_index.dart';
import '../viewmodels/anniversary_rule.dart';

/// 全部纪念日（置顶在前、再按创建先后），drift watch 驱动，增删改后自动
/// 推送新列表，不需要手动刷新。
final anniversaryListProvider = StreamProvider<List<Anniversary>>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchAnniversaries();
});

/// 单条纪念日（详情页、编辑页）；被删除后推送 null。
final anniversaryProvider = StreamProvider.autoDispose
    .family<Anniversary?, String>((Ref ref, String anniversaryId) {
      return ref.watch(appDatabaseProvider).watchAnniversary(anniversaryId);
    });

/// 日历网格用的按日索引。列表重新加载期间沿用上一份数据，日期格上的
/// 纪念日名称不会闪一下消失；还没有数据时为空索引。
final anniversaryCalendarIndexProvider = Provider<AnniversaryCalendarIndex>((
  Ref ref,
) {
  final rows = ref.watch(anniversaryListProvider).value;
  if (rows == null || rows.isEmpty) {
    return AnniversaryCalendarIndex.empty;
  }
  return AnniversaryCalendarIndex(rows);
});

/// 关联的日记（不含回收站中的）；进回收站或被彻底删除后推送 null。
final anniversaryLinkedDiaryProvider = StreamProvider.autoDispose
    .family<DiaryWithTags?, String>((Ref ref, String diaryId) {
      return ref.watch(appDatabaseProvider).watchActiveDiaryWithTags(diaryId);
    });

/// 关联日记的候选：所选日期前后各 7 天写下的日记（按创建时间倒序）。
final anniversaryDiaryCandidatesProvider = StreamProvider.autoDispose
    .family<List<DiaryWithTags>, DateTime>((Ref ref, DateTime day) {
      final start = DateTime(day.year, day.month, day.day - 7);
      final end = DateTime(day.year, day.month, day.day + 8);
      return ref.watch(appDatabaseProvider).watchDiariesCreatedInRanges(
        <(DateTime, DateTime)>[(start, end)],
      );
    });

/// “历年这一天”：纪念日在今天及以前每一次那天写下的日记（最近 100 次，
/// 每次一个自然日区间，最多 200 个 SQL 变量）。
final anniversaryPastDiariesProvider = StreamProvider.autoDispose
    .family<List<DiaryWithTags>, AnniversaryRule>((
      Ref ref,
      AnniversaryRule rule,
    ) {
      final past = AnniversaryCalendar.past(rule, DateTime.now());
      return ref
          .watch(appDatabaseProvider)
          .watchDiariesCreatedInRanges(<(DateTime, DateTime)>[
            for (final occurrence in past)
              (
                occurrence.date,
                DateTime(
                  occurrence.date.year,
                  occurrence.date.month,
                  occurrence.date.day + 1,
                ),
              ),
          ]);
    });
