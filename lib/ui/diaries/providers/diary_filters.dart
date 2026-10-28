import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_view_preferences.dart';
import 'package:node_diary/utils/provider_retention.dart';

/// 列表筛选状态：关键词 + 选中的标签集合。
class DiaryFilterState {
  const DiaryFilterState({
    this.keyword = '',
    this.selectedTagIds = const <int>{},
  });

  final String keyword;
  final Set<int> selectedTagIds;

  /// 生成新的筛选状态副本，保持不可变数据流。
  DiaryFilterState copyWith({String? keyword, Set<int>? selectedTagIds}) {
    return DiaryFilterState(
      keyword: keyword ?? this.keyword,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
    );
  }
}

/// 已分页的日记查询结果。
class PagedDiariesResult {
  const PagedDiariesResult({
    required this.items,
    required this.limit,
    required this.hasMore,
  });

  final List<DiaryWithTags> items;
  final int limit;
  final bool hasMore;
}

/// 日记列表分页查询参数。
class DiaryPageQuery {
  const DiaryPageQuery({
    required this.keyword,
    required this.requiredTagIds,
    required this.limit,
    required this.sortMode,
    this.scope = DiaryListScope.all,
  });

  final String keyword;
  final List<int> requiredTagIds;
  final int limit;
  final DiarySortMode sortMode;

  /// 查询范围（全部日记或某本日记本），参与相等比较：切换日记本即换一个
  /// provider 实例，不会命中别的范围的缓存。
  final DiaryListScope scope;

