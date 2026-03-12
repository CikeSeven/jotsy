import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';

/// 探索页日记流：
/// - 读取全部未删除日记（含归档）；
/// - 与日记列表页筛选条件解耦，保证探索统计口径稳定。
final exploreDiariesProvider = StreamProvider<List<DiaryWithTags>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllActiveDiaries();
});
