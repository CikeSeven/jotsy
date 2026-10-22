import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
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
import 'package:node_diary/ui/settings/providers/app_features_provider.dart';
import 'package:node_diary/ui/widgets/action_loading_overlay.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

/// 日记发布页（预览优先，进入即发表）。
///
/// 一打开就把日记写进库并提示“已发表”；之后底部面板里的封面、标签、此时
/// 此地、发表时间、定时锁等改动像编辑页一样随改随存。返回时补存、（胶囊）
/// 播放封存卡片，然后直接回到打开编辑页之前的页面（首页），不再回到编辑页。
/// 写库失败时提示并退回编辑页，草稿原样保留，可以再点“发布”重试。
///
/// 页面只做装配：展示真实发布预览（封面 + 标题 + 富文本正文），承载底部
/// 元数据面板，把用户操作交给控制器，并负责提示、触觉、封存动画与路由。
/// - 面板字段：DiaryMetaDraftController（草稿）+ DiaryMetaActions（异步动作）；
/// - 发布流程：PublishDiaryController（阶段、发表时间、写库、自动保存）。
class PublishDiaryPage extends ConsumerStatefulWidget {
  const PublishDiaryPage({
    super.key,
    required this.initialDraft,
    this.onPublished,
    this.onLeave,
  });

  final NewDiaryDraft initialDraft;

  /// 写库成功时调用（参数为新日记 id）：打开者（编辑页）借此删除这份草稿。
  /// 页面在这之后才可能被移除，回调不依赖本页仍挂载。
  final ValueChanged<String>? onPublished;

  /// 已发表、本页即将退场时调用（参数为新日记 id）。此刻本页静止且不透明，
  /// 打开者（编辑页）可以在这里把自己静默移出路由栈，返回直接回到列表。
  final ValueChanged<String>? onLeave;

  @override
  ConsumerState<PublishDiaryPage> createState() => _PublishDiaryPageState();
}

