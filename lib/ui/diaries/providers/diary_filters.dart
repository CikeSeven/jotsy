import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_view_preferences.dart';
import 'package:node_diary/ui/notebooks/models/notebook_scope_resolver.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_restore.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/utils/provider_retention.dart';

/// 列表筛选状态：关键词 + 选中的标签集合 + 标签栏是否处在多选模式。
class DiaryFilterState {
  const DiaryFilterState({
    this.keyword = '',
    this.selectedTagIds = const <int>{},
    this.multiSelect = false,
  });

  final String keyword;
  final Set<int> selectedTagIds;

  /// 首页标签栏是否已由长按进入多选模式（见 [isMultiSelect]）。
  final bool multiSelect;

  /// 是否处在多选模式：长按进入、点 ✕ 退出；选中两个以上（如恢复记住的
  /// 筛选）时一定是多选。多选模式下单击标签增减、不丢掉已选的，单选模式
  /// 下单击只选这一个。
  bool get isMultiSelect => multiSelect || selectedTagIds.length > 1;

  /// 生成新的筛选状态副本，保持不可变数据流。
  DiaryFilterState copyWith({
    String? keyword,
    Set<int>? selectedTagIds,
    bool? multiSelect,
  }) {
    return DiaryFilterState(
      keyword: keyword ?? this.keyword,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      multiSelect: multiSelect ?? this.multiSelect,
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
    this.matchComments = false,
    this.includeArchived = false,
    this.filter,
  });

  final String keyword;
  final List<int> requiredTagIds;
  final int limit;
  final DiarySortMode sortMode;

  /// 是否连归档的日记一起查：只有搜索页勾选“含归档”时为 true。
  final bool includeArchived;

  /// 搜索页的筛选谓词（由 `DiarySearchFilters` 经智能日记本规则编译），
  /// null 即不筛选。谓词实现了值相等，同一组筛选重建出的查询命中同一个
  /// provider 实例。
  final DiaryScopePredicate? filter;

  /// 关键词是否也匹配留言：只有搜索页在开启留言功能时为 true，参与相等
  /// 比较（开关一变即换一个 provider 实例）。
  final bool matchComments;

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
          matchComments: matchComments,
          includeArchived: includeArchived,
          filter: filter,
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
        matchComments != other.matchComments ||
        includeArchived != other.includeArchived ||
        filter != other.filter ||
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
    matchComments,
    includeArchived,
    filter,
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

  /// 单个标签开关，保留其余已选的标签（多选：同时带有这些标签才匹配），
  /// 并进入多选模式。
  void toggleTag(int tagId, bool selected) {
    final next = <int>{...state.selectedTagIds};
    if (selected) {
      next.add(tagId);
    } else {
      next.remove(tagId);
    }
    state = state.copyWith(selectedTagIds: next, multiSelect: true);
  }

  /// 进入多选模式，已选的标签不变（单选模式下长按已选中的那一个）。
  void enterMultiSelect() {
    if (state.isMultiSelect) {
      return;
    }
    state = state.copyWith(multiSelect: true);
  }

  /// 单选模式下单击标签：只选这一个（#196），它已是唯一选中的标签时取消
  /// 选择。多选模式下的单击走 [toggleTag]（由 `DiariesPageController` 按
  /// [DiaryFilterState.isMultiSelect] 分流）。
  void selectOnlyTag(int tagId) {
    final current = state.selectedTagIds;
    final onlyThis = current.length == 1 && current.contains(tagId);
    state = state.copyWith(
      selectedTagIds: onlyThis ? <int>{} : <int>{tagId},
      multiSelect: false,
    );
  }

  /// 批量替换标签筛选，用于从设置中的“标签记忆”恢复状态、切换日记本时
  /// 换回各自的选择。模式按数量推断：两个以上为多选，否则回到单选。
  void setTags(Iterable<int> tagIds) {
    final normalized = <int>{
      for (final tagId in tagIds)
        if (tagId > 0) tagId,
    };
    state = state.copyWith(
      selectedTagIds: normalized,
      multiSelect: normalized.length > 1,
    );
  }

