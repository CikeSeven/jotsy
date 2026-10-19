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
  /// 不会再叠一条“日记本已删除”。
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
    );
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
