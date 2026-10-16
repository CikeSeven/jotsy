import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../viewmodels/anniversary_calendar_index.dart';

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
