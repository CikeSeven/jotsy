import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:path/path.dart' as path;

import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/amap_config_channel.dart';
import 'package:node_diary/core/services/diary_cover_storage_service.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/location_resolver_service.dart';
import 'package:node_diary/core/services/qweather_weather_service.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/widgets/create_tag_dialog.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_cover_sliver.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

part '../controllers/publish_diary_controller.dart';

/// 日记发布页（预览优先）。
///
/// 页面职责：
/// - 展示真实发布预览（封面 + 标题 + 富文本正文）；
/// - 承载底部面板交互（封面/标签/位置/天气/心情/精力）；
/// - 最终调用控制器执行发布写库。
class PublishDiaryPage extends ConsumerStatefulWidget {
  const PublishDiaryPage({super.key, required this.initialDraft});

  final NewDiaryDraft initialDraft;

  @override
  ConsumerState<PublishDiaryPage> createState() => _PublishDiaryPageState();
}

class _PublishDiaryPageState extends ConsumerState<PublishDiaryPage> {
  // ==================== 输入控制器与面板控制器 ====================
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _weatherController = TextEditingController();
  final PublishDiaryPanelController _panelController =
      PublishDiaryPanelController();
  late final quill.QuillController _previewController;
  late final Set<int> _selectedTagIds;

  // ==================== 页面草稿态字段 ====================
  String? _draftCover;
  String? _moodEmoji;
  String? _locationTownship;
  Map<String, Object?>? _locationAddressComponent;
  double? _locationLatitude;
  double? _locationLongitude;
  bool _locationFromAuto = false;
  String? _weatherIconCode;
  double _energyLevel = 4;
  late DateTime _publishAt;
  TimeCapsuleSchedule? _timeCapsuleSchedule;
  double _panelExpandProgress = 0;

  // ==================== 异步流程状态 ====================
  bool _saving = false;
  bool _locating = false;
  bool _weatherLoading = false;
  bool _showCapsuleSealOverlay = false;
  LocationResolverService? _locationResolverService;
  QWeatherWeatherService? _weatherService;

  // ==================== 业务控制器 ====================
  late final PublishDiaryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PublishDiaryController(this);
    _selectedTagIds = <int>{...widget.initialDraft.selectedTagIds};
    _draftCover = _controller.normalizeOptionalText(widget.initialDraft.cover);
    _locationTownship = widget.initialDraft.location;
    _locationAddressComponent = widget.initialDraft.locationAddressComponent;
    _locationLatitude = widget.initialDraft.locationLatitude;
    _locationLongitude = widget.initialDraft.locationLongitude;
    _locationFromAuto = widget.initialDraft.locationFromAuto;
    _locationController.text = widget.initialDraft.location ?? '';
    _weatherController.text = widget.initialDraft.weather ?? '';
    _weatherIconCode = widget.initialDraft.weatherIconCode;
    _moodEmoji = widget.initialDraft.moodEmoji;
    _publishAt = _controller.resolveInitialPublishAt(
      widget.initialDraft.createdAtOverride,
    );
    final initialCapsuleUnlockAt = widget.initialDraft.capsuleUnlockAt;
    if (initialCapsuleUnlockAt != null) {
      _timeCapsuleSchedule = TimeCapsuleSchedule(
        unlockAt: initialCapsuleUnlockAt,
        precision: TimeCapsuleSchedule.parsePrecision(
          widget.initialDraft.capsulePrecision,
        ),
      );
    }

    // 精力值限制在 1~5，避免历史数据越界导致 UI 异常。
    final initialEnergy = (widget.initialDraft.energyLevel ?? 4).toDouble();
    if (initialEnergy < 1) {
      _energyLevel = 1;
    } else if (initialEnergy > 5) {
      _energyLevel = 5;
    } else {
      _energyLevel = initialEnergy;
    }

