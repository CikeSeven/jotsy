// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 日记页的日记本范围编排：卡组切换、上锁验证、头部菜单、本子排序、
/// 日记本被删除后的回退与系统返回。
///
/// 职责边界：
/// - 范围状态在 `homeNotebookScopeProvider`，这里只决定何时、怎样切换；
/// - 页面发起的切换一律经过渡协调器（旧列表淡出 → 新范围数据到齐 → 回到
///   顶部淡入），并退出多选；
/// - 别处改了范围（上锁遮罩“回到全部日记”）时由 [handleScopeIdChanged]
///   补上同样的过渡；
/// - 不构建 UI（日记本卡组、确认框由各自的组件与 flow 负责）。
class DiariesNotebookScopeController {
  DiariesNotebookScopeController(
    this._state, {
    required this.feedback,
    required this.transitionCoordinator,
  }) : _expectedNotebookId = _state.ref.read(homeNotebookScopeProvider).key;

  final _DiariesPage _state;
  final DiariesPageFeedback feedback;
  final DiaryListTransitionCoordinator transitionCoordinator;

  /// 页面自己最近一次切到的日记本 id（null 为全部日记）：范围变化与它一致
  /// 说明是页面发起的，否则是外部改的，需要补过渡。初始为页面创建时所在的
  /// 范围（冷启动可能恢复到了上次的日记本），上锁遮罩里“回到全部日记”因此
  /// 同样被认作外部改动、补上过渡。
  String? _expectedNotebookId;

  HomeNotebookScopeNotifier get _notifier =>
      _state.ref.read(homeNotebookScopeProvider.notifier);

  HomeNotebookScopeResolution get resolution =>
      _state.ref.read(homeNotebookScopeResolutionProvider);

  /// 从切换胶囊打开日记本卡组（右滑拉出是另一个入口，见
  /// [NotebookSwitcherGesture]）。
  void openSwitcher() => _state._switcher.openFromChip(
    textDirection: Directionality.of(_state.context),
  );

  /// 进入日记本（头部的子本网格与面包屑共用）：上锁的先验证，未通过
  /// （取消、失败、设备不支持）停留原处。
  Future<void> enter(String notebookId) async {
    final current = _state.ref.read(homeNotebookScopeProvider);
    if (current.notebookId == notebookId) {
      return;
    }
    if (!await _authorize(notebookId) || !_state.mounted) {
      return;
    }
    _switchScope(notebookId, () => _notifier.enter(notebookId));
  }

  /// 卡组选中一项之前的验证：日记本按 [_authorize]，全部日记与未收录不用
  /// 验证。卡组在验证期间把那张卡片抽出来等着，未通过时落回。
  Future<bool> authorizeEntry(NotebookDeckEntry entry) async {
    final notebook = entry.notebook;
    if (notebook == null) return true;
    return await _authorize(notebook.id) && _state.mounted;
  }

  /// 卡组选中一项（已验证）：切换范围，新列表从卡组所在的行首一侧切入。
  void commitEntry(NotebookDeckEntry entry) {
    // 列表切换的方向口径：+1 新内容从右边来。卡组在行首（LTR 为左）。
    final direction = Directionality.of(_state.context) == TextDirection.ltr
        ? -1
        : 1;
    switch (entry.kind) {
      case NotebookDeckEntryKind.all:
        showAll(direction: direction);
      case NotebookDeckEntryKind.unfiled:
        showUnfiled(direction: direction);
      case NotebookDeckEntryKind.notebook:
        final id = entry.notebook!.id;
        if (_state.ref.read(homeNotebookScopeProvider).notebookId == id) {
          return;
        }
        _switchScope(id, () => _notifier.enter(id), direction: direction);
      case NotebookDeckEntryKind.closedHeader:
        return;
    }
  }

  /// 进入 [notebookId] 前的验证（上锁的本子）；返回是否放行。
  ///
  /// 在同一个上锁范围里切换（上锁的父本与随之上锁的子本之间、经面包屑回到
  /// 上级）不再验证，见 [notebookSwitchRequiresAuth]；验证会话因切到后台
  /// 失效（relocked）时按从头进入处理。本子不在了（刚被删）不放行。
  Future<bool> _authorize(String notebookId) async {
    final current = _state.ref.read(homeNotebookScopeProvider);
    final tree = _state.ref.read(notebookTreeProvider);
    final notebook = tree?[notebookId];
    if (tree == null || notebook == null) {
      return false;
    }
    final needsAuth = notebookSwitchRequiresAuth(
      tree,
      notebook,
      fromId: current.relocked ? null : current.notebookId,
    );
    if (!needsAuth) {
      return true;
    }
    return authorizeNotebookEntry(_state.context, _state.ref, notebook);
  }

  /// 系统返回（多选与标签栏都已收起之后）：只在子本里回到上级本子。顶层
  /// 本子、未收录与全部日记不拦返回，应用直接退到后台、范围留着（#196）；
  /// 别的 PopScope 拦下返回时这里也会被叫到，所以没有上级时什么都不做，
  /// 不能回到全部日记。往上走不需要验证：上级要么与这本在同一个上锁范围
  /// 里，要么本身没有上锁（这本自己上的锁不会传给上级）。
  void back() {
    final parentId = resolution.notebook?.parentId;
    if (parentId == null) {
      return;
    }
    _goUp(parentId);
  }

  /// 头部的“新建子本”：打开预填了上级的编辑页。保存后留在当前
  /// 本子里，新子本出现在子本网格里。
  Future<void> createChild() async {
    final notebook = resolution.notebook;
    if (notebook == null || !notebook.canHaveChildren) {
      return;
    }
    await Navigator.of(
      _state.context,
    ).push(NotebookEditorPage.route(initialParentId: notebook.id));
  }

