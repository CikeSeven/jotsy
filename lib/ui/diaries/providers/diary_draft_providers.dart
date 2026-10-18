import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../utils/provider_retention.dart';
import '../viewmodels/diary_draft_list_item.dart';

/// 草稿箱列表（最近编辑在前）。先等旧版单份草稿迁移完成，升级后第一次
/// 打开就能看到它；限时保留，短时间返回复用已加载的结果。
final diaryDraftsProvider =
    StreamProvider.autoDispose<List<DiaryDraftListItem>>((Ref ref) async* {
      retainQueryWhileRecentlyUsed(ref);
      final database = ref.watch(appDatabaseProvider);
      await ref.watch(diaryDraftLegacyMigrationProvider.future);
      yield* database.watchDiaryDrafts().map(
        (rows) => rows.map(DiaryDraftListItem.of).toList(growable: false),
      );
    });

/// 草稿份数：首页顶栏的角标与设置入口读取；只订阅计数，不读正文。
final diaryDraftCountProvider = StreamProvider.autoDispose<int>((
  Ref ref,
) async* {
  final database = ref.watch(appDatabaseProvider);
  await ref.watch(diaryDraftLegacyMigrationProvider.future);
  yield* database.watchDiaryDraftCount();
});
