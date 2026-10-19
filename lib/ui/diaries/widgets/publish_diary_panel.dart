import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_meta_actions.dart';
import 'package:node_diary/ui/diaries/controllers/publish_panel_coordinator.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import 'publish_panel/publish_capsule_picker_page.dart';
import 'publish_panel/publish_notebook_tiles.dart';
import 'publish_panel/publish_panel_chrome.dart';
import 'publish_panel/publish_panel_main_page.dart';
import 'publish_panel/publish_panel_summary_bar.dart';
import 'publish_panel/publish_tag_picker_page.dart';

export 'publish_panel/publish_panel_main_page.dart' show PublishTimeOption;

/// 发布页与编辑页底部的元数据悬浮面板（smooth_sheets 版）。
///
/// 输入：面板草稿 [draft] 与动作 [actions]（与页面共享），是否忙碌、发表
/// 时间行、是否提供时间胶囊与发表按钮。标签与心情候选由面板自己监听。
/// 输出：草稿上的修改（区块直接写 [draft]）、[onPublish]、展开进度
/// [onProgressChanged]。
///
/// 交互：收起态更窄、位置更高；支持上划与点击展开；上划过程中尺寸连续
/// 变化，松手后吸附到展开/收起。内部 PageView 承载主页、标签页、胶囊页与
/// 日记本页，只允许代码切页。
class PublishDiaryPanel extends ConsumerStatefulWidget {
  const PublishDiaryPanel({
    super.key,
    this.controller,
    required this.draft,
    required this.actions,
    this.busy = false,
    this.publishTime,
    this.capsuleEnabled = false,
    this.onPublish,
    this.onProgressChanged,
  });

  final PublishDiaryPanelController? controller;
  final DiaryMetaDraftController draft;
  final DiaryMetaActions actions;

  /// 页面忙碌（写库中、封存中）：发表按钮停用，层级不可改。
  final bool busy;

  /// 发表时间行；为 null 时不显示。
  final PublishTimeOption? publishTime;

  /// 是否提供时间胶囊（只有发布新日记时）。
  final bool capsuleEnabled;

  /// 编辑页自动保存时不传主操作，发布页仍显示发布按钮。
  final VoidCallback? onPublish;
  final ValueChanged<double>? onProgressChanged;

  @override
  ConsumerState<PublishDiaryPanel> createState() => _PublishDiaryPanelState();
}

/// 发布页悬浮面板控制器。
///
/// 提供给页面级返回逻辑使用：
/// - 判断面板是否处于展开状态；
/// - 主动触发面板展开/收起动画。
class PublishDiaryPanelController {
  _PublishDiaryPanelState? _state;

  /// 是否处于“返回键应优先收起面板”的展开状态。
  bool get isExpanded =>
      _state?._panelCoordinator.isExpandedForBackAction ?? false;

  /// 是否位于内部子页（标签页、胶囊页），返回键应先回主页。
  bool get canPopInnerPage =>
      _state?._panelCoordinator.canPopInnerPage ?? false;

  Future<void> expand() =>
      _state?._panelCoordinator.expandToMax() ?? Future<void>.value();

  Future<void> collapse() =>
      _state?._panelCoordinator.collapseToMin() ?? Future<void>.value();

  Future<bool> popInnerPage() =>
      _state?._popInnerPage() ?? Future<bool>.value(false);

  void _attach(_PublishDiaryPanelState state) {
    _state = state;
  }

  void _detach(_PublishDiaryPanelState state) {
    if (_state == state) {
      _state = null;
    }
  }
}

class _PublishDiaryPanelState extends ConsumerState<PublishDiaryPanel> {
  // ==================== 尺寸参数（收起/展开/布局） ====================
  static const double _collapsedHeight = 56;
  static const double _mainExpandedHeight = 470;
  static const double _subPageExpandedHeight = 540;
  // 收起态两侧内缩：宽屏最多 40，收起栏宽度上限约 320；窄屏收到 8，给
  // 摘要和发表按钮留出空间。
  static const double _collapsedMaxInset = 40;
  static const double _collapsedMinInset = 8;
  static const double _collapsedTargetWidth = 320;
  static const double _expandedHorizontalInset = 2;
  static const double _collapsedExtraLift = 18;
  static const double _collapsedBottomGap = 10;
  // 展开时与宿主可用区域顶边至少留出的距离，表头不贴着顶栏、不被挤出。
  static const double _expandedTopGap = 24;

  // ==================== 交互状态机协调器 ====================
  late final PublishPanelCoordinator _panelCoordinator;
  // 每次打开胶囊页递增，让胶囊子页以新的 key 重建、从当前设置重新开始。
  int _capsuleOpenGeneration = 0;

  /// 展开进度（0=收起，1=展开）的可监听副本。
  ///
  /// 拖拽面板时进度逐帧变化：只让依赖进度的局部（宽度内缩与抬升、详情淡入与
  /// 可交互阈值、表头箭头与文案）跟随重建，三张子页的内容子树保持不变，不再
  /// 每帧整面板 setState。只在 [_handleSheetMetricsChanged] 确认处于非构建/
  /// 布局阶段后写入，监听者可以安全地标脏重建。
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  double get _activeExpandedHeight => _panelCoordinator.activeExpandedHeight;

