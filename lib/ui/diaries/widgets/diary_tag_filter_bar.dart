import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import 'expanded_tag_filter_list.dart';
import 'tag_filter_chip.dart';
import 'tag_filter_clear_button.dart';
import 'tag_filter_collapse_handle.dart';
import 'tag_filter_expansion_gesture.dart';
import 'tag_filter_layout.dart';

/// 日记页顶部标签筛选栏。
///
/// 结构：
/// - 左侧纯 `X` 清空筛选按钮（带缩放 + 旋转反馈）；
/// - 收起时横向滚动，展开高度随实际行数变化，最多五行并独立滚动；
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

  static const int maxExpandedRows = 5;
  static const double chipExtent = 32;
  static const double _expandedRowSpacing = AppSpacing.xs;
  static const double maxExpandedRowsExtent =
      chipExtent * maxExpandedRows +
      _expandedRowSpacing * (maxExpandedRows - 1);
  static const double collapseHandleExtent = 24;
  static const double maxExpandedBarExtent =
      maxExpandedRowsExtent + collapseHandleExtent + AppSpacing.xs * 2;
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

  /// Passes the raw drag distance and current content's expansion travel so
  /// the parent can track gesture intent without assuming a fixed row count.
  final void Function(double delta, double expansionExtent)
  onVerticalDragUpdate;
  final ValueChanged<double> onVerticalDragEnd;
  final VoidCallback onCollapse;

  @override
  State<DiaryTagFilterBar> createState() => _DiaryTagFilterBarState();
}

class _DiaryTagFilterBarState extends State<DiaryTagFilterBar> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final GlobalKey _clearKey = GlobalKey();
  final TagFilterLayoutCache _layoutCache = TagFilterLayoutCache();
  double _contentWidth = 0;
  double _expandedRowsExtent = DiaryTagFilterBar.chipExtent;

  double get _expandedContentExtent =>
      _expandedRowsExtent + DiaryTagFilterBar.collapseHandleExtent;

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collapsedTags = _buildCollapsedTags();

    return LayoutBuilder(
      builder: (context, constraints) {
        _contentWidth = (constraints.maxWidth - AppSpacing.m * 2).clamp(
          0.0,
          double.infinity,
        );
        final layout = _layoutCache.resolve(
          context,
          tags: widget.tags,
          selectedTagIds: widget.selectedTagFilterIds,
          width: _contentWidth,
          spacing: AppSpacing.s,
        );
        _expandedRowsExtent = layout.visibleRowsExtent(
          rowHeight: DiaryTagFilterBar.chipExtent,
          rowSpacing: DiaryTagFilterBar._expandedRowSpacing,
          maxRows: DiaryTagFilterBar.maxExpandedRows,
        );
        final expandedContentExtent = _expandedContentExtent;
        return TagFilterExpansionGesture(
          canExpand: () => widget.tags.isNotEmpty && widget.canExpand(),
          canCollapse: _canCollapseFrom,
          allowVerticalScroll: _canScrollVertically,
          allowHorizontalScroll: _canScrollHorizontally,
          onStart: widget.onVerticalDragStart,
          onUpdate: (delta) => widget.onVerticalDragUpdate(
            delta,
            expandedContentExtent - DiaryTagFilterBar.chipExtent,
          ),
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
              child: _buildExpandedTags(layout),
              builder: (BuildContext context, double progress, Widget? child) {
                final normalizedProgress = progress.clamp(0.0, 1.0);
                final contentHeight =
                    DiaryTagFilterBar.chipExtent +
                    (expandedContentExtent - DiaryTagFilterBar.chipExtent) *
                        normalizedProgress;
                final showExpandedLayout = normalizedProgress > 0;
                return SizedBox(
                  width: double.infinity,
                  height: contentHeight,
                  child: showExpandedLayout
                      ? ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: expandedContentExtent,
                            maxHeight: expandedContentExtent,
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
      start.dy < AppSpacing.xs + _expandedRowsExtent;

  bool _canCollapseFrom(Offset start) =>
      widget.canCollapse() &&
      _inContentWidth(start) &&
      start.dy >= AppSpacing.xs + _expandedRowsExtent &&
      start.dy <= AppSpacing.xs + _expandedContentExtent;

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

  Widget _buildExpandedTags(TagFilterLayout layout) {
    return SizedBox(
      height: _expandedContentExtent,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: _expandedRowsExtent,
            child: ExpandedTagFilterList(
              layout: layout,
              controller: _verticalController,
              itemBuilder: _buildTagItem,
              rowHeight: DiaryTagFilterBar.chipExtent,
              spacing: AppSpacing.s,
              rowSpacing: DiaryTagFilterBar._expandedRowSpacing,
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
    final tagColor = Color(tag.color);
    final isLight = Theme.of(context).brightness == Brightness.light;

    final unselectedBg = tagColor.withValues(alpha: isLight ? 0.08 : 0.16);
    final unselectedBorder = tagColor.withValues(alpha: isLight ? 0.22 : 0.32);
    final unselectedText = colorScheme.onSurface;

    final selectedBg = tagColor.withValues(alpha: isLight ? 0.22 : 0.36);
    final selectedBorder = tagColor;
    final selectedText = isLight
        ? (ThemeData.estimateBrightnessForColor(tagColor) == Brightness.dark
              ? tagColor
              : colorScheme.onSurface)
        : Colors.white;

    // A horizontal ListView supplies a tight 32dp cross-axis constraint, but a
    // Multi-row layout otherwise uses the chip's smaller intrinsic height. Retain that same
    // constraint here so expansion changes only positions, never card styling.
    return SizedBox(
      height: DiaryTagFilterBar.chipExtent,
      child: TagFilterChip(
        label: tag.name,
        colorDot: tagColor,
        selected: selected,
        selectedColor: selectedBg,
        selectedForegroundColor: selectedText,
        selectedBorderColor: selectedBorder,
        unselectedColor: unselectedBg,
        unselectedForegroundColor: unselectedText,
        unselectedBorderColor: unselectedBorder,
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        animateBorder: true,
        showSelectedShadow: false,
        onTap: () => widget.onToggleTagFilter(tag.id, !selected),
      ),
    );
  }
}
