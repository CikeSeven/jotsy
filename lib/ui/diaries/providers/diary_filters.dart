import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';

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
  });

  final String keyword;
  final List<int> requiredTagIds;
  final int limit;
  final DiaryQuerySortMode sortMode;

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
      Object.hash(keyword, limit, sortMode, Object.hashAll(requiredTagIds));
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

/// 日记列表分页流 provider。
///
/// 列表页只订阅当前可见窗口大小，数据库层通过 `LIMIT` 直接返回窗口内数据，
/// 不再把全量命中结果交给 UI 层 `take()` 截断。
final pagedDiariesProvider = StreamProvider.family<
  PagedDiariesResult,
  DiaryPageQuery
>((Ref ref, DiaryPageQuery query) {
  final db = ref.watch(appDatabaseProvider);
  final fetchLimit = query.limit + 1;
  return db
      .watchDiaries(
        keyword: query.keyword,
        requiredTagIds: query.requiredTagIds,
        limit: fetchLimit,
        sortMode: query.sortMode,
      )
      .map((items) {
        final hasMore = items.length > query.limit;
        return PagedDiariesResult(
          items:
              hasMore ? items.take(query.limit).toList(growable: false) : items,
          limit: query.limit,
          hasMore: hasMore,
        );
      });
});

/// 启动预热仍只取首页窗口，避免恢复旧的全量启动查询。
final filteredDiariesProvider = StreamProvider<List<DiaryWithTags>>((Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final filter = ref.watch(diaryFilterProvider);
  final tagIds = filter.selectedTagIds.toList()..sort();
  return db.watchDiaries(
    keyword: filter.keyword,
    requiredTagIds: tagIds,
    limit: 20,
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
  }) : keyword = keyword.trim(),
       requiredTagIds = _normalizeTagIds(requiredTagIds);

  final String keyword;
  final List<int> requiredTagIds;

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
  int get hashCode => Object.hash(keyword, Object.hashAll(requiredTagIds));
}

/// 搜索页独立数据源（关键词 + 标签条件）。
///
/// 设计目的：
/// - 与主页 `diaryFilterProvider` 解耦，避免搜索页对主页筛选状态产生副作用；
/// - 支持搜索页内部以局部状态驱动联合查询。
final searchDiariesProvider = StreamProvider.family<
  PagedDiariesResult,
  DiaryPageQuery
>((Ref ref, DiaryPageQuery query) {
  final db = ref.watch(appDatabaseProvider);
  final fetchLimit = query.limit + 1;
  return db
      .watchDiaries(
        keyword: query.keyword,
        requiredTagIds: query.requiredTagIds,
        limit: fetchLimit,
        sortMode: query.sortMode,
      )
      .map((items) {
        final hasMore = items.length > query.limit;
        return PagedDiariesResult(
          items:
              hasMore ? items.take(query.limit).toList(growable: false) : items,
          limit: query.limit,
          hasMore: hasMore,
        );
      });
});