class _PublishDiaryPageState extends ConsumerState<PublishDiaryPage>
    with WidgetsBindingObserver {
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
  // 进入页面时就取好：页面销毁时补存的写入在卸载后才完成。
  late final AppDatabase _database;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _database = ref.read(appDatabaseProvider);
    _meta = DiaryMetaDraftController(
      DiaryMetaDraft.fromNewDiaryDraft(widget.initialDraft),
    );
    _publisher = PublishDiaryController(
      initialDraft: widget.initialDraft,
      meta: _meta,
      // 功能管理关闭的功能发布时忽略（见 PublishDiaryController）：草稿里
      // 留下的胶囊不封存，留下的日记本不收进（面板已没有日记本行）。
      timeCapsulesEnabled: () => ref.read(appFeaturesProvider).timeCapsules,
      notebooksEnabled: () => ref.read(appFeaturesProvider).notebooks,
      onSaveError: _onSaveError,
    );
    // 阶段只变化几次（idle → saving → published → sealing/done），整页重建
    // 以同步返回按钮、面板锁定、写库遮罩与封存遮罩。
    _publisher.phase.addListener(_onPhaseChanged);
    _metaActions = DiaryMetaActions(
      ref,
      draft: _meta,
      // 发布新日记时“此时此地”就是现在：定位成功且没填天气时顺带取一次。
      autoWeatherAfterLocate: true,
      isBusy: () => _leaveBlocked,
    );
    // 第一帧之后再写库：提示要用到本地化与 ScaffoldMessenger。
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_publish()));
  }

  @override
  void dispose() {
    // 必须排在释放草稿之前：flush 当场读出快照，写库在页面卸载后完成。正常
    // 返回时已经补存过，这里兜住被别处移除路由的情况。
    unawaited(_publisher.flush());
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切到后台可能就被系统回收进程：不等防抖，立即补存面板改动。
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_publisher.flush());
    }
  }

  /// 只有已发表、且不在退场中时可以返回（见 [PublishPhase]）。
  bool get _leaveBlocked => !_publisher.canLeave;

  /// 进入即发表：（去掉已过期的胶囊）→ 写库 → 通知打开者删除草稿 → 提示。
  ///
  /// 写库失败时提示并退回编辑页：草稿还在那里，可以再点“发布”重试。
  Future<void> _publish() async {
    if (!mounted) return;
    final l10n = context.l10n;
    final onPublished = widget.onPublished;
    // 解封时间已过的胶囊（恢复的旧草稿、跨过零点的日历预设）写进去就会立即
    // 解封：去掉它按普通日记发表并在提示里说明，之后仍可在面板里重设定时锁。
    final capsuleExpired =
        _publisher.validate() == PublishValidation.capsuleUnlockPassed;
    if (capsuleExpired) _meta.setCapsule(null);
    final String diaryId;
    try {
      diaryId = await _publisher.submit(_database);
    } catch (error) {
      debugPrint('Publish failed: $error');
      _hint(l10n.publishFailed, abovePanel: false);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // 不论本页是否还在都要删除草稿，否则日记与草稿并存，可能被再发一次。
    onPublished?.call(diaryId);
    _hint(capsuleExpired ? l10n.publishCapsuleExpired : l10n.publishSucceeded);
  }

  /// 面板改动自动保存失败：提示通用文案（原始错误只进日志），快照保持未存，
  /// 下一次改动或返回时重试。
  void _onSaveError(Object error) {
    debugPrint('Publish autosave failed: $error');
    if (mounted) _hint(context.l10n.publishSaveFailed);
  }

  /// 返回：补存面板改动（失败时留在本页，提示见 [_onSaveError]）→（未解封
  /// 的胶囊）封存卡片 + 成功触觉 → 通知打开者 → 以新日记 id 退场。
  ///
  /// 先通知打开者（[PublishDiaryPage.onLeave]，编辑页借此静默移出路由栈），
  /// 返回时露出的直接是列表，列表据此播放新卡片的出现动画。
  Future<void> _leave() async {
    if (_leaveBlocked) return;
    if (!await _publisher.finish() || !mounted) return;
    if (_publisher.phase.value == PublishPhase.sealing) {
      // 封存是一次性的仪式动作：与封存卡片同时给出“成功”触觉，等卡片入场
      // 播完、停留片刻让用户读到提示后再退场。
      unawaited(HapticFeedback.successNotification());
      await Future<void>.delayed(TimeCapsuleSealOverlay.totalWait(context));
      if (!mounted) return;
    }
    final diaryId = _publisher.diaryId!;
    // 本页的提示浮在面板上方（见 [_hint]），带到列表上会悬在半空：退场时
    // 一并收起，列表上的新卡片动画就是结果。
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    widget.onLeave?.call(diaryId);
    Navigator.of(context).pop(diaryId);
  }

  /// 选择发表时间；约束见 [showPublishTimePicker]（与编辑已发布日记共用）。
  /// 改选后与其他面板字段一样自动保存。
  Future<void> _pickPublishTime() async {
    final shown = _publisher.effectivePublishAt;
    final picked = await showPublishTimePicker(context, current: shown);
    if (picked == null || !mounted) return;
    _publisher.applyPickedPublishAt(picked, shown: shown);
  }

  /// 轻提示不等待关闭，避免把后续状态复位拖到提示消失之后。
  ///
  /// 本页的提示浮在收起的面板上方：进入即发表的“已发表”每次都会出现，若
  /// 照常贴底，会在提示期间盖住收起栏、点不到。[abovePanel] 为 false 时照常
  /// 贴底（发表失败、随即退回编辑页时，提示显示在编辑页上）。
  void _hint(String message, {bool abovePanel = true}) {
    if (!mounted) return;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(message),
          margin: abovePanel
              ? const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  PublishDiaryPanel.collapsedFootprint + 8,
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 时间胶囊功能关闭时隐藏入口，数据保留：没有胶囊行，也不显示草稿里留下
    // 的胶囊（摘要项、发表时间跟随胶囊）——发布时会忽略它。
    final capsulesEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.timeCapsules),
    );
    // 返回键策略：
    // 0) 写库前后、封存中或退场中忽略；
    // 1) 优先返回面板子页；
    // 2) 其次收起面板；
    // 3) 最后补存并回到列表（见 [_leave]）。
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
        unawaited(_leave());
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppTopBar(
          title: Text(context.l10n.autoT0138),
          leading: IconButton(
            tooltip: context.l10n.commonBack,
            onPressed: _leaveBlocked ? null : _leave,
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
            // 底部悬浮交互面板：铺满 body、贴底对齐，面板据此拿到可用高度
            // （键盘弹出时展开高度随之收缩）。
            Positioned.fill(
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.bottomCenter,
                // 面板各区块自己监听草稿；这里只随发表时间（选择后的文案）重建。
                // 写库前后、封存与退场期间锁住面板：这时的改动不会被保存，不该
                // 看起来可改。
                child: AbsorbPointer(
                  absorbing: _leaveBlocked,
                  child: ValueListenableBuilder<DateTime?>(
                    valueListenable: _publisher.explicitPublishAt,
                    builder: (context, _, _) => PublishDiaryPanel(
                      controller: _panelController,
                      draft: _meta,
                      actions: _metaActions,
                      busy: _leaveBlocked,
                      // 进入即发表，发表时间就是写库那一刻（或用户改选的时间）。
                      publishTime: PublishTimeOption(
                        label: context.l10n.formatDateTimeMinute(
                          _publisher.effectivePublishAt,
                        ),
                        onPick: _pickPublishTime,
                      ),
                      capsuleEnabled: capsulesEnabled,
                      showDraftCapsule: capsulesEnabled,
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
              ),
            ),
            // 写库通常几十毫秒完成：遮罩立即拦截点击，超过 300ms 才淡入显示。
            Positioned.fill(
              child: ActionLoadingOverlay(
                visible: _publisher.phase.value == PublishPhase.saving,
                label: context.l10n.autoT0176,
                revealDelay: DelayedLoadingGate.defaultDelay,
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
