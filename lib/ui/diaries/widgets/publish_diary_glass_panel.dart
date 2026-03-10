import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';

/// 发布页底部玻璃悬浮面板（smooth_sheets 版）。
///
/// 交互目标：
/// - 收起态更窄、位置更高；
/// - 仅支持上划手势展开；
/// - 上划过程中尺寸连续变化，松手后自然吸附到展开/收起状态。
class PublishDiaryGlassPanel extends StatefulWidget {
  const PublishDiaryGlassPanel({
    super.key,
    this.controller,
    required this.saving,
    required this.bottomInset,
    required this.hasCover,
    required this.coverLabel,
    required this.locating,
    required this.weatherLoading,
    required this.locationLabel,
    required this.weatherController,
    required this.moodEmoji,
    required this.energyLevel,
    required this.tags,
    required this.tagsLoading,
    required this.tagsError,
    required this.selectedTagIds,
    required this.onPickCover,
    required this.onResolveLocation,
    required this.onResolveWeather,
    required this.onCreateTag,
    required this.onToggleTag,
    required this.onMoodChanged,
    required this.onEnergyChanged,
    required this.onPublish,
    this.onProgressChanged,
    this.onClearCover,
  });

  static const List<String> moodOptions = <String>[
    '😭',
    '😢',
    '😞',
    '😕',
    '😐',
    '🙂',
    '😊',
    '😄',
    '😀',
    '🤩',
  ];

  final PublishDiaryGlassPanelController? controller;
  final bool saving;
  final double bottomInset;
  final bool hasCover;
  final String? coverLabel;
  final bool locating;
  final bool weatherLoading;
  final String? locationLabel;
  final TextEditingController weatherController;
  final String? moodEmoji;
  final int energyLevel;
  final List<Tag> tags;
  final bool tagsLoading;
  final String? tagsError;
  final Set<int> selectedTagIds;
  final VoidCallback onPickCover;
  final VoidCallback onResolveLocation;
  final VoidCallback onResolveWeather;
  final VoidCallback onCreateTag;
  final void Function(int tagId, bool selected) onToggleTag;
  final ValueChanged<String?> onMoodChanged;
  final ValueChanged<double> onEnergyChanged;
  final VoidCallback onPublish;
  final ValueChanged<double>? onProgressChanged;
  final VoidCallback? onClearCover;

  @override
  State<PublishDiaryGlassPanel> createState() => _PublishDiaryGlassPanelState();
}

/// 发布页悬浮面板控制器。
///
/// 提供给页面级返回逻辑使用：
/// - 判断面板是否处于展开状态；
/// - 主动触发面板收起动画。
class PublishDiaryGlassPanelController {
  _PublishDiaryGlassPanelState? _state;

  bool get isExpanded => _state?._isExpandedForBackAction ?? false;
  bool get canPopInnerPage => _state?._canPopInnerPage ?? false;

  Future<void> collapse() {
    return _state?._collapseToMin() ?? Future<void>.value();
  }

  Future<bool> popInnerPage() {
    return _state?._popInnerPage() ?? Future<bool>.value(false);
  }

  void _attach(_PublishDiaryGlassPanelState state) {
    _state = state;
  }

  void _detach(_PublishDiaryGlassPanelState state) {
    if (_state == state) {
      _state = null;
    }
  }
}

class _PublishDiaryGlassPanelState extends State<PublishDiaryGlassPanel> {
  static const double _collapsedHeight = 64;
  static const double _mainExpandedHeight = 470;
  static const double _tagExpandedHeight = 540;
  static const double _collapsedHorizontalInset = 40;
  static const double _expandedHorizontalInset = 2;
  static const double _collapsedExtraLift = 18;

  late final SheetController _sheetController;
  late final PageController _contentPageController;
  double _progress = 0;
  int _contentPageIndex = 0;

  double get _activeExpandedHeight =>
      _contentPageIndex == 1 ? _tagExpandedHeight : _mainExpandedHeight;

