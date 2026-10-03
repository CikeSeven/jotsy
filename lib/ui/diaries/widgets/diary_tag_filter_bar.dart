import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import 'expanded_tag_filter_list.dart';
import 'tag_filter_chip.dart';
import 'tag_filter_clear_button.dart';
import 'tag_filter_collapse_handle.dart';
import 'tag_filter_expansion_gesture.dart';

/// 日记页顶部标签筛选栏。
///
/// 结构：
/// - 左侧纯 `X` 清空筛选按钮（带缩放 + 旋转反馈）；
/// - 收起时横向滚动，展开时用四行高的独立窗口浏览全部标签；
/// - 卡片尺寸和主题样式在两种排列中一致；
/// - 标签区域的拖动不移交给日记滚动或 Home 切页。
class DiaryTagFilterBar extends StatefulWidget {
  const DiaryTagFilterBar({
    super.key,
    required this.tags,
    required this.expansionProgress,
    required this.canExpand,
    required this.canCollapse,
    required this.selectedTagFilterIds,
    required this.onToggleTagFilter,
    required this.onClearTagFilters,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onCollapse,
  });

  static const int maxExpandedRows = 4;
  static const double collapsedHeaderExtent = 46;
  static const double chipExtent = 32;
  static const double _expandedRowSpacing = AppSpacing.xs;
  static const double expandedRowsExtent =
      chipExtent * maxExpandedRows +
      _expandedRowSpacing * (maxExpandedRows - 1);
  static const double collapseHandleExtent = 24;
  static const double expandedContentExtent =
      expandedRowsExtent + collapseHandleExtent;
  static const double expandedBarExtent =
      expandedContentExtent + AppSpacing.xs * 2;
  static const double expandedHeaderExtent = expandedContentExtent + 14;
  static const collapseHandleKey = ValueKey<String>(
    'diary_tag_collapse_handle',
  );

  final List<Tag> tags;
  final ValueListenable<double> expansionProgress;
  final bool Function() canExpand;
  final bool Function() canCollapse;
  final Set<int> selectedTagFilterIds;
  final void Function(int tagId, bool selected) onToggleTagFilter;
  final VoidCallback onClearTagFilters;
  final ValueChanged<bool> onVerticalDragStart;
  final ValueChanged<double> onVerticalDragUpdate;
  final ValueChanged<double> onVerticalDragEnd;
  final VoidCallback onCollapse;

  @override
  State<DiaryTagFilterBar> createState() => _DiaryTagFilterBarState();
}

