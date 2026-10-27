import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/providers/diary_filters.dart';
import '../models/notebook_scope_resolver.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_providers.dart';

/// 首页“日记”页当前所在的范围：全部日记、未收录的日记（[unfiled]），或某本
/// 日记本（含章节选择）。
///
/// 只在内存里：应用总是从“全部日记”启动（启动预热 `startupDiariesProvider`
/// 也固定为全部日记）。
///
/// - [chapterId] / [unassignedChapterOnly]：章节筛选（章节界面接入前恒为空）；
/// - [sortOverride]：在视图选项里改了本子的排序、写库结果还没推送回来时
///   先按它显示（见 [HomeNotebookScopeNotifier.setSortOverride]）；
/// - [relocked]：上锁日记本的验证会话因切到后台而失效，需要重新验证
///   （`NotebookLockLayer` 盖住整个应用）。
@immutable
class HomeNotebookScope {
  const HomeNotebookScope({
    this.notebookId,
    this.unfiled = false,
    this.chapterId,
    this.unassignedChapterOnly = false,
    this.sortOverride,
    this.relocked = false,
  });

  static const HomeNotebookScope all = HomeNotebookScope();

  /// 未收录：没有收进任何日记本的日记（书架“全部日记”下面那一项）。
  static const HomeNotebookScope unfiledScope = HomeNotebookScope(
    unfiled: true,
  );

  /// [key] 里代表“未收录”的值；日记本的业务 id 是 UUID，不会与它相同。
  static const String unfiledKey = ':unfiled';

  final String? notebookId;

  /// 在“未收录”里（此时 [notebookId] 为 null）。
  final bool unfiled;
  final String? chapterId;
  final bool unassignedChapterOnly;
  final NotebookSort? sortOverride;
  final bool relocked;

  bool get isAll => notebookId == null && !unfiled;

  /// 范围的身份：日记本 id、[unfiledKey] 或 null（全部日记）。日记页按它
  /// 判断“换了范围”（过渡、退出多选、外部切换时关掉上层页面）。
  String? get key => notebookId ?? (unfiled ? unfiledKey : null);