  double get _collapsedFactor => _collapsedHeight / _activeExpandedHeight;

  bool get _isExpandedForBackAction => _progress > 0.06;
  bool get _canPopInnerPage => _contentPageIndex > 0;

  @override
  void initState() {
    super.initState();
    _sheetController = SheetController();
    _contentPageController = PageController();
    _sheetController.addListener(_handleSheetMetricsChanged);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant PublishDiaryGlassPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _sheetController.removeListener(_handleSheetMetricsChanged);
    _sheetController.dispose();
    _contentPageController.dispose();
    super.dispose();
  }

  Future<void> _collapseToMin() async {
    if (_canPopInnerPage) {
      await _popInnerPage(animated: false);
    }
    if (!_sheetController.hasClient) {
      return;
    }
    await _sheetController.animateTo(
      SheetOffset(_collapsedFactor),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openTagPage() async {
    if (_contentPageIndex == 1 || !_contentPageController.hasClients) {
      return;
    }
    await _contentPageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<bool> _popInnerPage({bool animated = true}) async {
    if (!_canPopInnerPage || !_contentPageController.hasClients) {
      return false;
    }
    if (animated) {
      await _contentPageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return true;
    }
    _contentPageController.jumpToPage(0);
    if (mounted) {
      setState(() => _contentPageIndex = 0);
    }
    return true;
  }

  void _handleSheetMetricsChanged() {
    final nextProgress = _resolveProgress(_sheetController.metrics);
    if ((nextProgress - _progress).abs() < 0.0001) {
      return;
    }

    void apply() {
      if (!mounted) {
        return;
      }
      if ((nextProgress - _progress).abs() < 0.0001) {
        return;
      }
      setState(() => _progress = nextProgress);
      widget.onProgressChanged?.call(nextProgress);
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
      return;
    }
    apply();
  }

  double _resolveProgress(SheetMetrics? metrics) {
    if (metrics == null) {
      return 0;
    }
    final range = (metrics.maxOffset - metrics.minOffset).abs();
    if (range <= 0) {
      return 0;
    }
    final raw = (metrics.offset - metrics.minOffset) / range;
    return raw.clamp(0.0, 1.0).toDouble();
  }

  String get _energyDescription {
    final level = widget.energyLevel.clamp(1, 5).toInt();
    switch (level) {
      case 1:
        return '很疲惫';
      case 2:
        return '有点累';
      case 3:
        return '状态一般';
      case 4:
        return '精力不错';
      case 5:
      default:
        return '活力满满';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalInset =
        lerpDouble(_collapsedHorizontalInset, _expandedHorizontalInset, _progress)!;
    final extraLift = lerpDouble(_collapsedExtraLift, 0, _progress)!;
    // 避免展开态输入时被键盘整体顶得过高：随展开进度逐步降低键盘抬升量。
    final keyboardLiftFactor = (1 - _progress).clamp(0.0, 1.0).toDouble();
    final keyboardLift = widget.bottomInset * keyboardLiftFactor;
    final baseBottom = keyboardLift > 0 ? keyboardLift + 8 : 10.0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: horizontalInset,
        right: horizontalInset,
        bottom: baseBottom + extraLift,
      ),
      child: SizedBox(
        // SheetViewport 需要有限高度约束，否则会触发布局断言。
        height: _activeExpandedHeight,
        child: SheetViewport(
          child: Sheet(
            controller: _sheetController,
            initialOffset: SheetOffset(_collapsedFactor),
            physics: const BouncingSheetPhysics(
              spring: SpringDescription(
                mass: 0.62,
                stiffness: 190,
                damping: 19,
              ),
              bounceExtent: 92,
              resistance: 7.2,
            ),
            snapGrid: MultiSnapGrid(
              snaps: <SheetOffset>[
                SheetOffset(_collapsedFactor),
                const SheetOffset(1),
              ],
              minFlingSpeed: 580,
            ),
            decoration: SheetDecorationBuilder(
              size: SheetSize.fit,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.nav),
                    boxShadow: AppEffects.softShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.nav),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 15,
                        sigmaY: 15,
                        tileMode: TileMode.mirror,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(20),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            child: SizedBox(
              width: double.infinity,
              height: _activeExpandedHeight,
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return PageView(
      controller: _contentPageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        if (_contentPageIndex == index) {
          return;
        }
        setState(() => _contentPageIndex = index);
      },
      children: <Widget>[
        _buildMainPanelPage(context),
        _buildTagPanelPage(context),
      ],
    );
  }

  Widget _buildMainPanelPage(BuildContext context) {
    return _buildPanelPageScaffold(
      context: context,
      header: _buildMainHeader(context),
      content: _buildMainContentPage(context),
    );
  }

  Widget _buildMainContentPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildCoverEntryTile(context),
          const SizedBox(height: 14),
          _buildTagEntryTile(context),
          const SizedBox(height: 14),
          _buildContextFields(context),
          const SizedBox(height: 14),
          _buildMoodSection(context),
          const SizedBox(height: 14),
          _buildEnergySection(context),
          const SizedBox(height: 14),
          _buildPublishAction(),
        ],
      ),
    );
  }

  Widget _buildTagPanelPage(BuildContext context) {
    return _buildPanelPageScaffold(
      context: context,
      header: _buildTagHeader(context),
      content: _buildTagManagePage(context),
    );
  }

  Widget _buildPanelPageScaffold({
    required BuildContext context,
    required Widget header,
    required Widget content,
  }) {
    final detailsOpacity = ((_progress - 0.15) / 0.85).clamp(0.0, 1.0).toDouble();
    final dividerColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.5);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          top: _collapsedHeight + 1,
          child: ClipRect(
            child: IgnorePointer(
              // 只在展开到一定程度后开放内部交互，避免半展开误触。
              ignoring: _progress < 0.58,
              child: Opacity(
                opacity: detailsOpacity,
                child: content,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              header,
              Divider(height: 1, color: dividerColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagManagePage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: widget.onCreateTag,
                icon: const FaIcon(FontAwesomeIcons.plus, size: 12),
                label: const Text('新建'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTagManageContent(context),
        ],
      ),
    );
  }

  Widget _buildMainHeader(BuildContext context) {
    final isCollapsedVisual = _progress < 0.56;
    final icon =
        isCollapsedVisual ? FontAwesomeIcons.anglesUp : FontAwesomeIcons.anglesDown;
    final title = isCollapsedVisual ? '上划展开' : '下滑收起';
    return SizedBox(
      height: _collapsedHeight,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FaIcon(icon, size: 14),
            const SizedBox(width: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagHeader(BuildContext context) {
    return SizedBox(
      height: _collapsedHeight,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () {
              _popInnerPage();
            },
            icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 14),
            tooltip: '返回',
          ),
          Expanded(
            child: Center(
              child: Text(
                '选择标签',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCoverEntryTile(BuildContext context) {
    final coverText =
        widget.hasCover && widget.coverLabel != null
            ? widget.coverLabel!
            : '点击选择封面（可选）';
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        onTap: widget.onPickCover,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: <Widget>[
                Text(
                  '封面',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    coverText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (widget.hasCover && widget.onClearCover != null) ...<Widget>[
                  IconButton(
                    onPressed: widget.onClearCover,
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 12),
                    visualDensity: VisualDensity.compact,
                    tooltip: '清除封面',
                  ),
                ],
                const SizedBox(width: 6),
                const FaIcon(FontAwesomeIcons.chevronRight, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagEntryTile(BuildContext context) {
    final selectedTags =
        widget.tags.where((tag) => widget.selectedTagIds.contains(tag.id)).toList();

    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        onTap: _openTagPage,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: <Widget>[
                Text(
                  '标签',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: selectedTags.isEmpty
                      ? Text(
                          '未选择标签',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: selectedTags
                                .map(
                                  (tag) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: RawChip(
                                      visualDensity: VisualDensity.compact,
                                      side: BorderSide.none,
                                      elevation: 0,
                                      pressElevation: 0,
                                      shadowColor: Colors.transparent,
                                      shape: const StadiumBorder(),
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      label: Text(
                                        tag.name,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      avatar: CircleAvatar(
                                        radius: 7,
                                        backgroundColor: Color(tag.color),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                const FaIcon(FontAwesomeIcons.chevronRight, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagManageContent(BuildContext context) {
    if (widget.tagsLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (widget.tagsError != null) {
      return Text(
        '标签加载失败: ${widget.tagsError}',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (widget.tags.isEmpty) {
      return Text(
        '暂无标签，可先创建',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      children: widget.tags
          .map((tag) => _buildTagListRow(context, tag: tag))
          .toList(growable: false),
    );
  }

  Widget _buildTagListRow(BuildContext context, {required Tag tag}) {
    final selected = widget.selectedTagIds.contains(tag.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onToggleTag(tag.id, !selected),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 8,
                    backgroundColor: Color(tag.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tag.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IgnorePointer(
                    child: Checkbox(
                      value: selected,
                      shape: const CircleBorder(),
                      onChanged: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextFields(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locationLabel = widget.locationLabel?.trim();
    final hasLocation = locationLabel != null && locationLabel.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '此时此地',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
        ),
        const SizedBox(height: 8),
        Material(
          color: colorScheme.surface.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 42),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              child: Row(
                children: <Widget>[
                  const FaIcon(FontAwesomeIcons.locationDot, size: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasLocation ? locationLabel : '点击右侧获取当前地址',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                hasLocation
                                    ? null
                                    : colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.75,
                                    ),
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.locating ? null : widget.onResolveLocation,
                    tooltip: '获取位置',
                    visualDensity: VisualDensity.compact,
                    icon:
                        widget.locating
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const FaIcon(
                              FontAwesomeIcons.locationCrosshairs,
                              size: 14,
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: colorScheme.surface.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 42),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              child: Row(
                children: <Widget>[
                  const FaIcon(FontAwesomeIcons.cloudSun, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.weatherController.text.trim().isEmpty
                          ? '点击右侧获取当前天气'
                          : widget.weatherController.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                widget.weatherController.text.trim().isEmpty
                                    ? colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.75,
                                    )
                                    : null,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        widget.weatherLoading ? null : widget.onResolveWeather,
                    tooltip: '获取天气',
                    visualDensity: VisualDensity.compact,
                    icon:
                        widget.weatherLoading
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const FaIcon(FontAwesomeIcons.cloud, size: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodSection(BuildContext context) {
    const moodColumns = 5;
    const horizontalSpacing = 8.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '心情',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final itemWidth =
                (constraints.maxWidth - horizontalSpacing * (moodColumns - 1)) /
                    moodColumns;
            return Wrap(
              spacing: horizontalSpacing,
              children: PublishDiaryGlassPanel.moodOptions.map((emoji) {
                return SizedBox(
                  width: itemWidth,
                  child: ChoiceChip(
                    showCheckmark: false,
                    side: BorderSide.none,
                    elevation: 0,
                    pressElevation: 0,
                    shadowColor: Colors.transparent,
                    shape: const StadiumBorder(),
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        emoji,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    selected: widget.moodEmoji == emoji,
                    onSelected:
                        (selected) => widget.onMoodChanged(selected ? emoji : null),
                  ),
                );
              }).toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEnergySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '精力',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              _energyDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        Slider(
          value: widget.energyLevel.toDouble().clamp(1.0, 5.0).toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '${widget.energyLevel}',
          onChanged: widget.onEnergyChanged,
        ),
      ],
    );
  }

  Widget _buildPublishAction() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: widget.saving ? null : widget.onPublish,
        icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 13),
        label: Text(widget.saving ? '发布中...' : '点击发表日记'),
      ),
    );
  }
}
