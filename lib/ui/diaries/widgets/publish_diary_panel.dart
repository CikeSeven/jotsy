import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/publish_panel_coordinator.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/qweather_icon.dart';
import 'energy_battery_indicator.dart';
import 'publish_location_precision_picker.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

/// 发布页底部悬浮面板（smooth_sheets 版）。
///
/// 交互目标：
/// - 收起态更窄、位置更高；
/// - 支持上划与点击展开；
/// - 上划过程中尺寸连续变化，松手后自然吸附到展开/收起状态。
class PublishDiaryPanel extends StatefulWidget {
  const PublishDiaryPanel({
    super.key,
    this.controller,
    required this.saving,
    required this.hasCover,
    required this.coverLabel,
    required this.locating,
    required this.weatherLoading,
    required this.locationController,
    this.locationPrecision = DiaryLocationPrecision.township,
    this.locationAddressComponent,
    this.onLocationPrecisionChanged,
    this.showPublishTimeOption = false,
    this.publishTimeLabel,
    this.onPickPublishTime,
    this.showTimeCapsuleOption = false,
    this.timeCapsuleLabel,
    this.timeCapsuleActive = false,
    this.timeCapsuleSchedule,
    this.onTimeCapsuleChanged,
    this.onClearTimeCapsule,
    required this.weatherController,
    required this.weatherIconCode,
    required this.moodEmoji,
    this.energyLevel,
    required this.tags,
    required this.tagsLoading,
    required this.tagsError,
    required this.selectedTagIds,
    required this.onPickCover,
    required this.onResolveLocation,
    required this.onResolveWeather,
    required this.onLocationChanged,
    required this.onWeatherChanged,
    required this.onCreateTag,
    required this.onToggleTag,
    required this.onMoodChanged,
    required this.onEnergyChanged,
    this.onPublish,
    this.actionLabel = '',
    this.onProgressChanged,
    this.onClearCover,
    this.moodOptions = const <String>[],
  });

  /// 默认心情候选列表：从低落到高兴，固定两行展示。
  static const List<String> defaultMoodOptions =
      SettingsService.defaultMoodOptions;

  final PublishDiaryPanelController? controller;
  final bool saving;
  final bool hasCover;
  final String? coverLabel;
  final bool locating;
  final bool weatherLoading;
  final TextEditingController locationController;
  final DiaryLocationPrecision locationPrecision;

  /// 自动定位的地址组件，只用于层级菜单预览；手动地点或未定位时传 null。
  final Map<String, Object?>? locationAddressComponent;
  final ValueChanged<DiaryLocationPrecision>? onLocationPrecisionChanged;
  final bool showPublishTimeOption;
  final String? publishTimeLabel;
  final VoidCallback? onPickPublishTime;
  final bool showTimeCapsuleOption;
  final String? timeCapsuleLabel;
  final bool timeCapsuleActive;
  final TimeCapsuleSchedule? timeCapsuleSchedule;
  final ValueChanged<TimeCapsuleSchedule>? onTimeCapsuleChanged;
  final VoidCallback? onClearTimeCapsule;
  final TextEditingController weatherController;
  final String? weatherIconCode;
  final String? moodEmoji;
  final double? energyLevel;
  final List<Tag> tags;
  final bool tagsLoading;
  final String? tagsError;
  final Set<int> selectedTagIds;
  final VoidCallback onPickCover;
  final VoidCallback onResolveLocation;
  final VoidCallback onResolveWeather;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<String> onWeatherChanged;
  final VoidCallback onCreateTag;
  final void Function(int tagId, bool selected) onToggleTag;
  final ValueChanged<String?> onMoodChanged;
  final ValueChanged<double?> onEnergyChanged;

  /// 编辑页自动保存时不传主操作，发布页仍显示发布按钮。
  final VoidCallback? onPublish;
  final String actionLabel;
  final ValueChanged<double>? onProgressChanged;
  final VoidCallback? onClearCover;
  final List<String> moodOptions;

