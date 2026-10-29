part of 'diary_floating_toolbar.dart';

/// 提示块工具与提示块面板的状态切换，从 [DiaryFloatingToolbar] 拆出；面板
/// 状态（[_DiaryFloatingToolbarState._panel] 等）仍在主文件里。与代码块工具
/// 同一套路由：
///
/// - 点按提示块工具：选区不在提示块里（文字块不全是提示块）→ 把其余文字块
///   （代码块除外）转为提示块，面板原样不动；在 → 打开提示块面板：常驻的
///   工具在面板为它打开时再点收起，「更多」里的工具切到面板并记下来源，
///   「更多」按钮保持展开态；
/// - 面板开着时选区离开提示块（点到正文别处、转为正文、撤销）即收起，从
///   「更多」打开的回到「更多」。
extension _DiaryFloatingToolbarCallout on _DiaryFloatingToolbarState {
  void _handleCalloutTool({required bool fromMore}) {
    final controller = widget.controller;
    if (!diarySelectionInCallout(controller)) {
      convertDiaryBlocksToCallout(controller);
      return;
    }
    if (!fromMore && _panel == _ToolbarPanel.callout && !_panelFromMore) {
      _setPanel(_ToolbarPanel.none);
      return;
    }
    _panelFromMore = fromMore;
    _setPanel(_ToolbarPanel.callout);
  }

  /// 面板是不是正为常驻的提示块工具打开（按钮据此显示选中态）。
  bool get _calloutPanelOpen =>
      _panel == _ToolbarPanel.callout && !_panelFromMore;

  /// 收起提示块面板：从「更多」打开的回到「更多」。面板已不在时什么都不做
  /// （转为正文会先经选区监听收起，面板的回调随后到达）。
  void _closeCalloutPanel() {
    if (_panel != _ToolbarPanel.callout) return;
    _setPanel(_panelFromMore ? _ToolbarPanel.more : _ToolbarPanel.none);
  }

  /// 选区变化后（已推迟到构建之外）检查提示块面板是否还该开着。
  void _syncCalloutPanelWithSelection() {
    if (!diarySelectionInCallout(widget.controller)) _closeCalloutPanel();
  }
}
