part of 'diary_floating_toolbar.dart';

/// 有序 / 无序列表工具与列表面板的状态切换，从 [DiaryFloatingToolbar] 拆出；
/// 面板状态（[_DiaryFloatingToolbarState._panel] 等）仍在主文件里。与代码块
/// 工具同一套路由：
///
/// - 点按列表工具：选区里的文字块不全是这种列表 → 转为这种列表（原来的
///   切换行为），面板原样不动；全是 → 打开这种列表的样式面板：常驻的工具在
///   面板为它打开时再点收起，「更多」里的工具切到列表面板并记下来源；
/// - 面板开着时选区仍全在某一种列表里就跟着换成那种列表的样式（面板里的
///   “转为另一种列表”、另一个列表工具都会这样），离开列表（点到正文别处、
///   转为正文、撤销）即收起，从「更多」打开的回到「更多」。
extension _DiaryFloatingToolbarList on _DiaryFloatingToolbarState {
  void _handleListTool(DiaryToolbarItem item, {required bool fromMore}) {
    final type = item == DiaryToolbarItem.orderedList
        ? kDiaryBlockNumberedList
        : kDiaryBlockBulletedList;
    final controller = widget.controller;
    if (diarySelectionListType(controller) != type) {
      controller.setBlockType(type);
      return;
    }
    if (!fromMore &&
        _panel == _ToolbarPanel.list &&
        _listType == type &&
        !_panelFromMore) {
      _setPanel(_ToolbarPanel.none);
      return;
    }
    _listType = type;
    _panelFromMore = fromMore;
    _setPanel(_ToolbarPanel.list);
  }

  /// 列表面板是不是正为 [item] 打开（常驻的工具据此显示选中态）。
  bool _listPanelOpenFor(DiaryToolbarItem item) =>
      _panel == _ToolbarPanel.list &&
      !_panelFromMore &&
      _listType ==
          (item == DiaryToolbarItem.orderedList
              ? kDiaryBlockNumberedList
              : kDiaryBlockBulletedList);

  /// 收起列表面板：从「更多」打开的回到「更多」。面板已不在时什么都不做。
  void _closeListPanel() {
    if (_panel != _ToolbarPanel.list) return;
    _setPanel(_panelFromMore ? _ToolbarPanel.more : _ToolbarPanel.none);
  }

  /// 选区变化后（已推迟到构建之外）列表面板该收起、换类型还是保持。
  void _syncListPanelWithSelection() {
    final type = diarySelectionListType(widget.controller);
    if (type == null) {
      _closeListPanel();
    } else if (type != _listType) {
      _showListType(type);
    }
  }
}