  @override
  State<PublishDiaryPanel> createState() => _PublishDiaryPanelState();
}

/// 发布页悬浮面板控制器。
///
/// 提供给页面级返回逻辑使用：
/// - 判断面板是否处于展开状态；
/// - 主动触发面板收起动画。
class PublishDiaryPanelController {
  _PublishDiaryPanelState? _state;

  /// 是否处于“返回键应优先收起面板”的展开状态。
  bool get isExpanded => _state?._isExpandedForBackAction ?? false;

  /// 是否位于内部子页（标签页），返回键应先回主页。
  bool get canPopInnerPage => _state?._canPopInnerPage ?? false;

  Future<void> collapse() {
    return _state?._collapseToMin() ?? Future<void>.value();
  }

  Future<bool> popInnerPage() {
    return _state?._popInnerPage() ?? Future<bool>.value(false);
  }

  void _attach(_PublishDiaryPanelState state) {
    _state = state;
  }

  void _detach(_PublishDiaryPanelState state) {
    if (_state == state) {
      _state = null;
    }
  }
}

class _PublishDiaryPanelState extends State<PublishDiaryPanel> {
  // ==================== 尺寸参数（收起/展开/布局） ====================
  static const double _collapsedHeight = 56;
  static const double _mainExpandedHeight = 470;
  static const double _tagExpandedHeight = 540;
  static const double _capsuleExpandedHeight = 540;
  static const double _collapsedHorizontalInset = 40;
  static const double _expandedHorizontalInset = 2;
  static const double _collapsedExtraLift = 18;
  static const double _collapsedBottomGap = 10;

  // ==================== 交互状态机协调器 ====================
  late final PublishPanelCoordinator _panelCoordinator;
  late DateTime _pendingCapsuleUnlockAt;
  late TimeCapsulePrecision _pendingCapsulePrecision;
  // 打开胶囊页时冻结的“现在”：选择器的上下限按它算，不在每次构建时
  // 重取，否则滚轮停在下限、过一分钟再重建时初始值会早于新下限而断言。
  late DateTime _capsulePickerNow;
  // CupertinoDatePicker 只在创建时读取初始值与模式：快捷预设、打开页面时
  // 递增它换 key 重建，让滚轮跳到新值（精度变化同样在 key 里）。
  int _capsulePickerGeneration = 0;
  double _lastEnergyLevel = 4;

  /// 展开进度（0=收起，1=展开）的可监听副本。
  ///
  /// 拖拽面板时进度逐帧变化：只让依赖进度的局部（宽度内缩与抬升、详情淡入与
  /// 可交互阈值、表头箭头与文案）跟随重建，三张子页的内容子树保持不变，不再
  /// 每帧整面板 setState。只在 [_handleSheetMetricsChanged] 确认处于非构建/
  /// 布局阶段后写入，监听者可以安全地标脏重建。
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  double get _activeExpandedHeight => _panelCoordinator.activeExpandedHeight;

  double get _collapsedFactor => _collapsedHeight / _activeExpandedHeight;

  bool get _isExpandedForBackAction =>
      _panelCoordinator.isExpandedForBackAction;
  bool get _canPopInnerPage => _panelCoordinator.canPopInnerPage;

