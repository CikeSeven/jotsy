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

/// 日记列表流 provider。
///
/// 基于当前筛选状态实时监听数据库结果。
final filteredDiariesProvider = StreamProvider<List<DiaryWithTags>>((Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final filter = ref.watch(diaryFilterProvider);
  final tagIds = filter.selectedTagIds.toList()..sort();
  return db.watchDiaries(keyword: filter.keyword, requiredTagIds: tagIds);
});

/// 搜索页独立数据源（仅关键词，不叠加标签筛选）。
///
/// 设计目的：
/// - 与主页 `diaryFilterProvider` 解耦，避免搜索页对主页筛选状态产生副作用；
/// - 支持搜索页内部以局部状态驱动实时查询。
final searchDiariesProvider = StreamProvider.family<List<DiaryWithTags>, String>((
  Ref ref,
  String keyword,
) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchDiaries(keyword: keyword.trim());
});
