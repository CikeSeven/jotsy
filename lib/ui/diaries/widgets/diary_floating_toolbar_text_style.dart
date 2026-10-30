part of 'diary_floating_toolbar.dart';

/// 标题、对齐、字号三个工具与它们的面板，从 [DiaryFloatingToolbar] 拆出；
/// 面板状态（[_DiaryFloatingToolbarState._panel] 等）仍在主文件里。与颜色
/// 工具同一套路由：
///
/// - 点按：常驻的工具在面板正为它打开时再点收起，其余情况切到它的面板；
///   「更多」里的工具切到面板并记下来源，「更多」按钮保持展开态；
/// - 面板不随选区收起（任何文字块都能改标题、对齐与字号），只跟着显示选区
///   当前的取值；光标进了代码块时按钮整排停用（见 [DiaryTextStylePanel]）；
/// - 表头只有标题、没有收起按钮（同列表、代码块面板）：再点一次工具或
///   「更多」收起。
extension _DiaryFloatingToolbarTextStyle on _DiaryFloatingToolbarState {
  void _handleTextStyleTool(DiaryToolbarItem item, {required bool fromMore}) {
    final panel = _textStylePanelFor(item);
    if (panel == null) return;
    if (!fromMore && _panel == panel && !_panelFromMore) {
      _setPanel(_ToolbarPanel.none);
      return;
    }
    _panelFromMore = fromMore;
    _setPanel(panel);
  }

  /// 面板是不是正为 [item] 打开（常驻的工具据此显示选中态）。
  bool _textStylePanelOpenFor(DiaryToolbarItem item) =>
      _panel == _textStylePanelFor(item) && !_panelFromMore;
}

/// 工具对应的文字样式面板；不是这三个工具时为 null。
_ToolbarPanel? _textStylePanelFor(DiaryToolbarItem item) => switch (item) {
  DiaryToolbarItem.headerStyle => _ToolbarPanel.heading,
  DiaryToolbarItem.align => _ToolbarPanel.align,
  DiaryToolbarItem.fontSize => _ToolbarPanel.fontSize,
  _ => null,
};
