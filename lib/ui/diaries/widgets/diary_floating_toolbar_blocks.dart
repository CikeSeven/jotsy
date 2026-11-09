part of 'diary_floating_toolbar.dart';

/// 段落选择模式：整张卡片换成段落操作栏（[DiaryBlockActionBar]），面板高度
/// 改由操作栏经同一个回调报告（表头 + 它的面板）。进出时的面板收起见
/// `_DiaryFloatingToolbarState._handleBlockMode`。
extension _DiaryFloatingToolbarBlocks on _DiaryFloatingToolbarState {
  Widget _buildBlockActionBar() => DiaryBlockActionBar(
    controller: widget.controller,
    scale: _scale,
    maxPanelExtent: widget.maxPanelExtent,
    onPanelExtentChanged: widget.onPanelExtentChanged,
  );
}
