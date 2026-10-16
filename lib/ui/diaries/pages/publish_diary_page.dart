import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_meta_actions.dart';
import 'package:node_diary/ui/diaries/controllers/publish_diary_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/widgets/animated_publish_diary_cover_sliver.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_preview.dart';
import 'package:node_diary/ui/diaries/widgets/publish_time_picker.dart';
import 'package:node_diary/ui/diaries/widgets/time_capsule_seal_overlay.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

/// 日记发布页（预览优先）。
///
/// 页面只做装配：展示真实发布预览（封面 + 标题 + 富文本正文），承载底部
/// 元数据面板，把用户操作交给控制器，并负责提示、触觉、封存动画与路由。
/// - 面板字段：DiaryMetaDraftController（草稿）+ DiaryMetaActions（异步动作）；
/// - 发布流程：PublishDiaryController（阶段、发表时间、写库、回传草稿）。
class PublishDiaryPage extends ConsumerStatefulWidget {
  const PublishDiaryPage({
    super.key,
    required this.initialDraft,
    this.onPublished,
  });

  final NewDiaryDraft initialDraft;

  /// 写库成功、本页即将退场时调用（参数为新日记 id）。此刻本页静止且不透明，
  /// 打开者（编辑页）可以在这里把自己静默移出路由栈。
  final ValueChanged<String>? onPublished;

  @override
  ConsumerState<PublishDiaryPage> createState() => _PublishDiaryPageState();
}

class _PublishDiaryPageState extends ConsumerState<PublishDiaryPage> {
  // ==================== 面板与预览 ====================
  final PublishDiaryPanelController _panelController =
      PublishDiaryPanelController();
  // 面板展开进度只驱动正文底部占位：用 ValueNotifier 局部刷新占位条，
  // 避免拖拽时每帧 setState 重建整页（含只读 QuillEditor 预览）。
  final ValueNotifier<double> _panelExpandProgress = ValueNotifier<double>(0);

  // ==================== 草稿与流程 ====================
  // 面板字段的唯一来源；输入变化只通知监听它的局部（面板、封面），页面
  // 不再为每次打字、拖动精力滑块 setState。
  late final DiaryMetaDraftController _meta;
  late final DiaryMetaActions _metaActions;
  late final PublishDiaryController _publisher;

  @override
  void initState() {
    super.initState();
    _meta = DiaryMetaDraftController(
      DiaryMetaDraft.fromNewDiaryDraft(widget.initialDraft),
    );
    _publisher = PublishDiaryController(
      initialDraft: widget.initialDraft,
      meta: _meta,
    );
    // 阶段只在发布时变化几次（idle → saving → sealing/done），整页重建以
    // 同步返回按钮、面板的“发布中”与封存遮罩。
    _publisher.phase.addListener(_onPhaseChanged);
    _metaActions = DiaryMetaActions(
      ref,
      draft: _meta,
      isBusy: () => _leaveBlocked,
    );
  }

  @override
  void dispose() {
    _publisher.phase.removeListener(_onPhaseChanged);
    _publisher.dispose();
    _metaActions.dispose();
    _meta.dispose();
    _panelExpandProgress.dispose();
    super.dispose();
  }

  void _onPhaseChanged() {
    if (mounted) setState(() {});
  }

  /// 发布进行中、封存中或已发布退场中：此时带草稿返回会让已写库的日记
  /// 留在编辑页草稿里，用户可以再发一次。
  bool get _leaveBlocked => !_publisher.canLeave;

  /// 返回编辑页时带回发布页草稿上下文，确保往返不丢状态。
  void _closeWithDraft() {
    if (_leaveBlocked) return;
    Navigator.of(context).pop(_publisher.returnDraft());
  }

  /// 选择发表时间；约束见 [showPublishTimePicker]（与编辑已发布日记共用）。
  Future<void> _pickPublishTime() async {
    final shown = _publisher.effectivePublishAt;
    final picked = await showPublishTimePicker(context, current: shown);
    if (picked == null || !mounted) return;
    _publisher.applyPickedPublishAt(picked, shown: shown);
  }

