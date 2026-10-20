// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 日记页的日记本范围编排：书架切换、上锁验证、头部菜单、本子排序、
/// 日记本被删除后的回退与系统返回。
///
/// 职责边界：
/// - 范围状态在 `homeNotebookScopeProvider`，这里只决定何时、怎样切换；
/// - 页面发起的切换一律经过渡协调器（旧列表淡出 → 新范围数据到齐 → 回到
///   顶部淡入），并退出多选；
/// - 别处改了范围（上锁遮罩“回到全部日记”）时由 [handleScopeIdChanged]
///   补上同样的过渡；
/// - 不构建 UI（书架面板、确认框由各自的 flow 负责）。
class DiariesNotebookScopeController {
  DiariesNotebookScopeController(
    this._state, {
    required this.feedback,
    required this.transitionCoordinator,
  });

  final _DiariesPage _state;
  final DiariesPageFeedback feedback;
  final DiaryListTransitionCoordinator transitionCoordinator;

  /// 页面自己最近一次切到的日记本 id（null 为全部日记）：范围变化与它一致
  /// 说明是页面发起的，否则是外部改的，需要补过渡。
  String? _expectedNotebookId;

  HomeNotebookScopeNotifier get _notifier =>
      _state.ref.read(homeNotebookScopeProvider.notifier);

  HomeNotebookScopeResolution get resolution =>
      _state.ref.read(homeNotebookScopeResolutionProvider);

  /// 打开书架面板，按选择切换范围（上锁的先验证）。
  Future<void> openShelf() async {
    final current = _state.ref.read(homeNotebookScopeProvider).notebookId;
    final result = await showNotebookShelfSheet(
      _state.context,
      currentNotebookId: current,
    );
    if (!_state.mounted || result == null) {
      return;
    }
    switch (result) {
      case NotebookShelfSelectAll():
        showAll();
      case NotebookShelfSelectNotebook(:final notebookId):
        await enter(notebookId);
    }
  }

  /// 进入日记本：上锁的先验证，未通过（取消、失败、设备不支持）停留原处。
  Future<void> enter(String notebookId) async {
    if (_state.ref.read(homeNotebookScopeProvider).notebookId == notebookId) {
      return;
    }
    final notebooks =
        _state.ref.read(notebooksProvider).value ?? const <NotebookView>[];
    NotebookView? notebook;
    for (final candidate in notebooks) {
      if (candidate.id == notebookId) {
        notebook = candidate;
        break;
      }
    }
    if (notebook == null) {
      return;
    }
    final allowed = await authorizeNotebookEntry(
      _state.context,
      _state.ref,
      notebook,
    );
    if (!allowed || !_state.mounted) {
      return;
    }
    _switchScope(notebookId, () => _notifier.enter(notebookId));
  }

  /// 回到全部日记（已在全部日记时不变）。
  void showAll() {
    if (_state.ref.read(homeNotebookScopeProvider).isAll) {
      return;
    }
    _switchScope(null, _notifier.showAll);
  }

  /// 功能管理里关掉日记本时，首页若停在某本里就回到全部日记（日记本功能
  /// 关闭时隐藏入口，数据保留）。
  ///
  /// 此刻用户正在首页之上的设置页里，所以必须走页面自己的 [showAll]：它先
  /// 记下预期的范围，[handleScopeIdChanged] 便不会把它当成外部改动去
  /// `popUntil` 关掉设置页；范围本身回到全部日记，不经“本子不见了”的解析，
  /// 也就不会误报“日记本已删除”。新范围不带 relocked，重锁遮罩随之失效。
  /// 放到微任务里执行：监听回调里不直接改 provider。重新开启时不恢复原来的
  /// 本子（范围本就不跨重启记忆）。
  void handleFeatureToggled(bool enabled) {
    if (enabled) {
      return;
    }
    scheduleMicrotask(() {
      if (_state.mounted) {
        showAll();
      }
    });
  }