  HomeNotebookScope _copyWith({
    ValueGetter<String?>? chapterId,
    bool? unassignedChapterOnly,
    ValueGetter<NotebookSort?>? sortOverride,
    bool? relocked,
  }) {
    return HomeNotebookScope(
      notebookId: notebookId,
      unfiled: unfiled,
      chapterId: chapterId == null ? this.chapterId : chapterId(),
      unassignedChapterOnly:
          unassignedChapterOnly ?? this.unassignedChapterOnly,
      sortOverride: sortOverride == null ? this.sortOverride : sortOverride(),
      relocked: relocked ?? this.relocked,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeNotebookScope &&
      other.notebookId == notebookId &&
      other.unfiled == unfiled &&
      other.chapterId == chapterId &&
      other.unassignedChapterOnly == unassignedChapterOnly &&
      other.sortOverride == sortOverride &&
      other.relocked == relocked;

  @override
  int get hashCode => Object.hash(
    notebookId,
    unfiled,
    chapterId,
    unassignedChapterOnly,
    sortOverride,
    relocked,
  );
}

/// 首页范围的状态与切换。
///
/// 标签筛选按范围分开记：从全部日记进入日记本时先记下全部日记的已选标签，
/// 本子里从空选择开始；回到全部日记时还原（“记住标签筛选”只记全部日记的
/// 选择，见日记页控制器）。切换本身不做过渡动画，由日记页经过渡协调器调用。
class HomeNotebookScopeNotifier extends Notifier<HomeNotebookScope> {
  Set<int> _allScopeTagIds = const <int>{};

  @override
  HomeNotebookScope build() => HomeNotebookScope.all;

  /// 进入 [notebookId]（已在其中时不变）。上锁日记本须由调用方先验证。
  void enter(String notebookId) {
    if (state.notebookId == notebookId) {
      return;
    }
    final filter = ref.read(diaryFilterProvider.notifier);
    if (state.isAll) {
      _allScopeTagIds = <int>{...ref.read(diaryFilterProvider).selectedTagIds};
    }
    state = HomeNotebookScope(notebookId: notebookId);
    filter.setTags(const <int>[]);
  }

  /// 进入“未收录”（已在其中时不变）；标签筛选与进入日记本同理。
  void showUnfiled() {
    if (state.unfiled) {
      return;
    }
    final filter = ref.read(diaryFilterProvider.notifier);
    if (state.isAll) {
      _allScopeTagIds = <int>{...ref.read(diaryFilterProvider).selectedTagIds};
    }
    state = HomeNotebookScope.unfiledScope;
    filter.setTags(const <int>[]);
  }

  /// 回到全部日记，还原离开时的标签筛选。
  void showAll() {
    if (state.isAll) {
      return;
    }
    state = HomeNotebookScope.all;
    ref.read(diaryFilterProvider.notifier).setTags(_allScopeTagIds);
    _allScopeTagIds = const <int>{};
  }

  /// 章节筛选（章节界面使用）；全部日记与未收录里无效。
  void selectChapter({String? chapterId, bool unassignedOnly = false}) {
    if (state.notebookId == null) {
      return;
    }
    state = state._copyWith(
      chapterId: () => chapterId,
      unassignedChapterOnly: chapterId == null && unassignedOnly,
    );
  }

  /// 视图选项里改了本子的排序：写库结果推送回来之前先按 [sort] 显示，列表
  /// 过渡等到的就是新排序的数据。推送回来后（或写入失败时）经
  /// [clearSortOverride] 清除，之后在编辑页改排序不会被它挡住。
  void setSortOverride(NotebookSort sort) {
    if (state.notebookId == null) {
      return;
    }
    state = state._copyWith(sortOverride: () => sort);
  }

  void clearSortOverride() {
    if (state.sortOverride == null) {
      return;
    }
    state = state._copyWith(sortOverride: () => null);
  }

  /// 应用切到后台时让上锁日记本的验证会话失效。
  void relock() {
    if (state.notebookId == null || state.relocked) {
      return;
    }
    state = state._copyWith(relocked: true);
  }

  /// 重新验证通过。
  void unlock() {
    if (!state.relocked) {
      return;
    }
    state = state._copyWith(relocked: false);
  }
}

final homeNotebookScopeProvider =
    NotifierProvider<HomeNotebookScopeNotifier, HomeNotebookScope>(
      HomeNotebookScopeNotifier.new,
    );

/// 首页范围解析结果：当前日记本（全部日记与未收录时为 null）、查询范围与
/// 本子的生效排序。
///
/// [missing]：书架已加载但找不到当前日记本（已删除或已并入别的本子），
/// 日记页据此回到全部日记并提示。
@immutable
class HomeNotebookScopeResolution {
  const HomeNotebookScopeResolution({
    required this.state,
    required this.scope,
    this.notebook,
    this.sort,
    this.missing = false,
  });

  static const HomeNotebookScopeResolution all = HomeNotebookScopeResolution(
    state: HomeNotebookScope.all,
    scope: DiaryListScope.all,
  );

  final HomeNotebookScope state;
  final NotebookView? notebook;
  final DiaryListScope scope;

  /// 本子里的列表排序；全部日记时为 null（用全局排序偏好）。
  final NotebookSort? sort;
  final bool missing;

  bool get isAll => state.isAll;

  /// 在“未收录”里。
  bool get isUnfiled => state.unfiled;

  @override
  bool operator ==(Object other) =>
      other is HomeNotebookScopeResolution &&
      other.state == state &&
      other.notebook == notebook &&
      other.scope == scope &&
      other.sort == sort &&
      other.missing == missing;

  @override
  int get hashCode => Object.hash(state, notebook, scope, sort, missing);
}

/// 什么都不匹配的范围：书架还没加载（理论上不会发生，进入日记本必经书架）
/// 或本子已不存在时用它，绝不回落成全部日记或别的范围。
DiaryListScope _matchNothingScope(String notebookId) => DiarySmartScope(
  notebookId: notebookId,
  predicate: const DiaryScopePredicate(sql: '0'),
);

/// 当前范围的解析：全部日记与未收录时不订阅书架（未收录用全局排序偏好）。
final homeNotebookScopeResolutionProvider =
    Provider<HomeNotebookScopeResolution>((Ref ref) {
      final state = ref.watch(homeNotebookScopeProvider);
      if (state.unfiled) {
        return HomeNotebookScopeResolution(
          state: state,
          scope: DiaryListScope.unfiled,
        );
      }
      final notebookId = state.notebookId;
      if (notebookId == null) {
        return HomeNotebookScopeResolution.all;
      }
      final tree = ref.watch(notebookTreeProvider);
      final notebook = tree?[notebookId];
      if (notebook == null) {
        return HomeNotebookScopeResolution(
          state: state,
          scope: _matchNothingScope(notebookId),
          missing: tree != null,
        );
      }
      final sort = effectiveNotebookSort(
        notebook,
        state.sortOverride ?? notebook.payload.sort,
      );
      return HomeNotebookScopeResolution(
        state: state,
        notebook: notebook,
        sort: sort,
        scope: resolveNotebookScope(
          notebook,
          tree: tree,
          sort: sort,
          chapterId: state.chapterId,
          unassignedChapterOnly: state.unassignedChapterOnly,
        ),
      );
    });

/// 书架上是否有日记本：首页标签栏在没有标签时是否仍要显示（给日记本切换
/// 入口留位置）。
final hasNotebooksProvider = Provider<bool>(
  (Ref ref) => ref.watch(notebooksProvider).value?.isNotEmpty ?? false,
);

/// 某个范围内（未删除、未归档）日记用到的标签 id：日记本里的标签栏只列这些。
final scopeTagIdsProvider = StreamProvider.autoDispose
    .family<Set<int>, DiaryListScope>(
      (Ref ref, DiaryListScope scope) =>
          ref.watch(appDatabaseProvider).watchTagIdsUsedInScope(scope),
    );
