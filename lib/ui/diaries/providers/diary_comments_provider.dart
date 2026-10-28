import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../settings/providers/app_features_provider.dart';

/// 留言功能是否开启（设置 → 功能管理，默认关闭）。各处只读这一项决定
/// 留言区、留言数、搜索留言与导出开关是否出现。
final diaryCommentsEnabledProvider = Provider<bool>(
  (Ref ref) => ref.watch(appFeaturesProvider.select((f) => f.comments)),
);

/// 某篇日记的全部留言（按写下时间旧 → 新）。订阅而不是一次性读取：留言只在
/// 预览页里写，写完要立刻出现在时间线上；这条查询只读留言表，写日记不会让
/// 它重查。
final diaryCommentsProvider = StreamProvider.autoDispose
    .family<List<DiaryCommentRow>, String>(
      (Ref ref, String diaryId) =>
          ref.watch(appDatabaseProvider).watchDiaryComments(diaryId),
    );

/// 每篇日记的留言条数（键为日记业务 id）：卡片与预览页信息栏的留言数。
///
/// 功能关闭时不订阅、给空表——调用方仍可无条件 watch 它，关闭时不多一条
/// 查询，也不会显示留言数。
final diaryCommentCountsProvider = StreamProvider.autoDispose<Map<String, int>>(
  (Ref ref) {
    if (!ref.watch(diaryCommentsEnabledProvider)) {
      return Stream<Map<String, int>>.value(const <String, int>{});
    }
    return ref.watch(appDatabaseProvider).watchDiaryCommentCounts();
  },
);

/// 搜索词命中的留言（每篇取第一条，键为日记业务 id）：搜索结果里“只命中
/// 留言”的卡片下方显示它。功能关闭或没有关键词时为空表。
final diaryCommentHitsProvider = StreamProvider.autoDispose
    .family<Map<String, DiaryCommentRow>, String>((Ref ref, String keyword) {
      if (!ref.watch(diaryCommentsEnabledProvider)) {
        return Stream<Map<String, DiaryCommentRow>>.value(
          const <String, DiaryCommentRow>{},
        );
      }
      return ref.watch(appDatabaseProvider).watchDiaryCommentHits(keyword);
    });