    // 预览正文优先走 Delta JSON；失败时降级纯文本，确保页面总能打开。
    quill.Document previewDoc;
    try {
      previewDoc = decodeDiaryContentToDocument(
        widget.initialDraft.contentDocJson,
      );
    } catch (_) {
      previewDoc = documentFromPlainText(widget.initialDraft.contentText);
    }
    _previewController = quill.QuillController(
      document: previewDoc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    _weatherController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final tagsAsync = ref.watch(tagListProvider);

    // 标签数据状态拆分为三元组，便于直接透传给悬浮面板组件。
    var tags = const <Tag>[];
    var tagsLoading = false;
    String? tagsError;
    tagsAsync.when(
      data: (data) => tags = data,
      loading: () => tagsLoading = true,
      error: (error, stackTrace) => tagsError = '$error',
    );

    // 根据面板展开进度动态预留底部空间，避免正文被面板遮挡。
    final panelSpacer = lerpDouble(140, 460, _panelExpandProgress) ?? 140;

    // 返回键策略：
    // 1) 优先返回面板子页；
    // 2) 其次收起面板；
    // 3) 最后带草稿返回编辑页。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_panelController.canPopInnerPage) {
            _panelController.popInnerPage();
            return;
          }
          if (_panelController.isExpanded) {
            _panelController.collapse();
            return;
          }
          _controller.closeWithDraft();
        }
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: Text(context.l10n.autoT0138),
          leading: IconButton(
            onPressed: _controller.closeWithDraft,
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: <Widget>[
                if (_controller.normalizedCover != null)
                  PublishDiaryCoverSliver(cover: _controller.normalizedCover!),
                SliverToBoxAdapter(
                  // 标题与正文预览区域。
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _controller.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 16),
                        // 不能只看纯文本镜像（contentText），纯图片正文在镜像里会为空。
                        // 统一按 Quill 文档可见内容判断，图片/嵌入也算正文内容。
                        if (!diaryDocumentHasVisibleContent(
                          _previewController.document,
                        ))
                          Text(
                            context.l10n.autoT0139,
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          quill.QuillEditor.basic(
                            controller: _previewController,
                            config: quill.QuillEditorConfig(
                              autoFocus: false,
                              scrollable: false,
                              padding: EdgeInsets.zero,
                              showCursor: false,
                              embedBuilders: buildDiaryQuillEmbedBuilders(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: panelSpacer)),
              ],
            ),
            Positioned(
              // 底部悬浮交互面板。
              left: 16,
              right: 16,
              bottom: 0,
              child: PublishDiaryPanel(
                controller: _panelController,
                saving: _saving,
                bottomInset: keyboardInset,
                hasCover: _controller.normalizedCover != null,
                coverLabel: _controller.coverLabel,
                locating: _locating,
                weatherLoading: _weatherLoading,
                locationController: _locationController,
                weatherController: _weatherController,
                weatherIconCode: _weatherIconCode,
                moodEmoji: _moodEmoji,
                energyLevel: _energyLevel,
                tags: tags,
                tagsLoading: tagsLoading,
                tagsError: tagsError,
                selectedTagIds: _selectedTagIds,
                // 通过进度回调驱动正文区底部占位，维持滚动可见性。
                onProgressChanged: (progress) {
                  void applyProgress() {
                    if (!mounted) {
                      return;
                    }
                    if ((progress - _panelExpandProgress).abs() < 0.0001) {
                      return;
                    }
                    setState(() => _panelExpandProgress = progress);
                  }

                  final phase = SchedulerBinding.instance.schedulerPhase;
                  if (phase == SchedulerPhase.persistentCallbacks ||
                      phase == SchedulerPhase.midFrameMicrotasks) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => applyProgress(),
                    );
                    return;
                  }
                  applyProgress();
                },
                onPickCover: _controller.pickCover,
                onClearCover:
                    _controller.normalizedCover == null
                        ? null
                        : _controller.clearCover,
                onCreateTag: _controller.createTagInline,
                onResolveLocation: _controller.resolveLocation,
                onResolveWeather: _controller.resolveWeather,
                onLocationChanged: (nextLocation) {
                  setState(() {
                    _locationTownship = _controller.normalizeOptionalText(
                      nextLocation,
                    );
                  });
                },
                onWeatherChanged: (nextWeather) {
                  setState(() {
                    // 手动修改天气文本后，旧天气 code 可能与文案不一致，清空后走文案兜底图标。
                    _weatherIconCode = null;
                  });
                },
                showPublishTimeOption: true,
                publishTimeLabel: _controller.formatPublishTimeLabel(
                  _publishAt,
                ),
                onPickPublishTime: _controller.pickPublishAt,
                showTimeCapsuleOption: true,
                timeCapsuleLabel: _controller.timeCapsuleLabel,
                timeCapsuleActive: _timeCapsuleSchedule != null,
                timeCapsuleSchedule: _timeCapsuleSchedule,
                onTimeCapsuleChanged: _controller.updateTimeCapsule,
                onClearTimeCapsule:
                    _timeCapsuleSchedule == null
                        ? null
                        : _controller.clearTimeCapsule,
                onToggleTag: (tagId, selected) {
                  setState(() {
                    if (selected) {
                      _selectedTagIds.add(tagId);
                    } else {
                      _selectedTagIds.remove(tagId);
                    }
                  });
                },
                onMoodChanged: (nextMood) {
                  setState(() => _moodEmoji = nextMood);
                },
                onEnergyChanged: (nextValue) {
                  setState(
                    () => _energyLevel = nextValue.clamp(1, 5).toDouble(),
                  );
                },
                onPublish: _controller.publish,
                actionLabel:
                    _timeCapsuleSchedule == null
                        ? ''
                        : context.l10n.timeCapsuleSealAction,
              ),
            ),
            if (_showCapsuleSealOverlay) _buildCapsuleSealOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleSealOverlay(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _showCapsuleSealOverlay ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: ColoredBox(
            color: colorScheme.scrim.withValues(alpha: 0.36),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.88, end: 1),
                duration: const Duration(milliseconds: 620),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FaIcon(
                          FontAwesomeIcons.lock,
                          size: 34,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.l10n.timeCapsuleSealing,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
