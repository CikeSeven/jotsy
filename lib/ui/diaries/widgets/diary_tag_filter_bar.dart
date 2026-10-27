import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../widgets/list_item_presence.dart';
import 'expanded_tag_filter_list.dart';
import 'tag_filter_chip.dart';
import 'tag_filter_clear_button.dart';
import 'tag_filter_collapse_handle.dart';
import 'tag_filter_expansion_gesture.dart';
import 'tag_filter_layout.dart';
import '../../widgets/desktop_horizontal_scroll.dart';

/// 日记页顶部标签筛选栏。
///
/// 结构：
/// - 可选的前置项 [leading]（日记本切换胶囊），排在最前，收起与展开两种
///   排列里都在；
/// - 纯 `X` 清空筛选按钮（带缩放 + 旋转反馈）；
/// - 一个标签都没有时整栏只剩这个 `X`，点了也无事可做，于是整栏收起淡出；
///   仍有选中的筛选（例如记住的筛选指向已删除的标签）或 [keepVisible]
///   （有日记本可切换）时保留；
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
    this.leading,
    this.leadingWidth = 0,
    this.keepVisible = false,
  });

  static const int maxExpandedRows = 5;

  /// 1 倍字号下的标签行高（基准值）；下列 max* 常量同样按基准字号计算。
  static const double chipExtent = 32;

  /// 按当前字号缩放的标签行高：labelMedium 行高 16dp + 上下内边距与选中
  /// 描边共 16dp。固定 32dp 时，系统字号放大到约 1.5 倍以上标签文字会被截断。
  static double chipExtentFor(TextScaler scaler) =>
      math.max(chipExtent, scaler.scale(16) + 16);
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

  /// 排在清除按钮前面的前置项；高度与标签胶囊相同。
  final Widget? leading;

  /// [leading] 的固有宽度：展开成多行时按它排版（收起时取实际宽度）。
  final double leadingWidth;

  /// 没有标签也没有已选筛选时仍然显示（给 [leading] 留位置）。
  final bool keepVisible;

  @override
  State<DiaryTagFilterBar> createState() => _DiaryTagFilterBarState();
}

class _DiaryTagFilterBarState extends State<DiaryTagFilterBar> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final GlobalKey _clearKey = GlobalKey();
  final TagFilterLayoutCache _layoutCache = TagFilterLayoutCache();
  double _contentWidth = 0;
  double _chipExtent = DiaryTagFilterBar.chipExtent;
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
    _chipExtent = DiaryTagFilterBar.chipExtentFor(
      MediaQuery.textScalerOf(context),
    );
    final collapsedTags = _buildCollapsedTags();

    // 显隐会推动下方列表，不能在一帧内出现/消失；ListItemPresence 结构恒定，
    // 切换时标签栏子树（滚动位置、清除按钮状态）不会被重新挂载。
    return ListItemPresence(
      visible:
          widget.tags.isNotEmpty ||
          widget.selectedTagFilterIds.isNotEmpty ||
          widget.keepVisible,
      appearing: false,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      child: _buildBar(collapsedTags),
    );
  }

  Widget _buildBar(Widget collapsedTags) {
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
          leadingWidth: widget.leading == null ? 0 : widget.leadingWidth,
        );
        _expandedRowsExtent = layout.visibleRowsExtent(
          rowHeight: _chipExtent,
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
            expandedContentExtent - _chipExtent,
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
                    _chipExtent +
                    (expandedContentExtent - _chipExtent) * normalizedProgress;
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
        startPosition.dy > _chipExtent + AppSpacing.xs) {
      return false;
    }
    return position.maxScrollExtent > position.minScrollExtent;
  }

  Widget _buildCollapsedTags() {
    return DesktopHorizontalScroll(
      child: ListView.separated(
        key: const PageStorageKey<String>('diary_tag_filter_horizontal'),
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.tags.length + 1 + (widget.leading == null ? 0 : 1),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
        // 有前置项时整体后移一位：-1 为前置项，0 为清除按钮。
        itemBuilder: (BuildContext context, int index) =>
            _buildTagItem(widget.leading == null ? index : index - 1),
      ),
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
              rowHeight: _chipExtent,
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

  /// “控件”为玻璃时的材质；经典时为 null（胶囊照旧用标签色浅底）。
  AppGlassResolved? get _glass {
    final glass = AppGlass.of(context);
    return glass.isGlass(AppGlassComponent.controls) ? glass : null;
  }

  Widget _buildTagItem(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = widget.selectedTagFilterIds.isNotEmpty;
    if (index < 0) {
      return Center(
        child: SizedBox(height: _chipExtent, child: widget.leading),
      );
    }
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

    // “控件”为玻璃时，未选中胶囊的底色换成玻璃底色（半透明的中性色，高
    // 对比度时为不透明等效色），标签色只留在色点与描边上；选中态在同一块
    // 玻璃底色上叠标签色浅底，加上满色 2dp 描边，仍一眼可辨。不模糊：标签
    // 栏挂在刊头下面，那条栏是否模糊由导航栏样式决定，这里再加一层模糊就
    // 成了同一区域两层模糊（刊头恰好两块启用的 BackdropFilter 由测试兜底）。
    final glass = _glass;
    final unselectedBg =
        glass?.fill ?? tagColor.withValues(alpha: isLight ? 0.08 : 0.16);
    final unselectedBorder = tagColor.withValues(alpha: isLight ? 0.22 : 0.32);
    final unselectedText = colorScheme.onSurface;

    final tagTint = tagColor.withValues(alpha: isLight ? 0.22 : 0.36);
    final selectedBg = glass == null
        ? tagTint
        : Color.alphaBlend(tagTint, glass.fill);
    final selectedBorder = tagColor;
    final selectedText = isLight
        ? (ThemeData.estimateBrightnessForColor(tagColor) == Brightness.dark
              ? tagColor
              : colorScheme.onSurface)
        : colorScheme.onSurface;

    // A horizontal ListView supplies a tight chip-extent cross-axis constraint, but a
    // Multi-row layout otherwise uses the chip's smaller intrinsic height. Retain that same
    // constraint here so expansion changes only positions, never card styling.
    return SizedBox(
      height: _chipExtent,
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
