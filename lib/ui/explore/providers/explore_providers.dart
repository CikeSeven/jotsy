import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../controllers/explore_content_extractor.dart';
import '../models/explore_view_data.dart';

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

/// 还没解封的时间胶囊（时间胶囊卡）。只在卡片显示时订阅。
final exploreLockedCapsulesProvider =
    StreamProvider.autoDispose<List<LockedCapsuleSummary>>(
      (Ref ref) => ref.watch(appDatabaseProvider).watchLockedCapsules(),
    );

/// 媒体卡“包括正文里的图片”：最近更新的几篇带图日记里的图片（封面在前，
/// 再按正文顺序），同一来源只出现一次，最多 [limit] 张。
///
/// 只查最近的 `limit * 2` 篇：每篇至少一张图，通常够用；不够时就少显示几张，
/// 完整的图片在媒体画廊页里分页加载。
final exploreRecentMediaProvider = StreamProvider.autoDispose
    .family<List<ExploreMediaItem>, int>((Ref ref, int limit) {
      const extractor = ExploreContentExtractor();
      return ref
          .watch(appDatabaseProvider)
          .watchRecentMediaContents(limit: limit * 2)
          .map((List<DiaryMediaContent> rows) {
            final seen = <String>{};
            final items = <ExploreMediaItem>[];
            for (final row in rows) {
              for (final source in extractor.resolveMediaSourcesFrom(
                cover: row.cover,
                content: row.content,
              )) {
                if (items.length >= limit) break;
                if (!seen.add(source)) continue;
                items.add(
                  ExploreMediaItem(source: source, diaryId: row.diaryId),
                );
              }
            }
            return List<ExploreMediaItem>.unmodifiable(items);
          });
    });

/// 数据看板的照片数：日记 id → 这篇的图片数（封面与正文图片去重）。只在
/// 看板选了“照片”时订阅（要读带图日记的正文）。
final explorePhotoCountsProvider = StreamProvider.autoDispose<Map<String, int>>(
  (Ref ref) {
    const extractor = ExploreContentExtractor();
    return ref
        .watch(appDatabaseProvider)
        .watchScopedMediaContents(DiaryListScope.all)
        .map(
          (List<DiaryMediaContent> rows) =>
              Map<String, int>.unmodifiable(<String, int>{
                for (final row in rows)
                  row.diaryId: extractor
                      .resolveMediaSourcesFrom(
                        cover: row.cover,
                        content: row.content,
                      )
                      .length,
              }),
        );
  },
);
