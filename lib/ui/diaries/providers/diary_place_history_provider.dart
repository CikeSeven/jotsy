import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';

/// 用过的地点（口径见 `AppDatabase.watchPlaceHistory`），随日记写入更新。
///
/// autoDispose：只有“最近”条带（面板展开且地点为空时）与“用过的地点”
/// 子页（打开时）订阅它。写日记时面板收着，自动保存不会牵动这条汇总查询。
final diaryPlaceHistoryProvider =
    StreamProvider.autoDispose<List<DiaryPlaceUsage>>(
      (Ref ref) => ref.watch(appDatabaseProvider).watchPlaceHistory(),
    );
