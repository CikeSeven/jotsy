import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';

/// 单条日记详情 provider（含标签聚合）。
///
/// 通过业务 `diaryId` 查询，供编辑页与预览页共用。
final diaryDetailProvider = FutureProvider.autoDispose
    .family<DiaryWithTags?, String>((Ref ref, String diaryId) {
      final db = ref.watch(appDatabaseProvider);
      return db.getDiaryWithTagsByDiaryId(diaryId);
    });
