part of 'diary_floating_toolbar.dart';

/// 工具栏一排与单个工具的构建，从 [DiaryFloatingToolbar] 拆出；面板状态机
/// 仍在主文件里，这里只读取状态并转发点按。
extension _DiaryFloatingToolbarBar on _DiaryFloatingToolbarState {
  /// 全部放得下：紧凑居中（与改版前一致）。
  Widget _buildCompactBar(BuildContext context, List<DiaryToolbarItem> items) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var index = 0; index < items.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: kDiaryToolbarItemGap),
            _buildTool(context, items[index]),
          ],
        ],
      ),
    );
  }

  /// 放不下：整排按列等分，常驻工具从左依次占格，「更多」固定在最后一格；
  /// 「更多」面板沿用同样的列宽，上下两部分的按钮对齐成一张网格。
  Widget _buildOverflowBar(
    BuildContext context,
    DiaryToolbarLayout layout,
    double width,
  ) {
    final cellWidth = _overflowCellWidth(layout, width);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kDiaryToolbarHorizontalPadding,
      ),
      child: Row(
        children: <Widget>[
          for (final item in layout.pinned)
            _overflowCell(context, item, layout),
          const Spacer(),
          SizedBox(
            width: cellWidth,
            child: Center(
              child: _scaledTool(
                DiaryToolbarMoreButton(
                  controller: widget.controller,
                  overflow: layout.overflow,
                  expanded: _moreExpanded,
                  recordingOpen: widget.recordingOpen,
                  onPressed: _toggleMore,
                ),
                width: kDiaryToolbarButtonExtent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _overflowCellWidth(DiaryToolbarLayout layout, double width) =>
      (width - 2 * kDiaryToolbarHorizontalPadding) / layout.columns;

  Widget _overflowCell(
    BuildContext context,
    DiaryToolbarItem item,
    DiaryToolbarLayout layout, {
    bool inMorePanel = false,
  }) => SizedBox(
    width: _overflowCellWidth(layout, _width) * diaryToolbarItemSlots(item),
    child: Center(child: _buildTool(context, item, inMorePanel: inMorePanel)),
  );

  /// 单个工具占固定尺寸的格子：排布按常量计算，按钮实际尺寸受主题影响时
  /// 也不会把整排挤歪。
  Widget _buildTool(
    BuildContext context,
    DiaryToolbarItem item, {
    bool inMorePanel = false,
  }) {
    final colorTarget = switch (item) {
      DiaryToolbarItem.textColor => DiaryColorTarget.text,
      DiaryToolbarItem.backgroundColor => DiaryColorTarget.background,
      _ => null,
    };
    final Widget tool;
    if (colorTarget != null) {
      tool = DiaryToolbarColorButton(
        controller: widget.controller,
        target: colorTarget,
        selected:
            !inMorePanel &&
            _panel == _ToolbarPanel.color &&
            _colorTarget == colorTarget &&
            !_panelFromMore,
        tooltip: item.label(context.l10n),
        onPressed: () => _handleColorTool(colorTarget, fromMore: inMorePanel),
      );
    } else if (item == DiaryToolbarItem.orderedList ||
        item == DiaryToolbarItem.bulletList) {
      tool = buildDiaryToolbarItem(
        context,
        item,
        widget.controller,
        onPressed: () => _handleListTool(item, fromMore: inMorePanel),
        panelOpen: !inMorePanel && _listPanelOpenFor(item),
      );
    } else if (_textStylePanelFor(item) != null) {
      tool = buildDiaryToolbarItem(
        context,
        item,
        widget.controller,
        onPressed: () => _handleTextStyleTool(item, fromMore: inMorePanel),
        panelOpen: !inMorePanel && _textStylePanelOpenFor(item),
      );
    } else if (item == DiaryToolbarItem.callout) {
      tool = buildDiaryToolbarItem(
        context,
        item,
        widget.controller,
        onPressed: () => _handleCalloutTool(fromMore: inMorePanel),
        panelOpen: !inMorePanel && _calloutPanelOpen,
      );
    } else if (item == DiaryToolbarItem.table) {
      tool = DiaryToolbarTableButton(
        controller: widget.controller,
        panelOpen: !inMorePanel && _tablePanelOpen,
        tooltip: item.label(context.l10n),
        onPressed: () => _handleTableTool(fromMore: inMorePanel),
      );
    } else if (item == DiaryToolbarItem.codeBlock) {
      tool = DiaryToolbarCodeBlockButton(
        controller: widget.controller,
        panelOpen:
            !inMorePanel && _panel == _ToolbarPanel.code && !_panelFromMore,
        tooltip: item.label(context.l10n),
        onPressed: () => _handleCodeBlockTool(fromMore: inMorePanel),
      );
    } else if (_cameraKindFor(item) case final kind?) {
      // 能拍摄时图片 / 视频先选来源；按钮本身（停用、导入中的加载图标）
      // 照旧由 buildDiaryToolbarItem 画，点按改为开合菜单。
      final mediaImportController = widget.mediaImportController;
      final onMediaPressed = widget.onMediaPressed;
      tool = DiaryToolbarMediaSourceButton(
        kind: kind,
        onPickFromLibrary: () => onMediaPressed?.call(kind),
        onCapture: () => widget.onCameraPressed!(kind),
        builder: (context, onPressed, menuOpen) => buildDiaryToolbarItem(
          context,
          item,
          widget.controller,
          onPressed: onPressed,
          panelOpen: menuOpen,
          recordingOpen: widget.recordingOpen,
          onMediaPressed: onMediaPressed,
          activeMediaKind: mediaImportController?.activeKind,
          mediaImportBusy: mediaImportController?.isBusy ?? false,
        ),
      );
    } else {
      final mediaImportController = widget.mediaImportController;
      tool = buildDiaryToolbarItem(
        context,
        item,
        widget.controller,
        currentTimeFormatPattern: widget.currentTimeFormatPattern,
        onRecordingPressed: widget.onRecordingPressed,
        recordingOpen: widget.recordingOpen,
        onAiPressed: widget.onAiPressed,
        aiOpen: widget.aiOpen,
        onMediaPressed: widget.onMediaPressed,
        activeMediaKind: mediaImportController?.activeKind,
        mediaImportBusy: mediaImportController?.isBusy ?? false,
      );
    }
    return KeyedSubtree(
      key: ValueKey('diary-toolbar-tool-${item.storageKey}'),
      child: _scaledTool(tool, width: diaryToolbarItemExtent(item)),
    );
  }

  /// 图片 / 视频工具在能拍摄时（给了 [DiaryFloatingToolbar.onCameraPressed]）
  /// 对应的媒体类型；其余工具为 null。
  DiaryMediaKind? _cameraKindFor(DiaryToolbarItem item) {
    if (widget.onCameraPressed == null) return null;
    return switch (item) {
      DiaryToolbarItem.image => DiaryMediaKind.image,
      DiaryToolbarItem.video => DiaryMediaKind.video,
      _ => null,
    };
  }

  Widget _scaledTool(Widget tool, {required double width}) =>
      diaryToolbarScaledTool(tool, width: width, scale: _scale);
}
