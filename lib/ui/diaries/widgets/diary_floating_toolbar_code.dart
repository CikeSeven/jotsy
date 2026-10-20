part of 'diary_floating_toolbar.dart';

/// 代码块工具与代码块面板的状态切换，从 [DiaryFloatingToolbar] 拆出；面板
/// 状态（[_DiaryFloatingToolbarState._panel] 等）仍在主文件里。
///
/// - 点按代码块工具：选区没碰到代码块 → 当前行（或选区覆盖的各行）转为未
///   指定语言的代码块，面板原样不动（「更多」开着就仍开着）；碰到 → 与颜色
///   工具同一套路由：常驻的工具在面板为它打开时再点收起，「更多」里的工具
///   切到代码块面板并记下来源，「更多」按钮保持展开态；
/// - 面板开着时选区离开所有代码块（点到正文别处、退出、转为正文、撤销）即
///   收起，从「更多」打开的回到「更多」。
extension _DiaryFloatingToolbarCode on _DiaryFloatingToolbarState {
  void _handleCodeBlockTool({required bool fromMore}) {
    final controller = widget.controller;
    if (!diarySelectionInCodeBlock(controller)) {
      toggleDiaryCodeBlockOn(controller);
      return;
    }
    if (!fromMore && _panel == _ToolbarPanel.code && !_panelFromMore) {
      _setPanel(_ToolbarPanel.none);
      return;
    }
    _panelFromMore = fromMore;
    _setPanel(_ToolbarPanel.code);
  }

  /// 收起代码块面板：从「更多」打开的回到「更多」。面板已不在时什么都不做
  /// （退出、转为正文会先经选区监听收起，面板的回调随后到达）。
  void _closeCodePanel() {
    if (_panel != _ToolbarPanel.code) return;
    _setPanel(_panelFromMore ? _ToolbarPanel.more : _ToolbarPanel.none);
  }

  /// 正文控制器通知时检查代码块面板是否还该开着。
  ///
  /// 通知可能落在构建阶段（编辑器在布局中纠正选区）：此时改状态会在锁定的
  /// 树上 setState，并让编辑页在构建中刷新，所以推到这一帧结束后再检查。
  void _syncCodePanelWithSelection() {
    if (_panel != _ToolbarPanel.code) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncCodePanelWithSelection();
      });
      return;
    }
    if (!diarySelectionInCodeBlock(widget.controller)) _closeCodePanel();
  }
}