  @override
  void initState() {
    super.initState();
    if (widget.energyLevel != null) {
      _lastEnergyLevel = widget.energyLevel!;
    }
    _panelCoordinator = PublishPanelCoordinator(
      collapsedHeight: _collapsedHeight,
      mainExpandedHeight: _mainExpandedHeight,
      tagExpandedHeight: _tagExpandedHeight,
      capsuleExpandedHeight: _capsuleExpandedHeight,
      resolveDuration: (token) => ExpressiveMotion.duration(context, token),
    );
    _resetPendingCapsuleDraft();
    _panelCoordinator.sheetController.addListener(_handleSheetMetricsChanged);
    // 将状态对象挂到外部 controller，供页面层返回键逻辑调用。
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant PublishDiaryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.energyLevel != null) {
      _lastEnergyLevel = widget.energyLevel!;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _panelCoordinator.sheetController.removeListener(
      _handleSheetMetricsChanged,
    );
    _panelCoordinator.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _collapseToMin() async {
    await _panelCoordinator.collapseToMin();
  }

  Future<void> _expandToMax() async {
    await _panelCoordinator.expandToMax();
  }

  Future<void> _openTagPage() async {
    await _panelCoordinator.openTagPage();
  }

  Future<void> _openCapsulePage() async {
    _resetPendingCapsuleDraft();
    await _panelCoordinator.openCapsulePage();
  }

  Future<bool> _popInnerPage({bool animated = true}) async {
    final popped = await _panelCoordinator.popInnerPage(animated: animated);
    if (popped && mounted) {
      setState(() {});
    }
    return popped;
  }

  void _resetPendingCapsuleDraft() {
    final now = DateTime.now();
    final schedule = widget.timeCapsuleSchedule;
    _capsulePickerNow = now;
    _pendingCapsulePrecision = schedule?.precision ?? TimeCapsulePrecision.date;
    _pendingCapsuleUnlockAt = TimeCapsuleSchedule.initialPendingUnlockAt(
      schedule,
      now,
    );
    _capsulePickerGeneration++;
  }

  DateTime _clampPendingUnlockAt(DateTime value, {DateTime? now}) =>
      TimeCapsuleSchedule.clampUnlockAt(
        value,
        precision: _pendingCapsulePrecision,
        now: now ?? _capsulePickerNow,
      );

  void _applyCapsulePreset(TimeCapsulePreset preset) {
    setState(() {
      _pendingCapsuleUnlockAt = _clampPendingUnlockAt(
        TimeCapsuleSchedule.presetUnlockAt(preset, DateTime.now()),
      );
      _capsulePickerGeneration++;
    });
  }

  void _changeCapsulePrecision(TimeCapsulePrecision precision) {
    setState(() {
      _pendingCapsulePrecision = precision;
      // 分钟 → 日期时下限推到明天零点，先夹到范围内再交给新选择器。
      _pendingCapsuleUnlockAt = _clampPendingUnlockAt(_pendingCapsuleUnlockAt);
    });
  }

  Future<void> _confirmCapsuleSchedule() async {
    widget.onTimeCapsuleChanged?.call(
      TimeCapsuleSchedule(
        // 在选择页停留期间下限可能已经过去（滚轮停在最早一分钟/明天）：按
        // 确认这一刻重新夹一次，用户选的“最早”仍是最早，而不是过去的时刻。
        unlockAt: _clampPendingUnlockAt(
          _pendingCapsuleUnlockAt,
          now: DateTime.now(),
        ),
        precision: _pendingCapsulePrecision,
      ),
    );
    await _popInnerPage();
  }

  /// 监听 sheet 拖拽进度，回写本地状态并向外透传进度。
  void _handleSheetMetricsChanged() {
    final changed = _panelCoordinator.syncProgressFromMetrics(
      _panelCoordinator.sheetController.metrics,
    );
    if (!changed) {
      return;
    }

    void apply() {
      if (!mounted) {
        return;
      }
      _progress.value = _panelCoordinator.progress;
      widget.onProgressChanged?.call(_panelCoordinator.progress);
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
      return;
    }
    apply();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final panelBackgroundColor = Color.alphaBlend(
      colorScheme.primary.withValues(
        alpha: theme.brightness == Brightness.light ? 0.04 : 0.10,
      ),
      colorScheme.surfaceContainerHighest,
    );
    // 1) 不叠加键盘高度：宿主页 Scaffold 默认 resizeToAvoidBottomInset，body
    //    底边已经是键盘顶边，面板以 Positioned(bottom: 0) 挂在 body 内；再加
    //    viewInsets 会抬升两倍键盘高度（收起态会悬在键盘上方 300+dp）。
    // 2) 用普通 Padding 而非 AnimatedPadding：内缩量由拖拽进度逐帧给出，
    //    AnimatedPadding 每帧被重新定向，会让面板宽度滞后于手指。
    // 3) 只有这层 Padding 随进度重建，面板本体作为缓存的 child 传入。
    return ValueListenableBuilder<double>(
      valueListenable: _progress,
      builder: (BuildContext context, double progress, Widget? child) {
        // 面板展开时变宽，收起时变窄，形成“悬浮卡片展开”感。
        final horizontalInset = lerpDouble(
          _collapsedHorizontalInset,
          _expandedHorizontalInset,
          progress,
        )!;
        final extraLift = lerpDouble(_collapsedExtraLift, 0, progress)!;
        return Padding(
          padding: EdgeInsets.only(
            left: horizontalInset,
            right: horizontalInset,
            bottom: _collapsedBottomGap + extraLift,
          ),
          child: child,
        );
      },
      child: SizedBox(
        // SheetViewport 需要有限高度约束，否则会触发布局断言。
        height: _activeExpandedHeight,
        child: SheetViewport(
          child: Sheet(
            controller: _panelCoordinator.sheetController,
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
            // 面板容器：圆角 + 阴影 + 半透明描边。
            decoration: SheetDecorationBuilder(
              size: SheetSize.fit,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.nav),
                    boxShadow: AppEffects.softShadow(colorScheme),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.nav),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: panelBackgroundColor,
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                      child: Material(color: Colors.transparent, child: child),
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
    // 面板内部使用 PageView 管理“主页面/标签管理页”，只允许代码切页。
    return PageView(
      controller: _panelCoordinator.contentPageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        if (!_panelCoordinator.setContentPageIndex(index)) {
          return;
        }
        setState(() {});
      },
      children: <Widget>[
        _buildMainPanelPage(context),
        _buildTagPanelPage(context),
        _buildCapsulePanelPage(context),
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
    // 主页面内容顺序：封面 -> 标签 -> 环境信息 -> 心情 -> 精力 -> 发布按钮。
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
          if (widget.showPublishTimeOption) ...<Widget>[
            const SizedBox(height: 14),
            _buildPublishTimeEntryTile(context),
          ],
          if (widget.showTimeCapsuleOption) ...<Widget>[
            const SizedBox(height: 14),
            _buildTimeCapsuleEntryTile(context),
          ],
          const SizedBox(height: 14),
          _buildMoodSection(context),
          const SizedBox(height: 14),
          _buildEnergySection(context),
          if (widget.onPublish != null) ...<Widget>[
            const SizedBox(height: 14),
            _buildPublishAction(context),
          ],
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

  Widget _buildCapsulePanelPage(BuildContext context) {
    return _buildPanelPageScaffold(
      context: context,
      header: _buildCapsuleHeader(context),
      content: _buildCapsuleManagePage(context),
    );
  }

  Widget _buildPanelPageScaffold({
    required BuildContext context,
    required Widget header,
    required Widget content,
  }) {
    final dividerColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.5);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          top: _collapsedHeight + 1,
          child: ClipRect(
            // 拖拽中只重建淡入层与交互开关，子页内容作为缓存 child 不随进度重建。
            child: ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (BuildContext context, double progress, Widget? child) {
                final detailsOpacity = ((progress - 0.15) / 0.85)
                    .clamp(0.0, 1.0)
                    .toDouble();
                return IgnorePointer(
                  // 只在展开到一定程度后开放内部交互，避免半展开误触。
                  ignoring: progress < 0.58,
                  child: Opacity(opacity: detailsOpacity, child: child),
                );
              },
              child: content,
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
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 标签页顶部“新建”入口，视觉与标签项保持同体系卡片。
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: InkWell(
                onTap: widget.onCreateTag,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const FaIcon(FontAwesomeIcons.plus, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          l10n.autoT0157,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildTagManageContent(context),
        ],
      ),
    );
  }

  Widget _buildCapsuleManagePage(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final precision = _pendingCapsulePrecision;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ActionChip(
                label: Text(l10n.timeCapsuleQuickWeek),
                onPressed: () => _applyCapsulePreset(TimeCapsulePreset.week),
              ),
              ActionChip(
                label: Text(l10n.timeCapsuleQuickMonth),
                onPressed: () => _applyCapsulePreset(TimeCapsulePreset.month),
              ),
              ActionChip(
                label: Text(l10n.timeCapsuleQuickYear),
                onPressed: () => _applyCapsulePreset(TimeCapsulePreset.year),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ExpressiveButtonGroup<TimeCapsulePrecision>(
            segments: <ButtonSegment<TimeCapsulePrecision>>[
              ButtonSegment<TimeCapsulePrecision>(
                value: TimeCapsulePrecision.date,
                label: Text(l10n.timeCapsulePrecisionDate),
              ),
              ButtonSegment<TimeCapsulePrecision>(
                value: TimeCapsulePrecision.minute,
                label: Text(l10n.timeCapsulePrecisionMinute),
              ),
            ],
            selected: <TimeCapsulePrecision>{precision},
            onSelectionChanged: (values) =>
                _changeCapsulePrecision(values.single),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 184,
            child: CupertinoDatePicker(
              key: ValueKey<(TimeCapsulePrecision, int)>((
                precision,
                _capsulePickerGeneration,
              )),
              // “只按日期”只给日期滚轮，避免让用户调一个会被丢掉的时分。
              mode: precision == TimeCapsulePrecision.date
                  ? CupertinoDatePickerMode.date
                  : CupertinoDatePickerMode.dateAndTime,
              minimumDate: TimeCapsuleSchedule.earliestUnlockAt(
                precision,
                _capsulePickerNow,
              ),
              maximumDate: TimeCapsuleSchedule.latestUnlockAt(
                _capsulePickerNow,
              ),
              initialDateTime: _clampPendingUnlockAt(_pendingCapsuleUnlockAt),
              use24hFormat: true,
              onDateTimeChanged: (value) => _pendingCapsuleUnlockAt = value,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: _popInnerPage,
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: widget.onTimeCapsuleChanged == null
                      ? null
                      : _confirmCapsuleSchedule,
                  child: Text(l10n.commonConfirm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainHeader(BuildContext context) {
    final l10n = context.l10n;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    final reduceMotion = ExpressiveMotion.reduceMotion(context);
    return SizedBox(
      height: _collapsedHeight,
      child: ValueListenableBuilder<double>(
        valueListenable: _progress,
        builder: (BuildContext context, double progress, Widget? _) {
          final isCollapsedVisual = progress < 0.56;
          // 箭头随拖拽进度连续翻转：纵向缩放 1 → -1，上指的双箭头先压扁成一道
          // 横线再翻成下指，跟手且不会在越过阈值的那一帧突然掉头；文案仍按
          // 阈值切换，用短交叉淡入衔接。减少动态效果时朝向按阈值直接切换。
          final flip = reduceMotion
              ? (isCollapsedVisual ? 1.0 : -1.0)
              : 1 - 2 * progress;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: isCollapsedVisual ? _expandToMax : _collapseToMin,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(1, flip, 1),
                      child: const FaIcon(FontAwesomeIcons.anglesUp, size: 14),
                    ),
                    const SizedBox(width: 10),
                    // 中英文案长短不一：宽度随文案平滑过渡，箭头不会跳位。
                    AnimatedSize(
                      duration: ExpressiveMotion.durationNonZero(
                        context,
                        ExpressiveMotion.fast,
                      ),
                      curve: ExpressiveMotion.effects,
                      child: AnimatedSwitcher(
                        duration: ExpressiveMotion.duration(
                          context,
                          ExpressiveMotion.fast,
                        ),
                        switchInCurve: ExpressiveMotion.effects,
                        switchOutCurve: ExpressiveMotion.exit,
                        child: Text(
                          isCollapsedVisual ? l10n.autoT0158 : l10n.autoT0159,
                          key: ValueKey<bool>(isCollapsedVisual),
                          style: titleStyle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTagHeader(BuildContext context) {
    final l10n = context.l10n;
    // 标签子页头部：左返回、中标题、右占位保持居中。
    return SizedBox(
      height: _collapsedHeight,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () {
              _popInnerPage();
            },
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            tooltip: l10n.commonBack,
          ),
          Expanded(
            child: Center(
              child: Text(
                l10n.autoT0160,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCapsuleHeader(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: _collapsedHeight,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () {
              _popInnerPage();
            },
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            tooltip: l10n.commonBack,
          ),
          Expanded(
            child: Center(
              child: Text(
                l10n.timeCapsulePickTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCoverEntryTile(BuildContext context) {
    final l10n = context.l10n;
    final coverText = widget.hasCover && widget.coverLabel != null
        ? widget.coverLabel!
        : l10n.autoT0161;
    final colorScheme = Theme.of(context).colorScheme;
    // 封面入口卡片（可选），支持清除封面。
    return Material(
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
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
                  l10n.autoT0162,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                    tooltip: l10n.autoT0163,
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final selectedTags = widget.tags
        .where((tag) => widget.selectedTagIds.contains(tag.id))
        .toList();

    final colorScheme = theme.colorScheme;
    // 标签入口卡片：仅展示已选择标签摘要，点击进入标签页。
    return Material(
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
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
                  l10n.autoT0109,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: selectedTags.isEmpty
                      ? Text(
                          l10n.autoT0164,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: selectedTags.map((tag) {
                              final tagColor = Color(tag.color);
                              final isLight =
                                  Theme.of(context).brightness ==
                                  Brightness.light;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tagColor.withValues(
                                      alpha: isLight ? 0.08 : 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: tagColor.withValues(
                                        alpha: isLight ? 0.22 : 0.32,
                                      ),
                                      width: 0.65,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        '#',
                                        style: TextStyle(
                                          color: tagColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        tag.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagManageContent(BuildContext context) {
    final l10n = context.l10n;
    // 标签页内容三态：加载 / 错误 / 正常列表。
    if (widget.tagsLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: ExpressiveLoadingIndicator(),
      );
    }
    if (widget.tagsError != null) {
      final tagsError = widget.tagsError!;
      return Text(
        l10n.autoT0165(tagsError),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (widget.tags.isEmpty) {
      return Text(l10n.autoT0166, style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      children: widget.tags
          .map((tag) => _buildTagListRow(context, tag: tag))
          .toList(growable: false),
    );
  }

  Widget _buildTagListRow(BuildContext context, {required Tag tag}) {
    final selected = widget.selectedTagIds.contains(tag.id);
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tagColor = Color(tag.color);
    // 选中换色经 ExpressiveStateBlend 补间（Material 不补间颜色）。
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpressiveStateBlend(
        active: selected,
        builder: (context, t, child) => Material(
          color: Color.lerp(
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            tagColor.withValues(alpha: isLight ? 0.12 : 0.22),
            t,
          ),
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onToggleTag(tag.id, !selected),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: tagColor.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#',
                      style: TextStyle(
                        color: tagColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tag.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  ExpressiveIconSwap(
                    switchKey: selected,
                    child: FaIcon(
                      selected
                          ? FontAwesomeIcons.solidCircleCheck
                          : FontAwesomeIcons.circle,
                      size: 18,
                      color: selected ? tagColor : colorScheme.outlineVariant,
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
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.autoT0167,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Material(
          color: colorScheme.surfaceContainerHighest,
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
                    child: TextField(
                      controller: widget.locationController,
                      onChanged: widget.onLocationChanged,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: l10n.contextLocationInputHint,
                        hintStyle: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.75,
                              ),
                            ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.locating
                        ? null
                        : widget.onResolveLocation,
                    tooltip: l10n.autoT0169,
                    visualDensity: VisualDensity.compact,
                    icon: _buildResolvingIcon(
                      resolving: widget.locating,
                      icon: const FaIcon(
                        FontAwesomeIcons.locationCrosshairs,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.onLocationPrecisionChanged != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: PublishLocationPrecisionPicker(
              precision: widget.locationPrecision,
              locationController: widget.locationController,
              addressComponent: widget.locationAddressComponent,
              onChanged: widget.locating || widget.saving
                  ? null
                  : widget.onLocationPrecisionChanged,
            ),
          ),
        const SizedBox(height: 8),
        Material(
          color: colorScheme.surfaceContainerHighest,
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
                  QWeatherIcon(
                    iconCode: widget.weatherIconCode,
                    weatherText: widget.weatherController.text,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.weatherController,
                      onChanged: widget.onWeatherChanged,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: l10n.contextWeatherInputHint,
                        hintStyle: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.75,
                              ),
                            ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.weatherLoading
                        ? null
                        : widget.onResolveWeather,
                    tooltip: l10n.autoT0171,
                    visualDensity: VisualDensity.compact,
                    icon: _buildResolvingIcon(
                      resolving: widget.weatherLoading,
                      icon: QWeatherIcon(
                        iconCode: widget.weatherIconCode,
                        weatherText: widget.weatherController.text,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 定位/天气按钮的图标：按钮在请求开始时立即禁用防止连点；请求超过
  /// [DelayedLoadingGate.defaultDelay] 才把图标换成加载指示器，命中缓存的
  /// 快速返回不会闪一下转圈，切换本身经 [ExpressiveIconSwap] 过渡。
  Widget _buildResolvingIcon({required bool resolving, required Widget icon}) {
    return DelayedLoadingGate(
      loading: resolving,
      builder: (BuildContext context, bool showLoading) => ExpressiveIconSwap(
        switchKey: showLoading,
        child: showLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: ExpressiveLoadingIndicator(),
              )
            : icon,
      ),
    );
  }

  Widget _buildMoodSection(BuildContext context) {
    final l10n = context.l10n;
    const moodColumns = 5;
    const horizontalSpacing = 8.0;
    final moodOptions = widget.moodOptions.isEmpty
        ? SettingsService.defaultMoodOptions
        : SettingsService.normalizeMoodOptions(widget.moodOptions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.autoT0116,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final itemWidth =
                (constraints.maxWidth - horizontalSpacing * (moodColumns - 1)) /
                moodColumns;
            // 固定 5 列，两行排布，不允许横向滚动。
            return Wrap(
              spacing: horizontalSpacing,
              children: moodOptions
                  .map((emoji) {
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
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(height: 1),
                          ),
                        ),
                        selected: widget.moodEmoji == emoji,
                        onSelected: (selected) =>
                            widget.onMoodChanged(selected ? emoji : null),
                      ),
                    );
                  })
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPublishTimeEntryTile(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final publishTimeLabel = widget.publishTimeLabel?.trim();
    final hasPublishTime =
        publishTimeLabel != null && publishTimeLabel.isNotEmpty;

    return Material(
      color: colorScheme.surfaceContainerHighest,
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
              Text(
                l10n.autoT0172,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasPublishTime ? publishTimeLabel : l10n.autoT0173,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: hasPublishTime
                        ? null
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onPickPublishTime,
                tooltip: l10n.autoT0174,
                visualDensity: VisualDensity.compact,
                icon: const FaIcon(FontAwesomeIcons.calendarDays, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCapsuleEntryTile(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final capsuleLabel = widget.timeCapsuleLabel?.trim();
    final hasCapsule =
        widget.timeCapsuleActive &&
        capsuleLabel != null &&
        capsuleLabel.isNotEmpty;

    // 设置/清除时间胶囊后底色与描边经 ExpressiveStateBlend 补间（Material 只
    // 补间形状，不补间颜色）。
    return ExpressiveStateBlend(
      active: hasCapsule,
      builder: (context, t, child) => Material(
        color: Color.lerp(
          colorScheme.surfaceContainerHighest,
          colorScheme.primaryContainer.withValues(alpha: 0.56),
          t,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Color.lerp(
              colorScheme.outlineVariant.withValues(alpha: 0.45),
              colorScheme.primary.withValues(alpha: 0.34),
              t,
            )!,
          ),
        ),
        child: child,
      ),
      child: InkWell(
        onTap: _openCapsulePage,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: <Widget>[
                FaIcon(
                  FontAwesomeIcons.clock,
                  size: 14,
                  color: hasCapsule
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        l10n.timeCapsuleTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        hasCapsule ? capsuleLabel : l10n.timeCapsuleUnset,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasCapsule && widget.onClearTimeCapsule != null)
                  IconButton(
                    onPressed: widget.onClearTimeCapsule,
                    tooltip: l10n.timeCapsuleClear,
                    visualDensity: VisualDensity.compact,
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
                  ),
                IconButton(
                  onPressed: _openCapsulePage,
                  tooltip: l10n.timeCapsulePickTitle,
                  visualDensity: VisualDensity.compact,
                  icon: const FaIcon(FontAwesomeIcons.lock, size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnergySection(BuildContext context) {
    final l10n = context.l10n;
    final isEnergyEnabled = widget.energyLevel != null;
    final energyLevel = EnergyBatteryIndicator.normalizeValue(
      widget.energyLevel ?? _lastEnergyLevel,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  Text(
                    l10n.autoT0175,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isEnergyEnabled) ...<Widget>[
                    EnergyBatteryIndicator(value: energyLevel, iconSize: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        EnergyBatteryIndicator.descriptionForValue(
                          energyLevel,
                          l10n,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ] else ...<Widget>[
                    Flexible(
                      child: Text(
                        l10n.diaryEnergyUnrecorded,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: l10n.diaryEnergySwitchTooltip,
              child: Switch(
                value: isEnergyEnabled,
                onChanged: (enabled) {
                  if (enabled) {
                    widget.onEnergyChanged(_lastEnergyLevel);
                  } else {
                    widget.onEnergyChanged(null);
                  }
                },
              ),
            ),
          ],
        ),
        AnimatedSize(
          // 减少动画时用 1ms 近似瞬时：0 时长的 AnimatedSize 会在自身
          // performLayout 内重新标脏而触发断言（见 ExpressiveMotion.durationNonZero）。
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.fast,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topCenter,
          child: isEnergyEnabled
              ? Slider(
                  value: energyLevel,
                  min: 1,
                  max: 5,
                  // 精力是五格电量：整档 1–5 与文案一一对应。旧版连续值照常显示，
                  // 拖动后吸附到整档。
                  divisions: 4,
                  label: EnergyBatteryIndicator.formatValue(energyLevel),
                  onChanged: (nextValue) {
                    _lastEnergyLevel = nextValue;
                    widget.onEnergyChanged(nextValue);
                  },
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildPublishAction(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final actionLabel = widget.actionLabel.trim().isEmpty
        ? l10n.autoT0138
        : widget.actionLabel;

    // 主操作按钮始终位于内容底部，避免与顶部手势区域冲突。
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(64, 56),
          textStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: widget.saving ? null : widget.onPublish,
        icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 13),
        label: Text(widget.saving ? l10n.autoT0176 : actionLabel),
      ),
    );
  }
}