  @override
  void initState() {
    super.initState();
    _panelCoordinator = PublishPanelCoordinator(
      collapsedHeight: _collapsedHeight,
      mainExpandedHeight: _mainExpandedHeight,
      tagExpandedHeight: _subPageExpandedHeight,
      capsuleExpandedHeight: _subPageExpandedHeight,
      resolveDuration: (token) => ExpressiveMotion.duration(context, token),
    );
    _panelCoordinator.sheetController.addListener(_handleSheetMetricsChanged);
    // 将状态对象挂到外部 controller，供页面层返回键逻辑调用。
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant PublishDiaryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  Future<void> _openCapsulePage() async {
    setState(() => _capsuleOpenGeneration++);
    await _panelCoordinator.openCapsulePage();
  }

  Future<bool> _popInnerPage({bool animated = true}) async {
    final popped = await _panelCoordinator.popInnerPage(animated: animated);
    if (popped && mounted) {
      setState(() {});
    }
    return popped;
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
    final colorScheme = Theme.of(context).colorScheme;
    // 悬浮模块用卡片主表面（DESIGN.md §2.1）：亮色纯白、暗色温和深灰；面板内
    // 的行用输入框填充色区分层次。
    // 1) 不叠加键盘高度：宿主页 Scaffold 默认 resizeToAvoidBottomInset，body
    //    底边已经是键盘顶边，面板以 Positioned(bottom: 0) 挂在 body 内；再加
    //    viewInsets 会抬升两倍键盘高度（收起态会悬在键盘上方 300+dp）。
    // 2) 用普通 Padding 而非 AnimatedPadding：内缩量由拖拽进度逐帧给出，
    //    AnimatedPadding 每帧被重新定向，会让面板宽度滞后于手指。
    // 3) 只有这层 Padding 随进度重建，面板本体作为缓存的 child 传入。
    return LayoutBuilder(
      builder: (context, constraints) {
        // 宿主（Positioned.fill + Align）给出有界高度时，展开高度随可用高度
        // 收缩：键盘弹出、矮屏或横屏时表头不会被挤出可视区域。
        _panelCoordinator.maxExpandedHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight - _collapsedBottomGap - _expandedTopGap
            : null;
        final collapsedFactor = _collapsedHeight / _activeExpandedHeight;
        final collapsedInset = constraints.hasBoundedWidth
            ? ((constraints.maxWidth - _collapsedTargetWidth) / 2).clamp(
                _collapsedMinInset,
                _collapsedMaxInset,
              )
            : _collapsedMaxInset;
        return ValueListenableBuilder<double>(
          valueListenable: _progress,
          builder: (BuildContext context, double progress, Widget? child) {
            // 面板展开时变宽，收起时变窄，形成“悬浮卡片展开”感。
            final horizontalInset = lerpDouble(
              collapsedInset,
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
                initialOffset: SheetOffset(collapsedFactor),
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
                    SheetOffset(collapsedFactor),
                    const SheetOffset(1),
                  ],
                  minFlingSpeed: 580,
                ),
                // 面板容器：圆角 + 浮动阴影 + 卡片微边框。
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
                            color: ExpressiveSurfaces.cardColor(colorScheme),
                            border: Border.fromBorderSide(
                              ExpressiveSurfaces.cardBorderSide(colorScheme),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: child,
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
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = context.l10n;
    final tags = ref.watch(tagListProvider);
    // 只订阅日记本表；篇数（会随日记写入重查）由日记本子页自己订阅，子页
    // 不可见时不构建，编辑页自动保存不会牵动这条查询。
    final notebooks = ref.watch(notebooksProvider).value;
    final moodOptions = ref
        .watch(moodOptionsProvider)
        .maybeWhen(
          data: (options) => options,
          orElse: () => SettingsService.defaultMoodOptions,
        );
    PublishPanelSubHeader subHeader(String title) => PublishPanelSubHeader(
      title: title,
      height: _collapsedHeight,
      onBack: _popInnerPage,
    );
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
        PublishPanelPageScaffold(
          progress: _progress,
          headerHeight: _collapsedHeight,
          header: PublishPanelMainHeader(
            progress: _progress,
            height: _collapsedHeight,
            onExpand: _panelCoordinator.expandToMax,
            onCollapse: _panelCoordinator.collapseToMin,
            collapsedContent: PublishPanelSummaryBar(
              draft: widget.draft,
              tags: tags.asData?.value ?? const [],
              notebooks: notebooks ?? const <NotebookView>[],
              busy: widget.busy,
              onPublish: widget.onPublish,
            ),
          ),
          content: PublishPanelMainPage(
            draft: widget.draft,
            actions: widget.actions,
            tags: tags,
            moodOptions: moodOptions,
            busy: widget.busy,
            publishTime: widget.publishTime,
            capsuleEnabled: widget.capsuleEnabled,
            onOpenTags: _panelCoordinator.openTagPage,
            onOpenCapsule: _openCapsulePage,
            onPublish: widget.onPublish,
            notebooks: notebooks ?? const <NotebookView>[],
            onOpenNotebooks: _panelCoordinator.openNotebookPage,
          ),
        ),
        PublishPanelPageScaffold(
          progress: _progress,
          headerHeight: _collapsedHeight,
          header: subHeader(l10n.autoT0160),
          content: PublishTagPickerPage(
            draft: widget.draft,
            tags: tags,
            onCreateTag: () => widget.actions.createTag(context),
          ),
        ),
        PublishPanelPageScaffold(
          progress: _progress,
          headerHeight: _collapsedHeight,
          header: subHeader(l10n.timeCapsulePickTitle),
          content: PublishCapsulePickerPage(
            key: ValueKey<int>(_capsuleOpenGeneration),
            initial: widget.draft.value.capsule,
            onConfirm: (schedule) {
              widget.draft.setCapsule(schedule);
              _popInnerPage();
            },
            onCancel: _popInnerPage,
          ),
        ),
        PublishPanelPageScaffold(
          progress: _progress,
          headerHeight: _collapsedHeight,
          header: subHeader(l10n.notebookPickerTitle),
          content: PublishNotebookPickerPage(
            draft: widget.draft,
            notebooks: notebooks,
          ),
        ),
      ],
    );
  }
}