  /// 同一组筛选、排序与范围，窗口大小归零：不随翻页变化的查询 key（见
  /// `diaryTimelineProvider`）。
  DiaryPageQuery get timelineKey => limit == 0
      ? this
      : DiaryPageQuery(
          keyword: keyword,
          requiredTagIds: requiredTagIds,
          limit: 0,
          sortMode: sortMode,
          scope: scope,
        );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! DiaryPageQuery) {
      return false;
    }
    if (keyword != other.keyword ||
        limit != other.limit ||
        sortMode != other.sortMode ||
        scope != other.scope ||
        requiredTagIds.length != other.requiredTagIds.length) {
      return false;
    }
    for (var index = 0; index < requiredTagIds.length; index += 1) {
      if (requiredTagIds[index] != other.requiredTagIds[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    keyword,
    limit,
    sortMode,
    scope,
    Object.hashAll(requiredTagIds),
  );
}

/// 日记筛选状态控制器。
///
/// 负责维护筛选条件，并向列表查询 provider 提供统一输入。
class DiaryFilterNotifier extends Notifier<DiaryFilterState> {
  @override
  DiaryFilterState build() {
    return const DiaryFilterState();
  }

  /// 更新关键词筛选。
  void setKeyword(String value) {
    state = state.copyWith(keyword: value);
  }

  /// 单个标签开关。
  void toggleTag(int tagId, bool selected) {
    final next = <int>{...state.selectedTagIds};
    if (selected) {
      next.add(tagId);
    } else {
      next.remove(tagId);
    }
    state = state.copyWith(selectedTagIds: next);
  }

  /// 批量替换标签筛选，用于从设置中的“标签记忆”恢复状态。
  void setTags(Iterable<int> tagIds) {
    final normalized = <int>{
      for (final tagId in tagIds)
        if (tagId > 0) tagId,
    };
    state = state.copyWith(selectedTagIds: normalized);
  }

  /// 清空标签筛选（保留关键词）。
  void clearTags() {
    if (state.selectedTagIds.isEmpty) {
      return;
    }
    state = state.copyWith(selectedTagIds: <int>{});
  }
}

/// 筛选状态 provider。
final diaryFilterProvider =
    NotifierProvider<DiaryFilterNotifier, DiaryFilterState>(
      DiaryFilterNotifier.new,
    );

/// 分页/搜索查询实例在无人监听后的保留时长。
///
/// 两个查询 family 以（关键词、标签、窗口大小、排序）为 key：每次翻页、切换
/// 标签、输入搜索词都会产生新实例。实例此前永不释放，每个都常驻一份完整
/// 结果列表（含正文），用得越久内存只增不减。现在无人监听超过该时长才释放：
/// 短时间内来回切换（取消再勾回同一标签、从搜索返回）仍直接命中缓存，首帧
/// 不必等待重新查询；更早的查询不再常驻。
const Duration diaryQueryIdleRetention = queryIdleRetention;

/// 日记列表分页流 provider。
///
/// 列表页只订阅当前可见窗口大小，数据库层通过 `LIMIT` 直接返回窗口内数据，
/// 不再把全量命中结果交给 UI 层 `take()` 截断。
final pagedDiariesProvider = StreamProvider.autoDispose
    .family<PagedDiariesResult, DiaryPageQuery>((
      Ref ref,
      DiaryPageQuery query,
    ) {
      retainQueryWhileRecentlyUsed(ref);
      final db = ref.watch(appDatabaseProvider);
      final fetchLimit = query.limit + 1;
      return db
          .watchDiaries(
            keyword: query.keyword,
            requiredTagIds: query.requiredTagIds,
            limit: fetchLimit,
            sortMode: query.sortMode,
            scope: query.scope,
          )
          .map((items) {
            final hasMore = items.length > query.limit;
            return PagedDiariesResult(
              items: hasMore
                  ? items.take(query.limit).toList(growable: false)
                  : items,
              limit: query.limit,
              hasMore: hasMore,
            );
          });
    });

/// 日记页首屏窗口大小：日记页的初始窗口与启动预热共用，保证命中同一个查询。
const int diaryFirstPageSize = 20;

/// 启动预热：订阅日记页首帧将要使用的同一条分页查询（空筛选 + 持久化排序 +
/// 首屏窗口）。
///
/// 门控放行时日记页首帧直接命中这个已就绪的 provider 实例，列表随首页一起
/// 出现。此前预热的是另一条查询（默认排序、不多取一条判断 hasMore），结果被
/// 直接丢弃，首页还要再查一次并先闪加载指示再硬切成列表。
/// 只依赖设置服务（加载后实例稳定）：之后的筛选、排序变化不会让它切换到
/// 新实例，门控一旦放行就保持放行；仍开启标签记忆的用户首帧后会再换一次查询。
/// 范围固定为全部日记：应用总是从“全部日记”启动。
final startupDiariesProvider = Provider<AsyncValue<PagedDiariesResult>>((
  Ref ref,
) {
  final settings = ref.watch(settingsServiceProvider).asData?.value;
  if (settings == null) {
    return const AsyncValue<PagedDiariesResult>.loading();
  }
  final sortMode = DiaryViewPreferences.fromRaw(
    sortRaw: settings.diarySortModeRaw,
    layoutRaw: settings.diaryLayoutModeRaw,
  ).sortMode;
  return ref.watch(
    pagedDiariesProvider(
      DiaryPageQuery(
        keyword: '',
        requiredTagIds: const <int>[],
        limit: diaryFirstPageSize,
        sortMode: sortMode,
      ),
    ),
  );
});

/// 搜索页查询参数。
///
/// 约束：
/// - `keyword` 会在构造时自动 trim；
/// - `requiredTagIds` 会去重并排序，保证 provider family key 稳定。
class SearchDiaryQuery {
  SearchDiaryQuery({
    String keyword = '',
    Iterable<int> requiredTagIds = const <int>[],
    this.scope = DiaryListScope.all,
  }) : keyword = keyword.trim(),
       requiredTagIds = _normalizeTagIds(requiredTagIds);

  final String keyword;
  final List<int> requiredTagIds;

  /// 搜索范围：在日记本里搜索时只搜这本（私密规则同列表）。
  final DiaryListScope scope;

  bool get hasAnyCondition => keyword.isNotEmpty || requiredTagIds.isNotEmpty;

  static List<int> _normalizeTagIds(Iterable<int> source) {
    final normalized = source.toSet().toList(growable: false)..sort();
    return normalized;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SearchDiaryQuery) {
      return false;
    }
    if (keyword != other.keyword ||
        scope != other.scope ||
        requiredTagIds.length != other.requiredTagIds.length) {
      return false;
    }
    for (var index = 0; index < requiredTagIds.length; index += 1) {
      if (requiredTagIds[index] != other.requiredTagIds[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(keyword, scope, Object.hashAll(requiredTagIds));
}

/// 搜索页独立数据源（关键词 + 标签条件）。
///
/// 设计目的：
/// - 与主页 `diaryFilterProvider` 解耦，避免搜索页对主页筛选状态产生副作用；
/// - 支持搜索页内部以局部状态驱动联合查询。
final searchDiariesProvider = StreamProvider.autoDispose
    .family<PagedDiariesResult, DiaryPageQuery>((
      Ref ref,
      DiaryPageQuery query,
    ) {
      retainQueryWhileRecentlyUsed(ref);
      final db = ref.watch(appDatabaseProvider);
      final fetchLimit = query.limit + 1;
      return db
          .watchDiaries(
            keyword: query.keyword,
            requiredTagIds: query.requiredTagIds,
            limit: fetchLimit,
            sortMode: query.sortMode,
            scope: query.scope,
          )
          .map((items) {
            final hasMore = items.length > query.limit;
            return PagedDiariesResult(
              items: hasMore
                  ? items.take(query.limit).toList(growable: false)
                  : items,
              limit: query.limit,
              hasMore: hasMore,
            );
          });
    });