class _DiaryTagFilterBarState extends State<DiaryTagFilterBar> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final GlobalKey _clearKey = GlobalKey();
  double _contentWidth = 0;

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expandedTags = _buildExpandedTags();
    final collapsedTags = _buildCollapsedTags();

    return LayoutBuilder(
      builder: (context, constraints) {
        _contentWidth = constraints.maxWidth - AppSpacing.m * 2;
        return TagFilterExpansionGesture(
          canExpand: () => widget.tags.isNotEmpty && widget.canExpand(),
          canCollapse: _canCollapseFrom,
          allowVerticalScroll: _canScrollVertically,
          allowHorizontalScroll: _canScrollHorizontally,
          onStart: widget.onVerticalDragStart,
          onUpdate: widget.onVerticalDragUpdate,
          onEnd: widget.onVerticalDragEnd,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.xs,
              AppSpacing.m,
              AppSpacing.xs,
            ),
            child: ValueListenableBuilder<double>(
              valueListenable: widget.expansionProgress,
              child: expandedTags,
              builder: (BuildContext context, double progress, Widget? child) {
                final normalizedProgress = progress.clamp(0.0, 1.0);
                final contentHeight =
                    DiaryTagFilterBar.chipExtent +
                    (DiaryTagFilterBar.expandedContentExtent -
                            DiaryTagFilterBar.chipExtent) *
                        normalizedProgress;
                final showExpandedLayout = normalizedProgress > 0;
                return SizedBox(
                  width: double.infinity,
                  height: contentHeight,
                  child: showExpandedLayout
                      ? ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: DiaryTagFilterBar.expandedContentExtent,
                            maxHeight: DiaryTagFilterBar.expandedContentExtent,
                            child: child,
                          ),
                        )
                      : collapsedTags,
                );
              },
            ),
          ),
        );
      },
    );
  }

  bool _inContentWidth(Offset start) =>
      start.dx >= AppSpacing.m && start.dx <= AppSpacing.m + _contentWidth;

  bool _canScrollVertically(Offset start) =>
      widget.expansionProgress.value > 0 &&
      _inContentWidth(start) &&
      start.dy >= AppSpacing.xs &&
      start.dy < AppSpacing.xs + DiaryTagFilterBar.expandedRowsExtent;

  bool _canCollapseFrom(Offset start) =>
      widget.canCollapse() &&
      _inContentWidth(start) &&
      start.dy >= AppSpacing.xs + DiaryTagFilterBar.expandedRowsExtent &&
      start.dy <= AppSpacing.xs + DiaryTagFilterBar.expandedContentExtent;

  bool _canScrollHorizontally(Offset startPosition) {
    if (widget.expansionProgress.value > 0 ||
        !_horizontalController.hasClients) {
      return false;
    }
    final position = _horizontalController.position;
    if (!position.hasContentDimensions) {
      return false;
    }
    // A drag beginning in the panel padding never reaches the inner ListView.
    // Consume it here instead of passing it on to Home's horizontal PageView.
    // Scroll metrics are cached by layout and remain safe to read even when a
    // selection animation has already marked a render box dirty for layout.
    if (startPosition.dx < AppSpacing.m ||
        startPosition.dx > position.viewportDimension + AppSpacing.m ||
        startPosition.dy < AppSpacing.xs ||
        startPosition.dy > DiaryTagFilterBar.chipExtent + AppSpacing.xs) {
      return false;
    }
    return position.maxScrollExtent > position.minScrollExtent;
  }

  Widget _buildCollapsedTags() {
    return ListView.separated(
      key: const PageStorageKey<String>('diary_tag_filter_horizontal'),
      controller: _horizontalController,
      scrollDirection: Axis.horizontal,
      itemCount: widget.tags.length + 1,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
      itemBuilder: (BuildContext context, int index) => _buildTagItem(index),
    );
  }

  Widget _buildExpandedTags() {
    return SizedBox(
      height: DiaryTagFilterBar.expandedContentExtent,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: DiaryTagFilterBar.expandedRowsExtent,
            child: ExpandedTagFilterList(
              tags: widget.tags,
              selectedTagIds: widget.selectedTagFilterIds,
              controller: _verticalController,
              itemBuilder: _buildTagItem,
              rowHeight: DiaryTagFilterBar.chipExtent,
              spacing: AppSpacing.s,
              rowSpacing: AppSpacing.xs,
            ),
          ),
          SizedBox(
            height: DiaryTagFilterBar.collapseHandleExtent,
            child: TagFilterCollapseHandle(
              key: DiaryTagFilterBar.collapseHandleKey,
              onCollapse: widget.onCollapse,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagItem(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = widget.selectedTagFilterIds.isNotEmpty;
    if (index == 0) {
      return TagFilterClearButton(
        key: _clearKey,
        hasSelection: hasSelection,
        onClear: widget.onClearTagFilters,
      );
    }

    final tag = widget.tags[index - 1];
    final selected = widget.selectedTagFilterIds.contains(tag.id);
    // A horizontal ListView supplies a tight 32dp cross-axis constraint, but a
    // Multi-row layout otherwise uses the chip's smaller intrinsic height. Retain that same
    // constraint here so expansion changes only positions, never card styling.
    return SizedBox(
      height: DiaryTagFilterBar.chipExtent,
      child: TagFilterChip(
        label: tag.name,
        colorDot: Color(tag.color),
        colorDotSize: 12,
        selected: selected,
        selectedColor: colorScheme.secondaryContainer,
        selectedForegroundColor: colorScheme.onSecondaryContainer,
        unselectedColor: colorScheme.surfaceContainerHigh,
        unselectedForegroundColor: colorScheme.onSurface,
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        animateBorder: true,
        showSelectedShadow: false,
        onTap: () => widget.onToggleTagFilter(tag.id, !selected),
      ),
    );
  }
}