  /// 发布：校验 → 写库 →（胶囊）封存卡片 + 成功触觉 → 通知打开者 → 退场。
  ///
  /// 先通知打开者（[PublishDiaryPage.onPublished]，编辑页借此静默移出路由
  /// 栈），再以新日记 id 作为结果退场；失败时只提示、留在本页可重试。
  Future<void> _publish() async {
    if (_leaveBlocked) return;
    final l10n = context.l10n;
    if (_publisher.validate() == PublishValidation.capsuleUnlockPassed) {
      _hint(l10n.timeCapsuleUnlockPassed);
      return;
    }
    final String diaryId;
    try {
      diaryId = await _publisher.submit(ref.read(appDatabaseProvider));
    } catch (error) {
      debugPrint('Publish failed: $error');
      _hint(l10n.publishFailed);
      return;
    }
    if (!mounted) return;
    if (_publisher.phase.value == PublishPhase.sealing) {
      // 封存是一次性的仪式动作：与封存卡片同时给出“成功”触觉，等卡片入场
      // 播完、停留片刻让用户读到提示后再退场。
      unawaited(HapticFeedback.successNotification());
      await Future<void>.delayed(TimeCapsuleSealOverlay.totalWait(context));
      if (!mounted) return;
    }
    widget.onPublished?.call(diaryId);
    Navigator.of(context).pop(diaryId);
  }

  /// 轻提示不等待关闭，避免把后续状态复位拖到提示消失之后。
  void _hint(String message) {
    if (!mounted) return;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 返回键策略：
    // 0) 发布进行中、封存中或已发布时忽略；
    // 1) 优先返回面板子页；
    // 2) 其次收起面板；
    // 3) 最后带草稿返回编辑页。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _leaveBlocked) return;
        if (_panelController.canPopInnerPage) {
          _panelController.popInnerPage();
          return;
        }
        if (_panelController.isExpanded) {
          _panelController.collapse();
          return;
        }
        _closeWithDraft();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppTopBar(
          title: Text(context.l10n.autoT0138),
          leading: IconButton(
            tooltip: context.l10n.commonBack,
            onPressed: _leaveBlocked ? null : _closeWithDraft,
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: <Widget>[
                // 只随封面重建：面板上打字、选心情不触碰封面头图。
                ValueListenableSelector<DiaryMetaDraft, String?>(
                  valueListenable: _meta,
                  selector: (draft) => draft.cover,
                  builder: (context, cover, _) =>
                      AnimatedPublishDiaryCoverSliver(cover: cover),
                ),
                SliverToBoxAdapter(
                  child: PublishDiaryPreview(draft: widget.initialDraft),
                ),
                // 根据面板展开进度动态预留底部空间，避免正文被面板遮挡。
                SliverToBoxAdapter(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _panelExpandProgress,
                    builder: (context, progress, _) =>
                        SizedBox(height: lerpDouble(140, 460, progress) ?? 140),
                  ),
                ),
              ],
            ),
            Positioned(
              // 底部悬浮交互面板。
              left: 16,
              right: 16,
              bottom: 0,
              // 面板各区块自己监听草稿；这里只随发表时间（选择后的文案）重建。
              child: ValueListenableBuilder<DateTime?>(
                valueListenable: _publisher.explicitPublishAt,
                builder: (context, _, _) => PublishDiaryPanel(
                  controller: _panelController,
                  draft: _meta,
                  actions: _metaActions,
                  busy: _leaveBlocked,
                  publishTime: PublishTimeOption(
                    // 既没选过、打开者也没指定时传 null，显示“自动获取当前时间”。
                    label: _publisher.hasFixedPublishTime
                        ? context.l10n.formatDateTimeMinute(
                            _publisher.effectivePublishAt,
                          )
                        : null,
                    onPick: _pickPublishTime,
                  ),
                  capsuleEnabled: true,
                  onPublish: _publish,
                  // 通过进度回调驱动正文区底部占位，维持滚动可见性。面板只在
                  // 非构建/布局阶段回调，此处可直接写入 ValueNotifier。
                  onProgressChanged: (progress) {
                    if (mounted) {
                      _panelExpandProgress.value = progress;
                    }
                  },
                ),
              ),
            ),
            if (_publisher.phase.value == PublishPhase.sealing)
              const TimeCapsuleSealOverlay(),
          ],
        ),
      ),
    );
  }
}
