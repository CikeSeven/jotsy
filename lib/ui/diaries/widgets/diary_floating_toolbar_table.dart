part of 'diary_floating_toolbar.dart';

/// 表格工具与表格面板的状态切换，从 [DiaryFloatingToolbar] 拆出；面板状态
/// （[_DiaryFloatingToolbarState._panel] 等）仍在主文件里。与代码块工具
/// 同一套路由：
///
/// - 点按表格工具：光标不在表格里 → 在当前块后面插入 3 × 3、带表头行的
///   表格并把光标放进第一格（空段落上插入时取代它），面板原样不动；在表格
///   里 → 打开表格面板：常驻的工具在面板为它打开时再点收起，「更多」里的
///   工具切到面板并记下来源，「更多」按钮保持展开态；
/// - 面板开着时选区离开表格（点到正文别处、删除表格、撤销）即收起，从
///   「更多」打开的回到「更多」。
extension _DiaryFloatingToolbarTable on _DiaryFloatingToolbarState {
  void _handleTableTool({required bool fromMore}) {
    final controller = widget.controller;
    if (!diarySelectionInTable(controller)) {
      insertDiaryTable(controller);
      return;
    }
    if (!fromMore && _panel == _ToolbarPanel.table && !_panelFromMore) {
      _setPanel(_ToolbarPanel.none);
      return;
    }
    _panelFromMore = fromMore;
    _setPanel(_ToolbarPanel.table);
  }

  /// 面板是不是正为常驻的表格工具打开（按钮据此显示选中态）。
  bool get _tablePanelOpen => _panel == _ToolbarPanel.table && !_panelFromMore;

  /// 收起表格面板：从「更多」打开的回到「更多」。面板已不在时什么都不做
  /// （删除表格会先经选区监听收起，面板的回调随后到达）。
  void _closeTablePanel() {
    if (_panel != _ToolbarPanel.table) return;
    _setPanel(_panelFromMore ? _ToolbarPanel.more : _ToolbarPanel.none);
  }

  /// 选区变化后（已推迟到构建之外）检查表格面板是否还该开着。
  ///
  /// 再推迟一个微任务：行列操作与它的撤销会整个重建表格节点，上游先发事务
  /// 通知、后更新选区，通知到达时旧选区的路径可能一时不在新树上（看起来像
  /// 离开了表格）；等这次 apply 同步结束、选区落到新表格里再判断。
  void _syncTablePanelWithSelection() {
    scheduleMicrotask(() {
      if (mounted &&
          _panel == _ToolbarPanel.table &&
          !diarySelectionInTable(widget.controller)) {
        _closeTablePanel();
      }
    });
  }
}
