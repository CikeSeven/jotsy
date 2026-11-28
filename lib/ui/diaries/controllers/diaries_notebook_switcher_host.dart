// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 日记页给日记本卡组（[NotebookSwitcherController]）的接口：列表栏与切换
/// 胶囊的几何、当前范围、验证与提交切换（都转给范围控制器）。
///
/// 另外负责卡组与页面的联动（[attach] 时登记）：
/// - 卡组看得见时重建页面，`PopScope` 先拦下返回收起卡组；
/// - 进度轴变化时把列表推开一点（[DiaryListSwitchMotion.pullShift]）：左缘
///   拉出时先跟 4dp，长成面板这一段再跟 10dp；从切换胶囊打开只跟后一段。
class DiariesNotebookSwitcherHost implements NotebookSwitcherHost {
  DiariesNotebookSwitcherHost(this._state);

  final _DiariesPage _state;

  /// 列表栏被推开的最大距离：拉出胶囊一段与长成面板一段。
  static const double _pillShift = 4;
  static const double _panelShift = 10;

  void attach(NotebookSwitcherController controller) {
    controller
      ..addListener(() => _syncVisibility(controller))
      ..stage.addListener(() => _syncListPull(controller));
  }

  void _syncVisibility(NotebookSwitcherController controller) {
    if (controller.isVisible == _state._switcherVisible) return;
    // 卡组可能在页面构建途中被收掉（关闭日记本功能、外部改了范围的监听
    // 回调里）：那时不能 setState，放到这一帧之后。
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _syncVisibility(controller),
      );
      return;
    }
    if (_state.mounted) {
      _state.setState(() => _state._switcherVisible = controller.isVisible);
    }
  }

  void _syncListPull(NotebookSwitcherController controller) {
    final stage = controller.stage.value;
    final fromEdge = controller.origin == NotebookSwitcherOrigin.edge;
    final shift =
        (fromEdge ? _pillShift * stage.clamp(0.0, 1.0) : 0.0) +
        _panelShift * (stage - 1).clamp(0.0, 1.0);
    _state._listSwitchMotion.pullShift = shift * controller.directionSign;
  }

  @override
  BuildContext get context => _state.context;

  @override
  Rect? get paneRect => _globalRect(_state._switcherPaneKey.currentContext);

  /// 搜索栏此刻在屏幕上的底边全局 y：由刊头可见底边扣去搜索条下方留白
  /// 换算，实色 / 玻璃顶栏与滚动收起途中都一致，且不受入场位移或多选态
  /// 切换影响。
  @override
  double? get searchBarBottom {
    final rect = _globalRect(_state._switcherHeaderKey.currentContext);
    if (rect == null || rect.isEmpty) return null;
    return rect.bottom - DiaryHeadSection.searchBarBottomInset;
  }

  /// 切换胶囊完整显示时的矩形：被标签条横向滚出一截、标签栏收起（零尺寸）
  /// 时为 null，卡组改回左缘。
  @override
  Rect? get chipRect {
    final rect = _globalRect(_state._switcherChipKey.currentContext);
    final pane = paneRect;
    if (rect == null || pane == null || rect.isEmpty) return null;
    const slack = 4.0;
    final inside =
        rect.left >= pane.left + slack &&
        rect.right <= pane.right - slack &&
        rect.top >= pane.top &&
        rect.bottom <= pane.bottom;
    return inside ? rect : null;
  }

  static Rect? _globalRect(BuildContext? context) {
    final box = context?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  bool isCurrent(NotebookDeckEntry entry) {
    final scope = _state.ref.read(homeNotebookScopeProvider);
    return switch (entry.kind) {
      NotebookDeckEntryKind.all => scope.isAll,
      NotebookDeckEntryKind.unfiled => scope.unfiled,
      NotebookDeckEntryKind.notebook => entry.notebook!.id == scope.notebookId,
      NotebookDeckEntryKind.closedHeader => false,
    };
  }

  @override
  Future<bool> authorize(NotebookDeckEntry entry) =>
      _state._scopeController.authorizeEntry(entry);

  @override
  void commit(NotebookDeckEntry entry) =>
      _state._scopeController.commitEntry(entry);
}
