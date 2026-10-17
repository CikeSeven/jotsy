import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';

/// “导出日记”页的候选：全部未删除、已解封的日记（含归档），由页面再按
/// 日期范围与标签筛选。只在导出页打开期间订阅。
final diaryExportCandidatesProvider =
    StreamProvider.autoDispose<List<DiaryWithTags>>((Ref ref) {
      return ref.watch(appDatabaseProvider).watchAllActiveDiaries();
    });
