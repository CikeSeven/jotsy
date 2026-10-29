import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../controllers/notebooks_controller.dart';
import '../models/notebook_scope_resolver.dart';
import '../viewmodels/notebook_tree.dart';
import '../viewmodels/notebook_view.dart';

/// 书架上的全部日记本（置顶在前，再按手动顺序），实时跟随数据库。
///
/// 每行在这里解析一次成 [NotebookView]（经 [NotebookTree]，带好上级、层数
/// 与生效可见性），组件不再自己解码 payload。
final notebooksProvider = StreamProvider<List<NotebookView>>((Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return database.watchNotebooks().map((rows) => NotebookTree(rows).notebooks);
});

/// 书架的嵌套结构；书架还没加载时为 null。由 [notebooksProvider] 现算
/// （几十行，重建很便宜），测试只需覆盖书架列表。
final notebookTreeProvider = Provider<NotebookTree?>((Ref ref) {
  final notebooks = ref.watch(notebooksProvider).value;
  return notebooks == null ? null : NotebookTree.fromViews(notebooks);
});

/// 普通日记本 id → 篇数（不算回收站与归档）。没有日记的本子不在表里，读取方
/// 按 0 处理；智能日记本与有子本的日记本的篇数现算，见
/// [computedNotebookCountProvider]。
final notebookEntryCountsProvider = StreamProvider<Map<String, int>>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchManualNotebookEntryCounts();
});

/// 智能日记本按规则、有子本的普通日记本连同子本现算的篇数（未删除、未归档，
/// 私密规则与列表相同），口径与首页在这本里的列表一致（同一个
/// [notebookStatsScope]）。
///
/// 只 select 这本的范围：书架流因别的本子改名、排序推送时，范围相等就不重新
/// 订阅计数查询；改了规则或子本才换查询。既不是智能本也没有子本、或已删除时
/// 保持加载中（调用方只对这两种读取）。
final computedNotebookCountProvider = StreamProvider.autoDispose
    .family<int, String>((Ref ref, String notebookId) {
      final scope = ref.watch(
        notebookTreeProvider.select((NotebookTree? tree) {
          final notebook = tree?[notebookId];
          if (notebook == null || !(notebook.isSmart || notebook.hasChildren)) {
            return null;
          }
          return notebookStatsScope(notebook, tree: tree);
        }),
      );
      if (scope == null) return const Stream<int>.empty();
      return ref.watch(appDatabaseProvider).watchScopedDiaryCount(scope);
    });

/// 书架、管理页等列表上显示的篇数：普通日记本取 [counts]（来自
/// [notebookEntryCountsProvider]），智能日记本与有子本的日记本取
/// [computedNotebookCountProvider]（计算出来之前为 null，不显示篇数）。须在
/// build 期间调用。
int? watchNotebookDisplayCount(
  WidgetRef ref,
  NotebookView notebook,
  Map<String, int> counts,
) {
  if (notebook.isSmart || notebook.hasChildren) {
    return ref.watch(computedNotebookCountProvider(notebook.id)).value;
  }
  return notebook.isManual ? counts[notebook.id] ?? 0 : null;
}

/// 单个日记本（带层级信息，取自书架列表），不存在（已删除）时为 null。
final notebookProvider = Provider.autoDispose
    .family<AsyncValue<NotebookView?>, String>(
      (Ref ref, String notebookId) =>
          ref.watch(notebooksProvider).whenData((notebooks) {
            for (final notebook in notebooks) {
              if (notebook.id == notebookId) return notebook;
            }
            return null;
          }),
    );

/// 书架与管理页共用的日记本操作（置顶、合上、排序、删除与撤销、合并）。
final notebooksControllerProvider = Provider<NotebooksController>(
  (Ref ref) => NotebooksController(ref.watch(appDatabaseProvider)),
);

/// 范围内（未删除、未归档）的篇数：日记本头部卡片的篇数，与首页列表一致。
final notebookScopeCountProvider = StreamProvider.autoDispose
    .family<int, DiaryListScope>(
      (Ref ref, DiaryListScope scope) =>
          ref.watch(appDatabaseProvider).watchScopedDiaryCount(scope),
    );

