import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../home/widgets/home_bar/home_chrome_scope.dart';
import '../../widgets/list_item_presence.dart';
import 'expanded_tag_filter_list.dart';
import 'tag_filter_chip.dart';
import 'tag_filter_clear_button.dart';
import 'tag_filter_collapse_handle.dart';
import 'tag_filter_expansion_gesture.dart';
import 'tag_filter_layout.dart';
import 'tag_filter_pull_hint.dart';
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
/// - 标签区域的拖动不移交给日记滚动或 Home 切页；
/// - 一次性的“下拉展开”提示（[pullHintVisible]）：收着时在标签行下方展开
///   一行 [TagFilterPullHint]，标签栏按 [pullHintPeek] 往下探一段再弹回；
///   收起的一行是否放不下全部标签经 [onHiddenTagsChanged] 回报（时序与记录
///   见 `TagFilterPullHintController`）。
class DiaryTagFilterBar extends StatefulWidget {
  const DiaryTagFilterBar({
    super.key,
    required this.tags,
    required this.expansionProgress,
    required this.canExpand,
    required this.canCollapse,
    required this.selectedTagFilterIds,
    required this.onSelectTag,
    required this.onToggleTagFilter,
    required this.onClearTagFilters,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onCollapse,
    this.leading,
    this.leadingWidth = 0,
    this.keepVisible = false,
    this.pullHintVisible = false,
    this.pullHintPeek,
    this.onPullHintTap,
    this.onHiddenTagsChanged,
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

  /// 下拉提示行的高度：与展开后的收起行同高，两者互为镜像。
  static const double pullHintExtent = collapseHandleExtent;
  static const double maxExpandedBarExtent =
      maxExpandedRowsExtent + collapseHandleExtent + AppSpacing.xs * 2;
  static const collapseHandleKey = ValueKey<String>(
    'diary_tag_collapse_handle',
  );
  static const pullHintKey = ValueKey<String>('diary_tag_pull_hint');

  final List<Tag> tags;
  final ValueListenable<double> expansionProgress;
  final bool Function() canExpand;
  final bool Function() canCollapse;
  final Set<int> selectedTagFilterIds;

  /// 单击标签：只看这一个标签（再点一次取消），见
  /// `DiaryFilterNotifier.selectOnlyTag`。
  final ValueChanged<int> onSelectTag;

  /// 长按标签（桌面上也可以按住 Ctrl / ⌘ 点击）：在已选的标签里加上或去掉
  /// 它，其余保留，多个标签同时满足才显示。
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

  /// 是否显示下拉提示行；为 true 时由 [ListItemPresence] 从 0 高度展开。
  final bool pullHintVisible;

  /// 轻推演示的进度（0 → 1 → 0）：收着的标签栏按它往下探最多一段
  /// 下探距离（约露出第二行的六成），露出被藏起来的标签。
  final Animation<double>? pullHintPeek;

  /// 点按提示行；为 null 时不挂提示行。
  final VoidCallback? onPullHintTap;

  /// 收起的一行是否放不下全部标签（排成多行时多于一行）；布局后、值变化时
  /// 回报。
  final ValueChanged<bool>? onHiddenTagsChanged;

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
  bool _reportedHiddenTags = false;

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
        _reportHiddenTags(layout.rows.length > 1);
        final expandedContentExtent = _expandedContentExtent;
        final expansionTravel = expandedContentExtent - _chipExtent;
        // 下探到第二行的六成左右：看得出下面还有标签，又不像真的展开了。
        final peekExtent = math.min(
          expansionTravel,
          DiaryTagFilterBar._expandedRowSpacing + _chipExtent * 0.6,
        );
        final peek = widget.pullHintPeek;
        return TagFilterExpansionGesture(
          canExpand: () => widget.tags.isNotEmpty && widget.canExpand(),
          canCollapse: _canCollapseFrom,
          allowVerticalScroll: _canScrollVertically,
          allowHorizontalScroll: _canScrollHorizontally,
          onStart: widget.onVerticalDragStart,
          onUpdate: (delta) =>
              widget.onVerticalDragUpdate(delta, expansionTravel),
          onEnd: widget.onVerticalDragEnd,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.xs,
              AppSpacing.m,
              AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListenableBuilder(
                  listenable: peek == null
                      ? widget.expansionProgress
                      : Listenable.merge(<Listenable>[
                          widget.expansionProgress,
                          peek,
                        ]),
                  child: _buildExpandedTags(layout),
                  builder: (BuildContext context, Widget? child) {
                    final normalizedProgress = widget.expansionProgress.value
                        .clamp(0.0, 1.0);
                    // 轻推与展开共用同一套“展开排版 + 裁切”：弹簧过冲时下探
                    // 可能略低于 0 或越过落点，夹在收起与完全展开之间。
                    final extraHeight =
                        (expansionTravel * normalizedProgress +
                                peekExtent * (peek?.value ?? 0))
                            .clamp(0.0, math.max(0.0, expansionTravel));
                    final contentHeight = _chipExtent + extraHeight;
                    final showExpandedLayout = extraHeight > 0;
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
                if (widget.onPullHintTap != null) _buildPullHint(peek),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 提示行挂在内容下方：判断拖动起点的几个方法都按距顶部的距离算，
  /// 不受它影响；收着时在提示行上下拉同样会展开。不可见时不接收指针与
  /// 焦点，键盘遍历不会停在一行看不见的提示上（淡出到 0 后语义也随之排除）。
  Widget _buildPullHint(Animation<double>? peek) {
    final visible = widget.pullHintVisible;
    return ListItemPresence(
      visible: visible,
      appearing: false,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeFocus(
          excluding: !visible,
          child: SizedBox(
            height: DiaryTagFilterBar.pullHintExtent,
            child: TagFilterPullHint(
              key: DiaryTagFilterBar.pullHintKey,
              count: widget.tags.length,
              peek: peek,
              onTap: widget.onPullHintTap!,
            ),
          ),
        ),
      ),
    );
  }

  /// 布局阶段算出、帧末回报：回调里会改父级状态，不能在布局中途调用。
  void _reportHiddenTags(bool hasHiddenTags) {
    final callback = widget.onHiddenTagsChanged;
    if (callback == null || hasHiddenTags == _reportedHiddenTags) return;
    _reportedHiddenTags = hasHiddenTags;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onHiddenTagsChanged?.call(_reportedHiddenTags);
    });
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
    // 成了同一区域两层模糊（整条顶栏只有一块启用的 BackdropFilter，由测试
    // 兜底）。
    //
    // 首页顶栏自上而下渐变时，标签栏落在玻璃淡出的下半截，背后是滚上来的
    // 原样内容：胶囊改垫栏自己的颜色、几乎不透明的底（topBarControlFill），
    // 再按上面的规则叠标签色，否则淡底跟着玻璃一起看不见。
    final glass = _glass;
    final barStyle = HomeChromeScope.maybeStyleOf(context);
    final Color? base = barStyle != null && barStyle.topBarFades
        ? barStyle.topBarControlFill
        : glass?.fill;
    final classicTint = tagColor.withValues(alpha: isLight ? 0.08 : 0.16);
    final Color unselectedBg;
    if (base == null) {
      unselectedBg = classicTint;
    } else if (glass == null) {
      // 经典控件：保留标签色浅底，只是垫在实底上。
      unselectedBg = Color.alphaBlend(classicTint, base);
    } else {
      unselectedBg = base;
    }
    final unselectedBorder = tagColor.withValues(alpha: isLight ? 0.22 : 0.32);
    final unselectedText = colorScheme.onSurface;

    final tagTint = tagColor.withValues(alpha: isLight ? 0.22 : 0.36);
    final selectedBg = base == null ? tagTint : Color.alphaBlend(tagTint, base);
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
        onTap: () {
          // 键鼠专属：桌面上按住 Ctrl / ⌘ 点击与长按相同（只在桌面生效，
          // 手机外接键盘时单击照旧只切换）。
          final keyboard = HardwareKeyboard.instance;
          if (AppPlatform.isDesktop &&
              (keyboard.isControlPressed || keyboard.isMetaPressed)) {
            widget.onToggleTagFilter(tag.id, !selected);
            return;
          }
          widget.onSelectTag(tag.id);
        },
        onLongPress: () => widget.onToggleTagFilter(tag.id, !selected),
        longPressHint: context.l10n.diaryTagFilterMultiSelectSemanticHint,
      ),
    );
  }
}
