import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';

/// 用过的地点（口径见 `AppDatabase.watchPlaceHistory`），随日记写入更新。
///
/// autoDispose：只有地点为空时的“最近”条带与“用过的地点”子页订阅它。
/// 编辑一篇已有地点的日记时两者都不在树上，自动保存不会牵动这条汇总查询。
final diaryPlaceHistoryProvider =
    StreamProvider.autoDispose<List<DiaryPlaceUsage>>(
      (Ref ref) => ref.watch(appDatabaseProvider).watchPlaceHistory(),
    );
