import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';

/// 探索页轻量日记流：
/// - 读取全部未删除日记（含归档）的概览字段；
/// - 不携带富文本 Delta 正文，避免切入探索页时做全量大字段传输；
/// - 与日记列表页筛选条件解耦，保证探索统计口径稳定。
final exploreDiariesProvider = StreamProvider<List<ExploreDiaryOverview>>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchExploreDiaryOverviews();
});
