import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/utils/provider_retention.dart';

import 'diary_filters.dart';

/// 首页列表的完整时间轴（快速滚动条用，见 `watchDiaryTimeline`）。
///
/// 以分页查询的同一组条件为 key，但不看窗口大小：调用方传
/// [DiaryPageQuery.timelineKey]，翻页时不换实例、不重新查询。只在列表还有
/// 没加载的部分（或成书顺序要章节）时才订阅，短列表不多一条查询。
final diaryTimelineProvider = StreamProvider.autoDispose
    .family<List<DiaryTimelineEntry>, DiaryPageQuery>((
      Ref ref,
      DiaryPageQuery query,
    ) {
      retainQueryWhileRecentlyUsed(ref);
      final db = ref.watch(appDatabaseProvider);
      return db.watchDiaryTimeline(
        keyword: query.keyword,
        requiredTagIds: query.requiredTagIds,
        sortMode: query.sortMode,
        scope: query.scope,
      );
    });