  /// 清空标签筛选（保留关键词）并回到单选模式（标签栏的 ✕）。
  void clearTags() {
    if (state.selectedTagIds.isEmpty && !state.multiSelect) {
      return;
    }
    state = state.copyWith(selectedTagIds: <int>{}, multiSelect: false);
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
      var retainedBytes = 0;
      final checkBudget = retainQueryWhileRecentlyUsed(
        ref,
        estimatedBytes: () => retainedBytes,
      );
      final db = ref.watch(appDatabaseProvider);
      final fetchLimit = query.limit + 1;
      return db
          .watchDiaries(
            keyword: query.keyword,
            requiredTagIds: query.requiredTagIds,
            limit: fetchLimit,
            sortMode: query.sortMode,
            scope: query.scope,
            matchComments: query.matchComments,
          )
          .map((items) {
            // family 的多个分页窗口会短暂并存；除了 30 秒时限，也限制闲置
            // 窗口合计的文本。按 UTF-16 两字节和每行/标签的固定开销估计，
            // 不把活动窗口算进来，更不为省内存截断用户当前看到的正文。
            retainedBytes = items.fold(0, (total, item) {
              final diary = item.diary;
              return total +
                  256 +
                  2 *
                      (diary.title.length +
                          diary.content.length +
                          diary.contentText.length +
                          diary.metadata.length +
                          (diary.cover?.length ?? 0) +
                          item.tags.fold(
                            0,
                            (units, tag) => units + tag.name.length + 32,
                          ));
            });
            checkBudget();
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
/// 只依赖设置服务与启动时恢复的首页范围（两者都只在启动时变化一次）：之后
/// 的筛选、排序、范围变化不会让它切换到新实例，门控一旦放行就保持放行；仍
/// 开启标签记忆的用户首帧后会再换一次查询。
///
/// 范围取 `homeNotebookScopeRestoreProvider`（上次所在的日记本 / 章节 /
/// 未收录，本子里按本子的排序）。恢复到某本日记本时还要等书架流
/// `notebooksProvider` 第一次到达：日记页按它解析范围，书架没到时会先按
/// “什么都不匹配”查询、闪一下空列表。
final startupDiariesProvider = Provider<AsyncValue<PagedDiariesResult>>((
  Ref ref,
) {
  final settings = ref.watch(settingsServiceProvider).asData?.value;
  final restored = ref.watch(homeNotebookScopeRestoreProvider).value;
  if (settings == null || restored == null) {
    return const AsyncValue<PagedDiariesResult>.loading();
  }
  if (restored.state.notebookId != null &&
      !ref.watch(
        notebooksProvider.select((async) => async.hasValue || async.hasError),
      )) {
    return const AsyncValue<PagedDiariesResult>.loading();
  }
  final notebookSort = restored.sort;
  final sortMode = notebookSort == null
      ? DiaryViewPreferences.fromRaw(
          sortRaw: settings.diarySortModeRaw,
          layoutRaw: settings.diaryLayoutModeRaw,
        ).sortMode
      : diarySortModeForNotebook(notebookSort);
  return ref.watch(
    pagedDiariesProvider(
      DiaryPageQuery(
        keyword: '',
        requiredTagIds: const <int>[],
        limit: diaryFirstPageSize,
        sortMode: sortMode,
        scope: restored.scope,
      ),
    ),
  );
});

/// 搜索页独立数据源（关键词 + 标签 + 筛选 + 范围）。
///
/// 设计目的：
/// - 与主页 `diaryFilterProvider` 解耦，避免搜索页对主页筛选状态产生副作用；
/// - 支持搜索页内部以局部状态驱动联合查询（日记本“添加日记”页同样使用）。
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
            matchComments: query.matchComments,
            includeArchived: query.includeArchived,
            filter: query.filter,
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

/// 搜索结果的总篇数（“共 N 篇”）：与 [searchDiariesProvider] 同一筛选与范围，
/// key 为不随翻页变化的 [DiaryPageQuery.timelineKey]，加载更多不会重查计数。
final searchDiaryCountProvider = StreamProvider.autoDispose
    .family<int, DiaryPageQuery>((Ref ref, DiaryPageQuery query) {
      retainQueryWhileRecentlyUsed(ref);
      final db = ref.watch(appDatabaseProvider);
      return db.watchActiveDiaryCount(
        keyword: query.keyword,
        requiredTagIds: query.requiredTagIds,
        scope: query.scope,
        matchComments: query.matchComments,
        includeArchived: query.includeArchived,
        filter: query.filter,
      );
    });