  /// 回到上级 [parentId]（返回键、当前本子被删掉或不见了）；上级不存在（或
  /// 本就在顶层）时回到全部日记。不经验证，理由见 [back]。
  void _goUp(String? parentId) {
    final parent = parentId == null
        ? null
        : _state.ref.read(notebookTreeProvider)?[parentId];
    if (parent == null) {
      showAll();
    } else {
      _switchScope(parent.id, () => _notifier.enter(parent.id));
    }
  }

  /// 进入“未收录”（没有收进任何日记本的日记，已在其中时不变）。
  /// [direction] 见 [DiaryListTransitionCoordinator.queueFilterMutation]。
  void showUnfiled({int? direction}) {
    if (_state.ref.read(homeNotebookScopeProvider).unfiled) {
      return;
    }
    _switchScope(
      HomeNotebookScope.unfiledKey,
      _notifier.showUnfiled,
      direction: direction,
    );
  }

  /// 回到全部日记（已在全部日记时不变）。
  void showAll({int? direction}) {
    if (_state.ref.read(homeNotebookScopeProvider).isAll) {
      return;
    }
    _switchScope(null, _notifier.showAll, direction: direction);
  }

  /// 功能管理里关掉日记本时，首页若停在某本里就回到全部日记（日记本功能
  /// 关闭时隐藏入口，数据保留）。
  ///
  /// 此刻用户正在首页之上的设置页里，所以必须走页面自己的 [showAll]：它先
  /// 记下预期的范围，[handleScopeIdChanged] 便不会把它当成外部改动去
  /// `popUntil` 关掉设置页；范围本身回到全部日记，不经“本子不见了”的解析，
  /// 也就不会误报“日记本已删除”。新范围不带 relocked，重锁遮罩随之失效。
  /// 放到微任务里执行：监听回调里不直接改 provider。重新开启时不恢复原来的
  /// 本子：回到全部日记的同时记下的范围也已改成全部日记。
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

  /// [scopeKey] 为新范围的 [HomeNotebookScope.key]；[direction] 为列表
  /// 切换的左右方向（null 为纵向进出）。
  void _switchScope(String? scopeKey, VoidCallback mutation, {int? direction}) {
    _expectedNotebookId = scopeKey;
    if (_state._isSelectionMode) {
      _state.setState(_state._resetSelection);
    }
    transitionCoordinator.queueFilterMutation(
      mutation,
      scrollToTop: true,
      direction: direction,
    );
  }

  /// 范围的身份（[HomeNotebookScope.key]）变了：不是页面发起的（上锁遮罩
  /// “回到全部日记”）时，
  /// 先关掉首页之上的所有页面（可能正开着这本里的日记），再同样退出多选、
  /// 冻结旧列表并回到顶部淡入。
  void handleScopeIdChanged(String? next) {
    if (next == _expectedNotebookId) {
      return;
    }
    _expectedNotebookId = next;
    // 卡组开着时（例如上锁遮罩里回到全部日记）直接收掉，不留在新范围上。
    _state._switcher.dismissImmediately();
    Navigator.of(_state.context).popUntil((Route<dynamic> route) {
      return route.isFirst;
    });
    if (_state._isSelectionMode) {
      _state.setState(_state._resetSelection);
    }
    transitionCoordinator.queueFilterMutation(() {}, scrollToTop: true);
  }

  /// 范围解析变化：
  /// - 当前日记本不见了（被删除或并入别的本子）→ 回到它的上级（上级也不在
  ///   时回到全部日记）并提示。上级取自上一次解析：本子不见之后就查不到了；
  /// - 本子的排序已写回并推送回来 → 清除临时排序，之后在编辑页改排序不会
  ///   被它挡住。
  ///
  /// 在监听回调里不直接改 provider，放到微任务里执行。
  void handleResolutionChanged(
    HomeNotebookScopeResolution? previous,
    HomeNotebookScopeResolution next,
  ) {
    if (next.missing && !(previous?.missing ?? false)) {
      final lastParentId = previous?.notebook?.parentId;
      scheduleMicrotask(() {
        if (!_state.mounted) {
          return;
        }
        _goUp(lastParentId);
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
    if (_state._isSelectionMode) {
      _state.setState(_state._resetSelection);
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

  /// 首页“更多 → 排序方式”里改本子的排序：先按新排序过渡显示，再写回本子；
  /// 写入失败时退回原排序并提示。
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

  /// 头部卡片“更多”菜单。删除前（确认之后）先回到上级（顶层本子回到全部
  /// 日记），删除的撤销提示不会再叠一条“日记本已删除”。头部卡片只在这本已
  /// 解锁时可见，编辑、删除不再二次验证（`authorized`）。
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
      hooks: NotebookDeleteHooks(
        beforeDelete: () async => _goUp(notebook.parentId),
      ),
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

  /// 搜索页的范围参数：在日记本或“未收录”里时带上范围与它的名称、图标；
  /// 在全部日记里时为全局搜索（隐藏日记本里的日记也搜得到）。
  ({DiaryListScope scope, String? label, FaIconData? icon}) searchScope() {
    final current = resolution;
    final notebook = current.notebook;
    if (current.isUnfiled) {
      return (
        scope: DiaryListScope.unfiled,
        label: _state.context.l10n.notebookUnfiled,
        icon: NotebookSwitcherChip.unfiledIcon,
      );
    }
    if (notebook == null) {
      return (scope: DiaryListScope.globalSearch, label: null, icon: null);
    }
    return (
      scope: current.scope,
      label: NotebookSwitcherChip.labelFor(_state.context, notebook),
      icon: notebook.icon.data,
    );
  }
}
