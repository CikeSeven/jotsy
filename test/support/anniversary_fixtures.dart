import 'package:node_diary/core/database/app_database.dart';

/// 测试用纪念日行；[id] 同时生成业务 id，测试间保持唯一即可。
Anniversary testAnniversary({
  required int id,
  required String title,
  required String baseDate,
  AnniversaryRecurrence recurrence = AnniversaryRecurrence.solarYearly,
  int? lunarYear,
  int? lunarMonth,
  int? lunarDay,
  String? linkedDiaryId,
  String note = '',
  bool isPinned = false,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime(2026, 1, 1, 0, 0, id);
  return Anniversary(
    id: id,
    anniversaryId: 'anniversary-$id',
    title: title,
    baseDate: baseDate,
    recurrence: recurrence.name,
    lunarYear: lunarYear,
    lunarMonth: lunarMonth,
    lunarDay: lunarDay,
    linkedDiaryId: linkedDiaryId,
    note: note,
    isPinned: isPinned,
    metadata: '{}',
    createdAt: created,
    updatedAt: created,
  );
}