/// 范围内未归档日记的轻量概览（不含富文本正文与未解封的胶囊）：头部卡片
/// 统计字数与时间跨度。
final notebookScopeOverviewsProvider = StreamProvider.autoDispose
    .family<List<ExploreDiaryOverview>, DiaryListScope>(
      (Ref ref, DiaryListScope scope) => ref
          .watch(appDatabaseProvider)
          .watchExploreDiaryOverviews(scope: scope, includeArchived: false),
    );

/// 私密日记（在隐藏 / 上锁的普通日记本里）的业务 id，含回收站里的：回收站与
/// 纪念日据此把它们显示为占位，而不是“已删除”。
final privateDiaryIdsProvider = StreamProvider.autoDispose<Set<String>>(
  (Ref ref) => ref.watch(appDatabaseProvider).watchPrivateDiaryIds(),
);

/// 包含这篇日记的普通日记本（按书架顺序）：预览页的日记本胶囊与“收进日记本”
/// 的说明。
///
/// 一次性读取而不是订阅：这条查询连着日记表，订阅会在每次写日记（预览页
/// 勾选待办）时重查。改动收录的地方（预览页“收进日记本”）写完后
/// invalidate；预览页每次打开都重新读取。
final diaryNotebooksProvider = FutureProvider.autoDispose
    .family<List<NotebookView>, String>((Ref ref, String diaryId) async {
      final rows = await ref
          .watch(appDatabaseProvider)
          .getNotebooksOfDiary(diaryId);
      return List<NotebookView>.unmodifiable(rows.map(NotebookView.new));
    });

/// 普通日记本里每篇日记（首页列表口径）的章节：章节胶囊的篇数与书序分隔行
/// 由它派生（见 `NotebookChapterCounts`）。
final notebookEntryChaptersProvider = StreamProvider.autoDispose
    .family<Map<String, String?>, String>(
      (Ref ref, String notebookId) =>
          ref.watch(appDatabaseProvider).watchNotebookEntryChapters(notebookId),
    );

/// 目录页的日记行（含归档），按成书位置排好。
final notebookContentsProvider = StreamProvider.autoDispose
    .family<List<NotebookContentsEntry>, String>(
      (Ref ref, String notebookId) =>
          ref.watch(appDatabaseProvider).watchNotebookContents(notebookId),
    );

/// 管理页里收起了子本的日记本（业务 id）。
///
/// 只在内存里：本次运行期间离开管理页再回来仍保持，重启应用后全部展开，
/// 不加设置键。已删除的本子留在集合里无害（没有行认它）。
final notebookManageCollapsedProvider =
    NotifierProvider<NotebookManageCollapsedNotifier, Set<String>>(
      NotebookManageCollapsedNotifier.new,
    );

class NotebookManageCollapsedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// 收起或展开 [id] 下面的子本。
  void toggle(String id) => state = state.contains(id)
      ? Set<String>.unmodifiable(state.difference(<String>{id}))
      : Set<String>.unmodifiable(<String>{...state, id});

  /// 全部收起：收起 [ids]（有子本的本子），其余保持。
  void collapseAll(Iterable<String> ids) =>
      state = Set<String>.unmodifiable(<String>{...state, ...ids});

  /// 展开 [ids]；全部展开时传 null。
  void expand([Iterable<String>? ids]) {
    if (ids == null) {
      if (state.isNotEmpty) state = const <String>{};
      return;
    }
    final next = state.difference(ids.toSet());
    if (next.length != state.length) state = Set<String>.unmodifiable(next);
  }
}

/// 首页日记本头部展开了全部子本的日记本（业务 id），见 `NotebookChildrenGrid`。
///
/// 只在内存里：本次运行期间进了子本再回到上级仍保持展开，重启应用后全部
/// 折叠，不加设置键。
final notebookChildrenExpandedProvider =
    NotifierProvider<NotebookChildrenExpandedNotifier, Set<String>>(
      NotebookChildrenExpandedNotifier.new,
    );

class NotebookChildrenExpandedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// 展开或收起 [id] 的子本网格。
  void toggle(String id) => state = state.contains(id)
      ? Set<String>.unmodifiable(state.difference(<String>{id}))
      : Set<String>.unmodifiable(<String>{...state, id});
}
