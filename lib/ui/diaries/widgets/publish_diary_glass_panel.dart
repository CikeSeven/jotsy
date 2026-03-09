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
    required this.saving,
    required this.bottomInset,
    required this.hasCover,
    required this.coverLabel,
    required this.locationController,
    required this.weatherController,
    required this.moodEmoji,
    required this.energyLevel,
    required this.tags,
    required this.tagsLoading,
    required this.tagsError,
    required this.selectedTagIds,
    required this.metadataPreview,
    required this.onPickCover,
    required this.onCreateTag,
    required this.onToggleTag,
    required this.onLocationChanged,
    required this.onWeatherChanged,
    required this.onMoodChanged,
    required this.onEnergyChanged,
    required this.onPublish,
    this.onProgressChanged,
    this.onClearCover,
  });

  static const List<String> moodOptions = <String>[
    '😀',
    '🙂',
    '😌',
    '😐',
    '😕',
    '😴',
    '😤',
    '🤩',
  ];

  final bool saving;
  final double bottomInset;
  final bool hasCover;
  final String? coverLabel;
  final TextEditingController locationController;
  final TextEditingController weatherController;
  final String? moodEmoji;
  final int energyLevel;
  final List<Tag> tags;
  final bool tagsLoading;
  final String? tagsError;
  final Set<int> selectedTagIds;
  final String metadataPreview;
  final VoidCallback onPickCover;
  final VoidCallback onCreateTag;
  final void Function(int tagId, bool selected) onToggleTag;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<String> onWeatherChanged;
  final ValueChanged<String?> onMoodChanged;
  final ValueChanged<double> onEnergyChanged;
  final VoidCallback onPublish;
  final ValueChanged<double>? onProgressChanged;
  final VoidCallback? onClearCover;

  @override
  State<PublishDiaryGlassPanel> createState() => _PublishDiaryGlassPanelState();
}

class _PublishDiaryGlassPanelState extends State<PublishDiaryGlassPanel> {
  static const double _collapsedHeight = 64;
  static const double _expandedHeight = 430;
  static const double _collapsedHorizontalInset = 40;
  static const double _expandedHorizontalInset = 16;
  static const double _collapsedExtraLift = 18;
  static const double _collapsedFactor = _collapsedHeight / _expandedHeight;

  late final SheetController _sheetController;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _sheetController = SheetController();
    _sheetController.addListener(_handleSheetMetricsChanged);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_handleSheetMetricsChanged);
    _sheetController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalInset =
        lerpDouble(_collapsedHorizontalInset, _expandedHorizontalInset, _progress)!;
    final extraLift = lerpDouble(_collapsedExtraLift, 0, _progress)!;
    final baseBottom = widget.bottomInset > 0 ? widget.bottomInset + 8 : 10.0;

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
        height: _expandedHeight,
        child: SheetViewport(
          child: Sheet(
            controller: _sheetController,
            initialOffset: const SheetOffset(_collapsedFactor),
            physics: const BouncingSheetPhysics(
              spring: SpringDescription(
                mass: 0.62,
                stiffness: 190,
                damping: 19,
              ),
              bounceExtent: 92,
              resistance: 7.2,
            ),
            snapGrid: const MultiSnapGrid(
              snaps: <SheetOffset>[
                SheetOffset(_collapsedFactor),
                SheetOffset(1),
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
              height: _expandedHeight,
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final detailsOpacity = ((_progress - 0.15) / 0.85).clamp(0.0, 1.0).toDouble();

    return Column(
      children: <Widget>[
        _buildHeader(context),
        Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        Expanded(
          child: IgnorePointer(
            // 只在展开到一定程度后开放内部交互，避免半展开误触。
            ignoring: _progress < 0.58,
            child: Opacity(
              opacity: detailsOpacity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildCoverSection(context),
                    const SizedBox(height: 14),
                    _buildTagSection(context),
                    const SizedBox(height: 14),
                    _buildContextFields(context),
                    const SizedBox(height: 14),
                    _buildMoodSection(context),
                    const SizedBox(height: 14),
                    _buildEnergySection(context),
                    const SizedBox(height: 14),
                    _buildMetadataPreview(context),
                    const SizedBox(height: 14),
                    _buildPublishAction(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
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

  Widget _buildCoverSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '封面',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: widget.onPickCover,
              icon: const FaIcon(FontAwesomeIcons.image, size: 14),
              label: const Text('选择封面'),
            ),
            if (widget.hasCover) ...<Widget>[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: widget.onClearCover,
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 12),
                label: const Text('清除'),
              ),
            ],
          ],
        ),
        if (widget.hasCover && widget.coverLabel != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            widget.coverLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildTagSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '标签',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.onCreateTag,
              icon: const FaIcon(FontAwesomeIcons.plus, size: 12),
              label: const Text('新建'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (widget.tagsLoading)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (widget.tagsError != null)
          Text(
            '标签加载失败: ${widget.tagsError}',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else if (widget.tags.isEmpty)
          Text(
            '暂无标签，可先创建',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: -8,
            children: widget.tags.map((tag) {
              return FilterChip(
                selected: widget.selectedTagIds.contains(tag.id),
                avatar: CircleAvatar(
                  radius: 8,
                  backgroundColor: Color(tag.color),
                ),
                label: Text(tag.name),
                onSelected: (selected) => widget.onToggleTag(tag.id, selected),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildContextFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '环境信息',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.locationController,
          onChanged: widget.onLocationChanged,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '地理位置（手动填写）',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: FaIcon(FontAwesomeIcons.locationDot, size: 14),
            ),
            prefixIconConstraints: BoxConstraints(minHeight: 30, minWidth: 34),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.weatherController,
          onChanged: widget.onWeatherChanged,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '实时天气（手动填写）',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: FaIcon(FontAwesomeIcons.cloudSun, size: 14),
            ),
            prefixIconConstraints: BoxConstraints(minHeight: 30, minWidth: 34),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '情绪',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: -8,
          children: PublishDiaryGlassPanel.moodOptions.map((emoji) {
            return ChoiceChip(
              label: Text(emoji),
              selected: widget.moodEmoji == emoji,
              onSelected: (selected) => widget.onMoodChanged(selected ? emoji : null),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEnergySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '能量水平（1-5）',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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

  Widget _buildMetadataPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Metadata（自动生成）',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96, maxHeight: 140),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              widget.metadataPreview,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
            ),
          ),
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