  void _switchScope(String? notebookId, VoidCallback mutation) {
    _expectedNotebookId = notebookId;
    if (_state._selectedDiaryIds.isNotEmpty) {
      _state.setState(_state._selectedDiaryIds.clear);
    }
    transitionCoordinator.queueFilterMutation(mutation, scrollToTop: true);
  }

  /// 范围的日记本 id 变了：不是页面发起的（上锁遮罩“回到全部日记”）时，
  /// 先关掉首页之上的所有页面（可能正开着这本里的日记），再同样退出多选、
  /// 冻结旧列表并回到顶部淡入。
  void handleScopeIdChanged(String? next) {
    if (next == _expectedNotebookId) {
      return;
    }
    _expectedNotebookId = next;
    Navigator.of(_state.context).popUntil((Route<dynamic> route) {
      return route.isFirst;
    });
    if (_state._selectedDiaryIds.isNotEmpty) {
      _state.setState(_state._selectedDiaryIds.clear);
    }
    transitionCoordinator.queueFilterMutation(() {}, scrollToTop: true);
  }

  /// 范围解析变化：
  /// - 当前日记本不见了（被删除或并入别的本子）→ 回到全部日记并提示；
  /// - 本子的排序已写回并推送回来 → 清除临时排序，之后在编辑页改排序不会
  ///   被它挡住。
  ///
  /// 在监听回调里不直接改 provider，放到微任务里执行。
  void handleResolutionChanged(
    HomeNotebookScopeResolution? previous,
    HomeNotebookScopeResolution next,
  ) {
    if (next.missing && !(previous?.missing ?? false)) {
      scheduleMicrotask(() {
        if (!_state.mounted) {
          return;
        }
        showAll();
        unawaited(
          feedback.showInfoSnackBar(_state.context.l10n.notebookScopeDeleted),
        );
      });
    }
    final override = next.state.sortOverride;
    final notebook = next.notebook;
    // 选着的章节被删了（目录页或编辑页），或本子已没有章节（“未分章”胶囊
    // 跟着整行消失）：回到全部章节，免得列表停在一个看不见的筛选上。
    if (notebook != null && _chapterSelectionStale(next.state, notebook)) {
      scheduleMicrotask(() {
        if (_state.mounted &&
            _chapterSelectionStale(resolution.state, notebook)) {
          selectChapter();
        }
      });
    }
    if (override != null &&
        notebook != null &&
        effectiveNotebookSort(notebook, notebook.payload.sort) == override) {
      scheduleMicrotask(() {
        if (_state.mounted) {
          _notifier.clearSortOverride();
        }
      });
    }
  }

  static bool _chapterSelectionStale(
    HomeNotebookScope state,
    NotebookView notebook,
  ) {
    final chapterId = state.chapterId;
    final chapters = notebook.payload.chapters;
    if (chapterId != null) {
      return !chapters.any((chapter) => chapter.id == chapterId);
    }
    return state.unassignedChapterOnly && chapters.isEmpty;
  }

  /// 头部章节胶囊：切换章节筛选（全部 / 某章 / 未分章），列表走筛选过渡；
  /// 不改排序，也不回到顶部（头部卡片仍在原处，胶囊就在手指下）。
  void selectChapter({String? chapterId, bool unassigned = false}) {
    final current = _state.ref.read(homeNotebookScopeProvider);
    if (current.isAll ||
        (current.chapterId == chapterId &&
            current.unassignedChapterOnly ==
                (chapterId == null && unassigned))) {
      return;
    }
    if (_state._selectedDiaryIds.isNotEmpty) {
      _state.setState(_state._selectedDiaryIds.clear);
    }
    transitionCoordinator.queueFilterMutation(
      () => _notifier.selectChapter(
        chapterId: chapterId,
        unassignedOnly: unassigned,
      ),
    );
  }

  /// 头部卡片“目录”：打开这本的目录页（只对普通日记本）。
  Future<void> openContents() async {
    final notebook = resolution.notebook;
    if (notebook == null || !notebook.isManual) {
      return;
    }
    await Navigator.of(
      _state.context,
    ).push(NotebookContentsPage.route(notebookId: notebook.id));
  }

