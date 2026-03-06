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

  void setKeyword(String value) {
    state = state.copyWith(keyword: value);
  }

  void toggleTag(int tagId, bool selected) {
    final next = <int>{...state.selectedTagIds};
    if (selected) {
      next.add(tagId);
    } else {
      next.remove(tagId);
    }
    state = state.copyWith(selectedTagIds: next);
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
