part of 'diary_floating_toolbar.dart';

/// 段落选择模式：整张卡片换成段落操作栏（[DiaryBlockActionBar]）。
///
/// 进入时收起正在展开的面板（不播动画：卡片内容整个换掉），面板高度改由
/// 操作栏报告（表头 + 它的面板）；退出时操作栏卸载报告 0，工具栏回到收起
/// 态，下次构建照常报告自己的高度。
extension _DiaryFloatingToolbarBlocks on _DiaryFloatingToolbarState {
  void _syncBlockMode() {
    if (!mounted) return;
    if (widget.controller.blockSelection.isActive) {
      _panel = _ToolbarPanel.none;
      _content = _ToolbarPanel.none;
      _panelFromMore = false;
      _panelController.value = 0;
    }
    // 两边的高度报告交接：工具栏记成 0，与操作栏卸载时报告的一致。
    _reportedExtent = 0;
    setState(() {});
  }

  Widget _buildBlockActionBar() => DiaryBlockActionBar(
    controller: widget.controller,
    scale: _scale,
    maxPanelExtent: widget.maxPanelExtent,
    onPanelExtentChanged: widget.onPanelExtentChanged,
  );
}