  /// 头部卡片“统计”：打开这本的统计页（普通与智能日记本都有）。已在这本的
  /// 解锁范围里，不再验证。
  Future<void> openInsights() async {
    final notebook = resolution.notebook;
    if (notebook == null) {
      return;
    }
    await Navigator.of(
      _state.context,
    ).push(NotebookInsightsPage.route(notebookId: notebook.id));
  }

  /// 头部菜单“导出成书”：整本（含归档）按书序交给导出流程。已在这本的
  /// 解锁范围里，不再验证。
  Future<void> exportBook() async {
    final notebook = resolution.notebook;
    if (notebook == null) {
      return;
    }
    await exportNotebookAsBook(_state.context, _state.ref, notebook);
  }

  /// 视图选项里改本子的排序：先按新排序过渡显示，再写回本子；写入失败时
  /// 退回原排序并提示。
  void changeNotebookSort(NotebookSort sort) {
    final current = resolution;
    final notebook = current.notebook;
    if (notebook == null || current.sort == sort) {
      return;
    }
    transitionCoordinator.queueFilterMutation(
      () => _notifier.setSortOverride(sort),
      scrollToTop: true,
    );
    unawaited(_writeNotebookSort(notebook, sort));
  }

  Future<void> _writeNotebookSort(
    NotebookView notebook,
    NotebookSort sort,
  ) async {
    try {
      await _state.ref
          .read(appDatabaseProvider)
          .updateNotebook(
            notebook.id,
            payload: notebook.payload.copyWith(sort: sort),
          );
    } catch (error) {
      debugPrint('Updating notebook sort failed: $error');
      if (!_state.mounted) {
        return;
      }
      transitionCoordinator.queueFilterMutation(
        _notifier.clearSortOverride,
        scrollToTop: true,
      );
      await feedback.showInfoSnackBar(_state.context.l10n.notebookActionFailed);
    }
  }

  /// 头部卡片“更多”菜单。删除前（确认之后）先回到全部日记，删除的撤销提示
  /// 不会再叠一条“日记本已删除”。头部卡片只在这本已解锁时可见，编辑、删除
  /// 不再二次验证（`authorized`）。
  Future<void> handleHeaderAction(NotebookAction action) async {
    final notebook = resolution.notebook;
    if (notebook == null) {
      return;
    }
    await runNotebookAction(
      _state.context,
      _state.ref,
      notebook: notebook,
      action: action,
      hooks: NotebookDeleteHooks(beforeDelete: () async => showAll()),
      authorized: true,
    );
  }

  /// 头部卡片“添加日记”与空日记本的“从已有日记挑选”：打开添加日记页。
  Future<void> openAddDiaries() async {
    final notebook = resolution.notebook;
    if (notebook == null || !notebook.isManual) {
      return;
    }
    await Navigator.of(
      _state.context,
    ).push(NotebookAddDiariesPage.route(notebook: notebook));
  }

  /// 在当前范围里新建日记时预先收进的日记本与章节：普通日记本里为这本（停在
  /// 某一章时带上这一章），全部日记与智能日记本里都为 null。
  ({String? notebookId, String? chapterId}) createTarget() {
    final current = resolution;
    final notebook = current.notebook;
    if (notebook == null || !notebook.isManual) {
      return (notebookId: null, chapterId: null);
    }
    return (notebookId: notebook.id, chapterId: current.state.chapterId);
  }

  /// 搜索页的范围参数：在日记本里时带上这本与它的名称、图标。
  ({DiaryListScope scope, String? label, FaIconData? icon}) searchScope() {
    final current = resolution;
    final notebook = current.notebook;
    if (notebook == null) {
      return (scope: DiaryListScope.all, label: null, icon: null);
    }
    return (
      scope: current.scope,
      label: NotebookSwitcherChip.labelFor(_state.context, notebook),
      icon: notebook.icon.data,
    );
  }
}
