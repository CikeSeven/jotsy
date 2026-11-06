import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import '../controllers/diary_editor_controller.dart' as editor;
import '../models/diary_link_candidate.dart';
import '../widgets/diary_editor/diary_editor.dart';
import '../widgets/diary_editor/diary_editor_caret.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/core/services/diary_audio_storage_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/models/edit_diary_snapshot.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/diaries/models/recording_insertion.dart';
import 'package:node_diary/ui/diaries/controllers/diary_location_preference.dart';
import 'package:node_diary/ui/diaries/controllers/diary_meta_actions.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_recording_controller.dart';
import 'package:node_diary/ui/diaries/controllers/debounced_auto_save_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_media_import_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_audio_player_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_day_photos_controller.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';
import 'package:node_diary/utils/optional_text.dart';
import 'package:node_diary/ui/diaries/providers/diary_detail_provider.dart';
import 'package:node_diary/ui/diaries/providers/diary_saved_colors_provider.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor_drop_target.dart';
import 'package:node_diary/ui/diaries/widgets/diary_floating_toolbar_surface.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_media_import_overlay.dart';
import 'package:node_diary/ui/diaries/widgets/diary_day_photos/diary_day_photos_sheet.dart';
import 'package:node_diary/ui/diaries/widgets/diary_day_photos/diary_day_photos_strip.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:node_diary/ui/diaries/widgets/publish_time_picker.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/diary_templates/controllers/diary_template_apply_controller.dart';
import 'package:node_diary/ui/diary_templates/controllers/diary_template_save_as.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_prefs.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_selection.dart';
import 'package:node_diary/ui/diary_templates/providers/diary_template_providers.dart';
import 'package:node_diary/ui/diary_templates/sections/diary_template_picker_sheet.dart';
import 'package:node_diary/ui/diary_templates/widgets/diary_template_strip.dart';
import 'package:node_diary/ui/settings/pages/editor_settings_page.dart';
import 'package:node_diary/ui/settings/providers/app_features_provider.dart';
import 'package:node_diary/ui/settings/widgets/style_editor/style_editor_common.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:node_diary/ui/widgets/soft_keyboard_selection_keys.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import '../../widgets/desktop_page_arrows.dart';
import '../../widgets/expressive_entrance.dart';
import 'package:node_diary/ui/widgets/route_entrance_waiter.dart';
import 'package:node_diary/ui/ai/controllers/ai_privacy_gate.dart';
import 'package:node_diary/ui/ai/controllers/ai_writing_flow.dart';
import 'package:node_diary/ui/ai/controllers/ai_writing_session.dart';
import 'package:node_diary/ui/ai/models/ai_built_ins.dart';
import 'package:node_diary/ui/ai/models/ai_preference_parts.dart';
import 'package:node_diary/ui/ai/providers/ai_providers.dart';
import 'package:node_diary/ui/ai/sections/ai_suggestion_sheet.dart';
import 'package:node_diary/ui/ai/viewmodels/ai_json_output.dart';
import 'package:node_diary/ui/diaries/widgets/diary_ai/diary_ai_writing_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_ai/diary_ai_prompts_strip.dart';
import 'package:node_diary/ui/diaries/controllers/diary_ai_editing.dart';
import 'package:node_diary/ui/ai/controllers/ai_prompts_flow.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_commands.dart';
import 'package:node_diary/ui/ai/controllers/ai_reply_flow.dart';
import 'package:node_diary/ui/anniversaries/controllers/anniversary_navigation.dart';
import 'package:node_diary/ui/anniversaries/models/anniversary_draft.dart';
import 'package:node_diary/ui/diaries/controllers/diary_comment_flows.dart';
import 'package:node_diary/ui/diaries/controllers/diary_preview_export_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_preview_extras.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_mood_palette_provider.dart';
import 'package:node_diary/ui/diaries/providers/diary_preview_style_provider.dart';
import 'package:node_diary/ui/diaries/sections/diary_typography_sheet.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_preview_resolved_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_reading_snapshot.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comments_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_link/diary_backlinks_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor_trailing_region.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_actions_sheet.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_body.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_dialogs.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_header.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_meta.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_surface.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_top_bar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_trailing.dart';
import 'package:node_diary/ui/diaries/widgets/diary_reading_editor/diary_reading_cover.dart';
import 'package:node_diary/ui/diaries/widgets/diary_reading_editor/diary_reading_editor_header.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:node_diary/ui/settings/pages/diary_preview_style_page.dart';
import 'package:node_diary/ui/widgets/action_loading_overlay.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';

part '../controllers/edit_diary_controller.dart';
part '../controllers/edit_diary_persistence_controller.dart';
part '../controllers/edit_diary_recording_controller.dart';
part '../controllers/edit_diary_media_controller.dart';
part '../controllers/edit_diary_template_flow.dart';
part '../controllers/edit_diary_ai_flow.dart';
part '../controllers/edit_diary_reading_flow.dart';
part '../controllers/edit_diary_reading_actions.dart';

/// 日记编辑页。
///
/// - `diaryId == null`：新建模式（[createDraftId] 为 null 时新建空白，否则续写
///   草稿箱里的那一份）；每次新建都是草稿箱里独立的一份，自动保存，发布后删除
/// - `diaryId != null`：编辑模式，版式与预览页相同（阅读式编辑，见
///   `edit_diary_reading_flow.dart`）
class EditDiaryPage extends ConsumerStatefulWidget {
  const EditDiaryPage({
    super.key,
    this.diaryId,
    this.entryMode = EditDiaryEntryMode.edit,
    this.createDraftId,
    this.createDateOverride,
    this.createCapsuleUnlockAt,
    this.createTemplate,
    this.createNotebookId,
    this.createNotebookChapterId,
    this.initialCaret,
    this.initialDetail,
    this.coverHero,
  });

  final String? diaryId;
  final EditDiaryEntryMode entryMode;

  /// 新建模式下要续写的草稿（草稿表业务 id）；null 为新建空白。
  final String? createDraftId;
  final DateTime? createDateOverride;

  /// 新建模式下预设的时间胶囊解封日（按“日期”精度）：日历从未来日期进入
  /// “写给这一天的时间胶囊”时传入，发布页打开即为该日解封的胶囊，用户仍可
  /// 在发布页修改或取消。恢复的草稿若自带胶囊设置则以草稿为准。
  final DateTime? createCapsuleUnlockAt;

  /// 新建空白日记时直接套用的模板（新建入口里先在模板面板选好、预览过）。
  /// 续写草稿时不使用。
  final DiaryTemplateSelection? createTemplate;

  /// 新建空白日记时预先收进的日记本（在日记本里点“新建”）；续写草稿时不
  /// 使用，草稿自带它的日记本。
  final String? createNotebookId;

  /// 与 [createNotebookId] 同时传入：首页正停在这本的某一章时，新日记落在
  /// 这一章（发布时写入，见 `createDiary.notebookChapterIds`）。
  final String? createNotebookChapterId;

  /// 编辑已有日记时打开后的光标位置（预览页双击正文处）：放好光标、等入场
  /// 转场结束再聚焦弹出键盘。位置在正文里找不到（块已不在、不是文字块）时
  /// 照常从文首打开、不聚焦。新建模式不使用。
  final editor.Position? initialCaret;

  /// 编辑模式下入口已持有的同一篇日记：详情查询返回前直接用它回填，路由
  /// 滑入时就是完整的页面（头图共享元素才有落点）。
  final DiaryWithTags? initialDetail;

  /// 入口抓取的封面画面：头图以它为共享元素落点与占位。本页销毁时释放。
  final ImageViewerHero? coverHero;

  @override
  ConsumerState<EditDiaryPage> createState() => _EditDiaryPageState();
}

class _EditDiaryPageState extends ConsumerState<EditDiaryPage>
    with WidgetsBindingObserver {
  /// 悬浮工具栏一排之外再留的 12dp：卡片与键盘之间的空隙。
  static const double _floatingToolbarGap = 12.0;
  static const double _recordingPanelReservedSpace = 310.0;
  // 键盘弹起时光标与悬浮工具栏之间留出的空隙：光标贴着工具栏时下一行没有
  // 余地、读起来像被压住。底部占位同样加上它，最后一行才能被顶到这么高。
  static const double _caretToolbarClearance = 40.0;
  // 阅读式版式里正文之后的留白（与预览页页尾相同），再加系统导航条高度。
  static const double _readingBottomGap = 28.0;

  // ==================== 文本输入与焦点控制 ====================
  final _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  // 包住悬浮工具栏：颜色面板里的颜色代码输入框拿到焦点时，正文与标题都失焦，
  // 工具栏仍须留着（它的显示条件含“正在编辑”），否则输入框随之卸载。
  // 自身不可获得焦点，只用来判断焦点是否在工具栏内。
  final FocusNode _toolbarFocusNode = FocusNode(
    debugLabel: 'diary-floating-toolbar',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final RouteEntranceWaiter _routeEntranceWaiter = RouteEntranceWaiter();
  // 悬浮工具栏「更多」面板的目标高度（收起为 0），驱动正文末尾的额外留白。
  final ValueNotifier<double> _toolbarPanelExtent = ValueNotifier<double>(0);
  // 最近一次构建是否显示了悬浮工具栏：帧末的光标揭示据此取与这一帧布局一致
  // 的遮挡高度（见 [_editorBottomCover]）。
  bool _floatingToolbarShown = false;
  final DiaryRecordingController _recordingController =
      DiaryRecordingController();
  final DiaryMediaImportController _mediaImportController =
      DiaryMediaImportController();
  final PublishDiaryPanelController _editPanelController =
      PublishDiaryPanelController();
  DateTime? _createDateOverride;

  // 日记那天相册里拍的照片（见 [_dayPhotosDay]）：新建时跟随
  // _createDateOverride（日历入口、恢复的草稿、发布页改日期都会改它），编辑
  // 时跟随 _draftPublishAt。补写时提示条是否自动出现取决于编辑器设置；顶栏
  // 菜单随时可打开面板。
  late final DiaryDayPhotosController _dayPhotos;
  SettingsService? _dayPhotoSettings;

  // ==================== 发布上下文草稿字段 ====================
  late editor.DiaryEditorController _contentController;
  String _metadataJson = '{}';
  // 封面、标签、此时此地、天气、心情、精力与（新建时预设的）胶囊：与发布页
  // 共用同一草稿模型与动作。编辑模式下草稿变化经 [_onMetaChanged] 自动保存；
  // 新建模式只随草稿带进发布页。新日记默认不记录精力。
  late final DiaryMetaDraftController _meta;
  late final DiaryMetaActions _metaActions;
  // 新建空白日记时的模板建议条与套用、撤销（见 edit_diary_template_flow）。
  late final DiaryTemplateApplyController _templates;
  // 模板套用读的“此刻”（diaryTemplateClockProvider）：自动套用的时间段、
  // 变量与“今天”都按它算，测试据此固定时间。
  late final DateTime Function() _templateClock;
  // 已发布日记的发表时间（created_at）：详情回填时取库中原值，面板改选后随
  // 自动保存写回。新建模式不用它，发表时间经 _createDateOverride 交给发布页。
  DateTime? _draftPublishAt;
  bool _panelMetadataDirty = false;
  // 所在日记本不在 metadata 里：编辑模式只在用户改过之后才随自动保存写回
  // （未改过时不传，别处同时改了收录也不会被这份旧快照覆盖）。读回期间的
  // 整体恢复不算修改。
  bool _notebookIdsDirty = false;
  bool _restoringNotebookIds = false;
  // 上一次通知时的面板草稿：区分“只改了日记本”（不重组 metadata）与其他修改。
  late DiaryMetaDraft _lastMeta;
  // 新建模式按章节新建时的章节（日记本 id → 章节 id），随草稿保存与发布。
  Map<String, String> _createNotebookChapters = const <String, String>{};
  // 元数据面板拖拽进度逐帧变化，只用于正文底部占位的连续插值；放进
  // ValueNotifier 让占位局部刷新，页面仅在跨越展开阈值时 setState。
  final ValueNotifier<double> _editPanelExpandProgress = ValueNotifier<double>(
    0,
  );
  late List<DiaryToolbarItem> _toolbarOrder;
  Set<DiaryToolbarItem> _toolbarHiddenItems = <DiaryToolbarItem>{};
  String? _toolbarCurrentTimeFormatPattern;
  // 编辑器设置“始终显示工具栏”：打开后工具栏不再随软键盘出现与消失。
  bool _toolbarAlwaysVisible = false;
  // 编辑器设置“工具栏大小”：一排高度与正文底部占位随之变化。
  DiaryToolbarSize _toolbarSize = DiaryToolbarSize.standard;
  SettingsService? _boundToolbarSettingsService;
  VoidCallback? _toolbarSettingsListener;
  bool _recordingPanelOpen = false;
  int _recordingPanelGeneration = 0;
  editor.Selection? _recordingSelection;

  /// AI 写作面板的会话：打开时建立，关闭时释放（见 EditDiaryAiFlow）。
  AiWritingSession? _aiSession;

  /// 智能填写（生成标题、推荐标签与心情）进行中。
  bool _aiBusy = false;

  bool get _aiPanelOpen => _aiSession != null;

  /// 录音或 AI 写作面板占着工具栏下方的位置（正文锁定、工具栏保持显示）。
  bool get _bottomPanelOpen => _recordingPanelOpen || _aiPanelOpen;

  /// AI 写作在这里可用：AI 助手可用且写作模块开启。
  bool get _aiWritingAvailable =>
      ref.read(aiModuleAvailableProvider(AiModule.writing));

  // ==================== 阅读式版式（编辑已有日记） ====================
  // 详情回填时的原日记（id、归档、胶囊等列）；新建模式为 null。
  Diary? _readingBase;
  // 自动保存最近写下的正文与时间：页头页尾（借用的首图、字数、最后编辑于）
  // 按它们显示，见 [_EditDiaryReadingFlow._onReadingSaved]。
  String _readingContentJson = '';
  String _readingContentText = '';
  DateTime? _readingUpdatedAt;
  final DiaryReadingSnapshotBuilder _readingSnapshots =
      DiaryReadingSnapshotBuilder();
  // 信息面板挂着（点信息栏打开，收回到底后卸载）；升起过才算可以收回。
  bool _metaPanelOpen = false;
  bool _metaPanelRaised = false;
  final GlobalKey _readingCommentsKey = GlobalKey();
  // 按列表下标滚动编辑器：点信息栏的“N 条留言”时先把页尾滚出来。
  final DiaryEditorScrollHandle _readingScroll = DiaryEditorScrollHandle();
  // 分享与导出（没有长图：编辑页没有可整页截取的阅读视图）。
  late final DiaryPreviewExportController _readingExport;

  // ==================== 生命周期与保存状态 ====================
  bool _initialized = false;
  bool _saving = false;
  // 新建模式对应的草稿（草稿表业务 id）：续写时取入口传入的 id，新建空白在
  // 第一次有内容写入时由数据库生成。草稿写入与发布后的删除都按它进行。
  String? _createDraftId;
  // 进入页面时就取好：返回与 dispose 时补存的草稿在页面卸载后才写完，那时
  // 不能再经 ref 读取 provider。
  late final AppDatabase _database;

  // ==================== 业务控制器 ====================
  late final EditDiaryController _controller;

  /// 这个平台有没有悬浮工具栏：手机与桌面有（网页没有）。
  bool get _hasFloatingToolbar => AppPlatform.isMobile || AppPlatform.isDesktop;

  /// 工具栏不看键盘与焦点、一直显示：桌面上总是如此（没有软键盘，等同
  /// “始终显示工具栏”一直开着），手机上取决于那个设置。
  bool get _toolbarAlwaysShown =>
      AppPlatform.isDesktop || _toolbarAlwaysVisible;

  /// 录音入口（工具栏与斜杠菜单）：不支持录音的平台（Linux）不提供。
  bool get _recordingAvailable =>
      !diaryToolbarUnavailableItems().contains(DiaryToolbarItem.recording);

  /// 工具栏实际隐藏的工具：用户隐藏的，加上本平台不提供的（AI 写作在 AI
  /// 不可用时不提供）。
  Set<DiaryToolbarItem> get _effectiveToolbarHiddenItems {
    final unavailable = diaryToolbarUnavailableItems(ai: _aiWritingAvailable);
    return unavailable.isEmpty
        ? _toolbarHiddenItems
        : <DiaryToolbarItem>{..._toolbarHiddenItems, ...unavailable};
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _database = ref.read(appDatabaseProvider);
    _createDraftId = widget.createDraftId;
    _createDateOverride = widget.createDateOverride;
    // 先于草稿监听创建：_onMetaChanged 会同步封面角标。
    _dayPhotos = DiaryDayPhotosController(
      library: ref.read(dayPhotoLibraryProvider),
    );
    // 时间胶囊功能关闭时隐藏入口，数据保留：入口预设的解封日不再生效（兜底；
    // 日历的“写时间胶囊”入口已隐藏，新建流程也已忽略它）。
    final presetCapsule = ref.read(appFeaturesProvider).timeCapsules
        ? widget.createCapsuleUnlockAt
        : null;
    // 在日记本里新建空白日记：预先收进这本（用户仍可在发布页取消）。
    final presetNotebookId = _isCreateEntry && widget.createDraftId == null
        ? widget.createNotebookId
        : null;
    final presetChapterId = widget.createNotebookChapterId;
    if (presetNotebookId != null && presetChapterId != null) {
      _createNotebookChapters = <String, String>{
        presetNotebookId: presetChapterId,
      };
    }
    _meta = DiaryMetaDraftController(
      DiaryMetaDraft(
        notebookIds: presetNotebookId == null
            ? const <String>{}
            : <String>{presetNotebookId},
        capsule: presetCapsule == null
            ? null
            : TimeCapsuleSchedule(
                unlockAt: TimeCapsuleSchedule.normalizeUnlockAt(
                  presetCapsule,
                  precision: TimeCapsulePrecision.date,
                ),
                precision: TimeCapsulePrecision.date,
              ),
      ),
    );
    _lastMeta = _meta.value;
    _meta.addListener(_onMetaChanged);
    _metaActions = DiaryMetaActions(ref, draft: _meta, isBusy: () => _saving);
    // 先于业务控制器创建：草稿自动保存读快照时要经它判断“原样未动”。
    _templateClock = ref.read(diaryTemplateClockProvider);
    _templates = DiaryTemplateApplyController(
      enabled: _isCreateEntry && widget.createDraftId == null,
      port: _EditDiaryTemplatePort(this),
      database: _database,
      clock: _templateClock,
      // 时间胶囊功能关闭时模板里的胶囊预设不套用（预设本身留在模板里）。
      capsulesEnabled: () => ref.read(appFeaturesProvider).timeCapsules,
      onUsed: (templateId) async {
        final settings = await ref.read(settingsServiceProvider.future);
        await recordDiaryTemplateUse(settings, templateId);
      },
    );
    _contentController = editor.DiaryEditorController(
      document: editor.diaryEditorDocument(''),
      selection: editor.Selection.single(path: [0], startOffset: 0),
      linkSource: _linkSource,
    );
    _toolbarOrder = List<DiaryToolbarItem>.from(kDefaultDiaryToolbarOrder);
    _controller = EditDiaryController(this);
    _readingExport = DiaryPreviewExportController(
      onHint: _controller._showHint,
    );
    _mediaImportController.addListener(_onMediaImportChanged);
    // 阅读式顶栏在编辑标题或正文时显示“完成”：焦点进出时重建（接实体键盘、
    // 桌面上没有键盘高度变化来带动重建）。
    _titleFocusNode.addListener(_onEditingFocusChanged);
    _contentFocusNode.addListener(_onEditingFocusChanged);
    _titleController.addListener(_controller.onCreateDraftInputChanged);
    _contentController.addListener(_controller.onCreateDraftInputChanged);
    // 新建模式无需等详情查询，直接允许渲染编辑区域。
    _initialized = widget.diaryId == null;
    if (_isCreateEntry) {
      unawaited(_controller.prepareCreateEntry(draftId: widget.createDraftId));
    }
    if (widget.diaryId == null) {
      _routeEntranceWaiter.schedule(this, _contentFocusNode.requestFocus);
    }
  }

  @override
  void dispose() {
    // 必须排在释放输入控制器之前：flush 当场读出快照，写库在页面卸载后完成。
    // 发布后草稿自动保存已关闭，这里不会把刚删除的草稿写回去。
    if (_isCreateEntry) unawaited(_controller.flushCreateDraft());
    _aiSession?.dispose();
    // 返回飞行在本帧绘制前已结束，此时释放占位画面是安全的。
    widget.coverHero?.dispose();
    _readingExport.dispose();
    _routeEntranceWaiter.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _titleController.removeListener(_controller.onCreateDraftInputChanged);
    _contentController.removeListener(_controller.onCreateDraftInputChanged);
    _mediaImportController.removeListener(_onMediaImportChanged);
    _mediaImportController.dispose();
    _dayPhotoSettings?.dayPhotoSuggestionsEnabledNotifier.removeListener(
      _syncDayPhotos,
    );
    _dayPhotos.dispose();
    _titleController.dispose();
    _meta.removeListener(_onMetaChanged);
    _metaActions.dispose();
    _templates.dispose();
    _meta.dispose();
    _titleFocusNode.removeListener(_onEditingFocusChanged);
    _contentFocusNode.removeListener(_onEditingFocusChanged);
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _toolbarFocusNode.dispose();
    _editPanelExpandProgress.dispose();
    _toolbarPanelExtent.dispose();
    _contentController.dispose();
    _recordingController.dispose();
    _unbindToolbarSettingsService();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置（开启相册权限）或相机回来：权限与当天照片都可能变了。
    if (state == AppLifecycleState.resumed) {
      _dayPhotos.refresh();
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // 切到后台可能就被系统回收进程：已有日记与新建草稿都不等防抖，立即补存。
      if (_isEditEntry) unawaited(_controller.flushEditAutoSave());
      if (_isCreateEntry) unawaited(_controller.flushCreateDraft());
    }
  }

  /// 当前正文纯文本（用于搜索、字数统计和空内容判断）。
  String get _currentContentText => _contentController.plainText;

  /// 当前正文 Delta JSON（用于富文本持久化）。
  String get _currentContentDocJson => _contentController.contentJson;

  /// 模板变量按哪天展开、推荐按哪天判断：补写时是那一天，否则是今天。
  DateTime get _templateDiaryDate => _createDateOverride ?? _templateClock();

  /// 正文能插入日记链接；正在编辑的这篇不出现在候选里。
  DiaryLinkSource get _linkSource => DiaryLinkSource(diaryId: widget.diaryId);

  bool get _isCreateEntry =>
      widget.diaryId == null && widget.entryMode == EditDiaryEntryMode.create;
  bool get _isEditEntry =>
      widget.diaryId != null && widget.entryMode == EditDiaryEntryMode.edit;
  bool get _isEditPanelExpanded =>
      _isEditEntry && _editPanelExpandProgress.value >= 0.56;
  bool get _isEditingNoteText =>
      _titleFocusNode.hasFocus ||
      _contentFocusNode.hasFocus ||
      _toolbarFocusNode.hasFocus;

  void _onMediaImportChanged() {
    if (mounted) setState(() {});
  }

  /// 监听“补写时推荐当天照片”开关；设置服务异步就绪后才能绑定，绑定后
  /// 在下一帧同步一次（不在 build 中直接改控制器状态）。
  void _bindDayPhotoSettings(SettingsService settings) {
    if (identical(_dayPhotoSettings, settings)) return;
    _dayPhotoSettings?.dayPhotoSuggestionsEnabledNotifier.removeListener(
      _syncDayPhotos,
    );
    _dayPhotoSettings = settings;
    settings.dayPhotoSuggestionsEnabledNotifier.addListener(_syncDayPhotos);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDayPhotos();
    });
  }

  /// “这天的照片”看哪一天：新建为发表日期（没改过就是今天），编辑为日记的
  /// 发表时间（详情回填前为 null）；未来的日子（时间胶囊）没有照片可看。
  ///
  /// 顶栏菜单在 build 时直接据此决定是否显示入口，不依赖照片控制器的通知。
  DateTime? get _dayPhotosDay => DiaryDayPhotosController.diaryDay(
    _isCreateEntry ? _createDateOverride ?? DateTime.now() : _draftPublishAt,
  );

  /// 把日记那天与是否自动显示提示条交给照片控制器。提示条只在新建模式、
  /// 日期早于今天且编辑器设置开着时自动出现；顶栏菜单打开面板不受这些限制。
  void _syncDayPhotos() {
    _dayPhotos.configure(
      day: _dayPhotosDay,
      autoShow:
          _isCreateEntry &&
          DiaryDayPhotosController.backfillDay(_createDateOverride) != null &&
          (_dayPhotoSettings?.isDayPhotoSuggestionsEnabled ?? false),
    );
  }

  /// 面板输入同正文一样自动保存，新建模式继续沿用草稿链路。
  void _markEditPanelDirty() {
    _panelMetadataDirty = true;
    _controller.scheduleEditAutoSave();
  }

  /// 编辑模式下面板草稿每次真实变化都排程自动保存。详情回填（未初始化）
  /// 时的整体恢复不算修改；新建模式的草稿只随发布页往返，不走这里。
  ///
  /// 只改了所在日记本时不重组 metadata（那会刷新生成时间等字段），只记下
  /// “日记本改过”并排程保存；读回日记本时的恢复不算修改。
  void _onMetaChanged() {
    final previous = _lastMeta;
    final current = _meta.value;
    _lastMeta = current;
    // 发布页换了封面或清除封面时，“这天的照片”里的封面角标随之消失。
    _dayPhotos.syncCover(current.cover);
    if (!_isEditEntry || !_initialized) {
      return;
    }
    // 阅读式版式：信息栏与配色基调读面板草稿的当前值，改了立刻重建。
    _rebuildReading();
    final notebooksChanged = !setEquals(
      previous.notebookIds,
      current.notebookIds,
    );
    if (notebooksChanged && !_restoringNotebookIds) {
      _notebookIdsDirty = true;
    }
    final othersChanged =
        previous.copyWith(notebookIds: current.notebookIds) != current;
    if (othersChanged) {
      _markEditPanelDirty();
    } else if (notebooksChanged && _notebookIdsDirty) {
      _controller.scheduleEditAutoSave();
    }
  }

  void _onEditingFocusChanged() {
    if (_isEditEntry) _rebuildReading();
  }

  /// 阅读式版式重建页面：面板草稿变化（信息栏、头图、配色基调）与编辑焦点
  /// 进出（顶栏“完成”）。变化可能来自构建期间（极少：回填后的同步恢复），
  /// 那时推到这一帧之后。
  void _rebuildReading() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  /// 编辑模式读回这篇日记所在的日记本。在详情回填之后进行，读回之前用户
  /// 已经在面板里改过日记本时以用户的选择为准。用一次性查询而不是订阅：
  /// 编辑期间别处的收录变化不改面板（保存时也不写回，见 [_notebookIdsDirty]）。
  Future<void> _loadEditNotebooks(String diaryId) async {
    final ids = await _database.getDiaryNotebookIds(diaryId);
    if (!mounted || _notebookIdsDirty) return;
    _restoringNotebookIds = true;
    try {
      _meta.restore(
        _meta.value.copyWith(notebookIds: Set<String>.unmodifiable(ids)),
      );
    } finally {
      _restoringNotebookIds = false;
    }
  }

  /// 正文滚动容器的底部占位，也就是视口底部被浮层盖住、光标要让开的部分：
  /// 悬浮工具栏（连同光标上方的空隙）/录音面板优先；否则编辑模式在信息
  /// 面板挂着时按展开进度在 140~460 之间插值，面板不在时只留阅读版式的页尾
  /// 留白（与预览页相同，再让开系统导航条）。
  double _editorBottomSpacer(
    double panelProgress, {
    required bool showFloatingToolbar,
  }) {
    if (showFloatingToolbar) {
      if (_recordingPanelOpen) return _recordingPanelReservedSpace;
      if (_aiPanelOpen) {
        return _floatingToolbarReservedSpace +
            DiaryAiWritingPanel.reservedHeight;
      }
      return _floatingToolbarReservedSpace + _caretToolbarClearance;
    }
    if (!_isEditEntry) {
      return 16.0;
    }
    if (_metaPanelOpen) return _metaPanelBottomSpacer(panelProgress);
    return _readingBottomGap + MediaQuery.paddingOf(context).bottom;
  }

  /// 悬浮工具栏一排（不含面板）在正文底部占的高度，随工具栏大小变化。
  double get _floatingToolbarReservedSpace =>
      diaryToolbarBarHeight(_toolbarSize.scale) + _floatingToolbarGap;

  double _metaPanelBottomSpacer(double panelProgress) =>
      (lerpDouble(140, 460, panelProgress) ?? 140) + 16;

  /// 此刻被浮层盖住的高度：底部占位再加「更多」面板展开时的额外让位。
  double _editorBottomCover() =>
      _editorBottomSpacer(
        _editPanelExpandProgress.value,
        showFloatingToolbar: _floatingToolbarShown,
      ) +
      _toolbarPanelExtent.value;

  /// 汇总当前编辑态数据，形成可持久化的新建草稿对象。
  NewDiaryDraft get _currentCreateDraft => _meta.value.applyTo(
    NewDiaryDraft(
      title: _titleController.text,
      contentDocJson: _currentContentDocJson,
      contentText: _currentContentText,
      createdAtOverride: _createDateOverride,
      metadataJson: _metadataJson,
      notebookChapterIds: _createNotebookChapters,
    ),
  );

  /// 编辑模式的信息面板（与发布页同一组件）；区块直接写共享草稿，变化经
  /// [_onMetaChanged] 自动保存，这里只做装配。平时不挂载，点信息栏才挂上并
  /// 展开，收起时整块沉到底边之下、随后卸载（不留收起栏）。
  Widget _buildMetaPanel({required bool fillWidth}) {
    return PublishDiaryPanel(
      fillWidth: fillWidth,
      hideWhenCollapsed: true,
      controller: _editPanelController,
      draft: _meta,
      actions: _metaActions,
      busy: _saving,
      publishTime: PublishTimeOption(
        label: _controller.publishTimeLabelForEdit,
        onPick: _controller.pickPublishAtForEdit,
      ),
      onProgressChanged: (progress) {
        if (!mounted) {
          return;
        }
        final wasExpanded = _isEditPanelExpanded;
        // 连续进度只通知底部占位；页面层仅在越过展开阈值时
        // setState（切换正文锁定、悬浮工具栏等离散状态），收回到底时卸载。
        _editPanelExpandProgress.value = progress;
        _onMetaPanelProgress(progress);
        if (!_metaPanelOpen) return;
        final nextExpanded = _isEditPanelExpanded;
        if (wasExpanded == nextExpanded) {
          return;
        }
        if (nextExpanded) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
        setState(() {});
      },
    );
  }

  /// 元数据面板所在的列：铺满 body、贴底对齐，面板据此拿到可用高度，矮屏时
  /// 展开高度收缩。宽窗口（≥ 600）里与悬浮工具栏完全同一列——同样的左右
  /// 边距、最宽 760 居中，面板不再自行内缩，收起栏与叠在上方的工具栏同宽
  /// 同边；手机上照旧左右各 16、面板自己内缩。
  Widget _metaPanelColumn(Widget Function(bool wide) panel) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.medium;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? kDiaryFloatingToolbarInset : 16,
          ),
          child: CenteredContent(
            maxWidth: AppContentWidth.editor,
            child: Align(alignment: Alignment.bottomCenter, child: panel(wide)),
          ),
        );
      },
    );
  }

  /// 标题输入框。
  ///
  /// 使用下划线风格，焦点态颜色高亮以提供明确输入反馈；字体跟随正文排版设置。
  Widget _buildTitleInput(
    BuildContext context, {
    required bool contentLocked,
    required DiaryTextAppearance appearance,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = appearance.titleStyle(
      Theme.of(context).textTheme.headlineSmall,
    );
    return TextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      enabled: !contentLocked,
      readOnly: contentLocked,
      textAlignVertical: TextAlignVertical.top,
      buildCounter:
          (
            BuildContext context, {
            required int currentLength,
            required bool isFocused,
            int? maxLength,
          }) => null,
      style: titleStyle,
      maxLength: 200,
      decoration: InputDecoration(
        // 标题为空、正文有字时，旁边出现“AI 生成标题”（可在 AI 设置里关）。
        suffixIcon: _AiTitleButton(
          visible:
              !contentLocked &&
              ref.watch(aiModuleAvailableProvider(AiModule.suggest)) &&
              ref.watch(aiPreferencesProvider.select((p) => p.titleButton)),
          busy: _aiBusy,
          title: _titleController,
          content: _contentController,
          onPressed: () =>
              unawaited(_controller.suggestWithAi(titleOnly: true)),
        ),
        suffixIconConstraints: const BoxConstraints(),
        // 标题属于文档画布，不使用普通表单的填充表面。
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
        hintText: context.l10n.autoT0106,
        hintStyle: titleStyle?.copyWith(color: colorScheme.onSurfaceVariant),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      contextMenuBuilder: appTextContextMenuBuilder,
    );
  }

  /// 标题、模板与照片建议和正文共用 AppFlowy 的滚动，不再嵌套页面滚动容器。
  Widget _buildEditor(
    BuildContext context, {
    required double Function(double panelProgress) resolveBottomSpacer,
    required bool contentLocked,
    required DiaryTextAppearance appearance,
    required bool templatesEnabled,
    _ReadingFrame? reading,
  }) {
    // 宽窗口里标题与正文收成最宽 760 的一列居中：留白放在编辑器自己的左右
    // 内边距里（滚动视图仍铺满，滚动条留在窗口边缘），页头与正文同一组
    // 边距，段落把手跟着内边距落在列左侧（contentLeft）。手机上为 16。
    // 阅读式版式（编辑已有日记）改按预览页样式的边距与正文列宽，按编辑器
    // 实际拿到的宽度换算（与预览页的 atWidth 相同）。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth;
        final resolved = reading?.resolved.atWidth(width);
        return _buildEditorColumn(
          context,
          gutter: resolved == null
              ? AppContentWidth.gutter(width, AppContentWidth.editor)
              : _readingGutter(resolved, width),
          resolveBottomSpacer: resolveBottomSpacer,
          contentLocked: contentLocked,
          appearance: appearance,
          templatesEnabled: templatesEnabled,
          reading: reading,
          readingResolved: resolved,
        );
      },
    );
  }

  Widget _buildEditorColumn(
    BuildContext context, {
    required double gutter,
    required double Function(double panelProgress) resolveBottomSpacer,
    required bool contentLocked,
    required DiaryTextAppearance appearance,
    required bool templatesEnabled,
    _ReadingFrame? reading,
    DiaryPreviewResolvedStyle? readingResolved,
  }) {
    // 阅读式版式：页头、页尾与正文颜色按预览页样式；信息栏在页头或页尾
    // （按样式里的位置），只建一份。
    final readingMeta = reading == null || readingResolved == null
        ? null
        : _buildReadingMeta(
            reading.snapshot,
            readingResolved,
            notebooks: reading.notebooks,
            commentCount: reading.comments?.comments.length ?? 0,
            canRevealComments: reading.comments?.actions != null,
          );
    final readingTrailing = reading == null || readingResolved == null
        ? null
        : _buildReadingTrailing(
            context,
            frame: reading,
            resolved: readingResolved,
            meta: readingMeta,
          );
    final header = reading != null && readingResolved != null
        ? _buildReadingHeader(
            context,
            snapshot: reading.snapshot,
            resolved: readingResolved,
            appearance: appearance,
            contentLocked: contentLocked,
            meta: readingMeta,
          )
        : _buildClassicHeader(
            context,
            gutter: gutter,
            contentLocked: contentLocked,
            appearance: appearance,
            templatesEnabled: templatesEnabled,
          );
    return IgnorePointer(
      ignoring: contentLocked,
      // 自定义正文颜色（阅读式版式、通过对比度检查时）经 DefaultTextStyle
      // 交给正文，与预览页相同；没有时合并一个空样式，不改变什么。始终包
      // 这一层：颜色有无切换时组件树结构不变，编辑器不会重建。
      child: DefaultTextStyle.merge(
        style: TextStyle(color: readingResolved?.bodyColor),
        child: DiaryEditor(
          controller: _contentController,
          appearance: appearance,
          focusNode: _contentFocusNode,
          onMediaCommand: (kind) => unawaited(_controller.importMedia(kind)),
          onCameraCommand: AppPlatform.supportsCameraCapture
              ? (kind) => unawaited(_controller.captureMedia(kind))
              : null,
          onRecordingCommand: _recordingAvailable
              ? _toggleRecordingPanel
              : null,
          onAiCommand: _aiWritingAvailable
              ? (command) => unawaited(_controller.handleAiSlash(command))
              : null,
          aiPrompts: ref.watch(aiModuleAvailableProvider(AiModule.prompts)),
          placeholder: context.l10n.autoT0133,
          padding: EdgeInsets.symmetric(horizontal: gutter),
          header: header,
          scrollHandle: _readingScroll,
          autoScrollEdgeOffset: _editorBottomCover(),
          footer: Column(
            children: [
              ?readingTrailing,
              DiaryToolbarPanelReserve(extent: _toolbarPanelExtent),
              ValueListenableBuilder<double>(
                valueListenable: _editPanelExpandProgress,
                builder: (context, progress, _) => SizedBox(
                  key: const ValueKey('diary-editor-page-reserve'),
                  height: resolveBottomSpacer(progress),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 新建页的页头：表单式标题、模板建议条、这天的照片与写作灵感。
  Widget _buildClassicHeader(
    BuildContext context, {
    required double gutter,
    required bool contentLocked,
    required DiaryTextAppearance appearance,
    required bool templatesEnabled,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleInput(
            context,
            contentLocked: contentLocked,
            appearance: appearance,
          ),
          if (_isCreateEntry && templatesEnabled)
            DiaryTemplateStrip(
              controller: _templates,
              diaryDate: _templateDiaryDate,
              busy:
                  _saving ||
                  _recordingPanelOpen ||
                  _mediaImportController.isBusy,
              onApply: (template) =>
                  unawaited(_controller.applyTemplateFromStrip(template)),
              onOpenAll: () => unawaited(_controller.openTemplatePicker()),
            ),
          if (_isCreateEntry)
            DiaryDayPhotosStrip(
              controller: _dayPhotos,
              busy:
                  _saving ||
                  _recordingPanelOpen ||
                  _mediaImportController.isBusy,
              onInsert: () => unawaited(_controller.insertDayPhotos()),
              onSetCover: (photo) =>
                  unawaited(_controller.setDayPhotoCover(photo)),
              onClearCover: _controller.clearDayPhotoCover,
            ),
          // 写作灵感：新建空白日记、AI 可用且灵感模块与灵感条都开着时出现，
          // 开始写字后自己收起。
          if (_isCreateEntry &&
              ref.watch(aiModuleAvailableProvider(AiModule.prompts)) &&
              ref.watch(aiPreferencesProvider.select((p) => p.promptsStrip)))
            DiaryAiPromptsStrip(
              title: _titleController,
              content: _contentController,
              busy:
                  _saving || _bottomPanelOpen || _mediaImportController.isBusy,
              onGenerate: _generateAiPrompts,
              onPick: _insertAiPrompt,
            ),
        ],
      ),
    );
  }

  /// 顶栏“更多”菜单的动作；菜单项经 [ExpressiveMenuItem] 先关菜单再调用这里。
  void _onEditorMenuAction(_EditorMenuAction action) => switch (action) {
    _EditorMenuAction.chooseTemplate => unawaited(
      _controller.openTemplatePicker(),
    ),
    _EditorMenuAction.dayPhotos => unawaited(_controller.openDayPhotos()),
    _EditorMenuAction.saveAsTemplate => unawaited(_controller.saveAsTemplate()),
    _EditorMenuAction.editorSettings => unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const EditorSettingsPage(),
        ),
      ),
    ),
  };

  /// 首次拿到详情时回填编辑器、面板草稿与阅读式版式（只执行一次）。
  ///
  /// 在 State 的 build 里调用：改标题文字、恢复面板草稿都会通知监听者，但
  /// 那时 [_initialized] 仍为 false，自动保存与阅读式重建都不响应；需要
  /// 通知控制器的部分（这天的照片）推到这一帧之后。
  void _initializeFromDetail(DiaryWithTags detail) {
    _titleController.text = detail.diary.title;
    final document = editor.diaryEditorDocument(detail.diary.content);
    final caret = widget.initialCaret;
    final caretSelection = caret == null
        ? null
        : editor.DiaryEditorController.collapsedSelectionAt(document, caret);
    _controller.replaceContentController(
      editor.DiaryEditorController(
        document: document,
        selection:
            caretSelection ??
            editor.Selection.single(path: [0], startOffset: 0),
        linkSource: _linkSource,
      ),
    );
    // 预览页双击进来：光标已放在双击处，转场结束后聚焦弹出键盘，
    // 正文随键盘升起揭示光标（DiaryEditorViewport）。
    if (caretSelection != null) {
      _routeEntranceWaiter.schedule(this, _contentFocusNode.requestFocus);
    }
    try {
      _metadataJson = prettyMetadataJson(detail.diary.metadata);
    } catch (_) {
      _metadataJson = detail.diary.metadata;
    }
    // 面板字段从 metadata 读回；封面与标签以日记表的列为准。
    _meta.restore(
      PublishMetadataComposer.parse(detail.diary.metadata).copyWith(
        cover: normalizeOptionalText(detail.diary.cover),
        tagIds: Set<int>.unmodifiable(detail.tags.map((Tag tag) => tag.id)),
      ),
    );
    _draftPublishAt = detail.diary.createdAt;
    _panelMetadataDirty = false;
    _controller.initializeEditAutoSave();
    _initialized = true;
    unawaited(_loadEditNotebooks(detail.diary.diaryId));
    // “这天的照片”跟随日记的发表日期；configure 会通知监听者，不能在
    // build 中直接调用，放到这一帧之后。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDayPhotos();
    });
    _initReading(detail);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    // 信息面板只在点信息栏后挂着（见 _EditDiaryReadingActions._openMetaPanel）。
    final showEditMetaPanel = _isEditEntry && _metaPanelOpen;
    // 日记模板功能关闭时隐藏入口，数据保留：没有建议条，顶栏菜单里没有
    // “选择模板”与“另存为模板”（自动套用见 applyInitialTemplate）。
    final templatesEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.templates),
    );
    // AI 入口随 AI 助手的可用性与模块开关显隐（工具栏、`/` 菜单、选区菜单、
    // ⋮ 菜单与标题旁按钮）。
    final aiWriting = ref.watch(aiModuleAvailableProvider(AiModule.writing));
    final aiSuggest = ref.watch(aiModuleAvailableProvider(AiModule.suggest));
    _contentController.aiSelectionHandler = aiWriting
        ? () => unawaited(_controller.toggleAiPanel())
        : null;
    _contentController.aiImageDescriber =
        ref.watch(aiModuleAvailableProvider(AiModule.vision))
        ? _controller.describeImageWithAi
        : null;
    final settingsAsync = ref.watch(settingsServiceProvider);
    // 先绑定设置再判断显示条件：首次绑定在本次构建里同步读入“始终显示工具栏”。
    settingsAsync.whenData(_bindToolbarSettingsService);
    settingsAsync.whenData(_bindDayPhotoSettings);
    // 默认随软键盘出现：编辑标题或正文且键盘弹起时显示。焦点在工具栏内（颜色
    // 代码输入框）时不看键盘高度：焦点从正文交给输入框时，输入法可能先收起
    // 再弹出，键盘高度会短暂归零；此时卸载工具栏会连同面板与输入框一起丢掉。
    // 打开“始终显示工具栏”后不看键盘与焦点（接实体键盘时软键盘不弹出），
    // 只在信息面板挂着时让位；桌面上一直如此（见 [_toolbarAlwaysShown]）。
    final rawShowFloatingToolbar =
        _hasFloatingToolbar &&
        !_metaPanelOpen &&
        (_toolbarAlwaysShown ||
            ((keyboardInset > 0 || _toolbarFocusNode.hasFocus) &&
                _isEditingNoteText));
    final enabledToolbarOrder = filterEnabledDiaryToolbarOrder(
      _toolbarOrder,
      _effectiveToolbarHiddenItems,
    );
    final showFloatingToolbar =
        enabledToolbarOrder.isNotEmpty &&
        (rawShowFloatingToolbar ||
            (_hasFloatingToolbar && _bottomPanelOpen && !_metaPanelOpen));
    _floatingToolbarShown = showFloatingToolbar;
    // 悬浮工具栏、录音面板与元数据面板同属“工具栏”材质。玻璃时它们外面的
    // 入场与淡出都改用 GlassReveal（见 ExpressiveEntrance.glass），不再套
    // Opacity——透明度层里的玻璃采不到下面的正文。只影响外观，遮挡高度与
    // 正文末尾占位不随材质变化。
    final toolbarGlass = AppGlass.of(
      context,
    ).isGlass(AppGlassComponent.toolbar);
    // 面板进度由 ValueNotifier 驱动，占位随之局部刷新，不触发整页重建。
    double resolveEditorBottomSpacer(double panelProgress) =>
        _editorBottomSpacer(
          panelProgress,
          showFloatingToolbar: showFloatingToolbar,
        );

    final queried = widget.diaryId == null
        ? const AsyncData<DiaryWithTags?>(null)
        : ref.watch(diaryDetailProvider(widget.diaryId!));
    // 入口已持有同一篇时，查询返回前直接用它：路由滑入时就是完整页面，头图
    // 共享元素有落点。
    final initialDetail = widget.initialDetail;
    final detailAsync =
        initialDetail != null && !queried.hasValue && !queried.hasError
        ? AsyncData<DiaryWithTags?>(initialDetail)
        : queried;
    // 首次拿到详情时回填编辑器与草稿上下文（后续重建不重复执行）。放在本
    // State 的 build 里：阅读式版式这一帧就要用到回填的内容。
    final loadedDetail = detailAsync.value;
    if (!_initialized && loadedDetail != null) {
      _initializeFromDetail(loadedDetail);
    }
    // 编辑已有日记：与预览页同一版式（页头、页尾、主题与边距）。
    final reading = _readingFrame(context);

    // 编辑页统一处理三态：加载中 / 加载失败 / 数据可用。三态都画编辑区域的
    // 背景（AppPageBackground 在 Scaffold 外面、按路由尺寸铺满，键盘弹出时
    // 不缩放不移动）；页面底色经 Builder 从背景组件之下读：有背景时透明。
    // 没有背景时 pageColor 就是 surface，与接入前一致。
    // 在本 State 的 build 里订阅：下面 Builder 的 build 不在本元素的依赖
    // 记录窗口内，在那里 watch 会在每次重建时退订再重订。
    final appearance = ref.watch(diaryTextAppearanceProvider);
    return AppPageBackground(
      // 阅读式版式与预览页同一背景区域：页面与预览页看起来一样。
      area: _isEditEntry ? AppBackgroundArea.preview : AppBackgroundArea.editor,
      child: Builder(
        builder: (BuildContext context) {
          final pageColor = AppPageBackdrop.pageColorOf(context);
          return detailAsync.when(
            loading: () => Scaffold(
              backgroundColor: pageColor,
              body: const DelayedLoadingIndicator(),
            ),
            error: (Object error, StackTrace stackTrace) => Scaffold(
              backgroundColor: pageColor,
              appBar: AppTopBar(
                contentMaxWidth: AppContentWidth.editor,
                leading: IconButton(
                  tooltip: context.l10n.commonBack,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
                ),
              ),
              body: Center(
                child: Text(context.l10n.autoT0121(error.toString())),
              ),
            ),
            data: (DiaryWithTags? detail) {
              // 工具栏顺序和启用状态已在外层解析，避免详情流重建时重复解析设置。

              if (widget.diaryId != null && detail == null) {
                return Scaffold(
                  backgroundColor: pageColor,
                  appBar: AppTopBar(
                    contentMaxWidth: AppContentWidth.editor,
                    leading: IconButton(
                      tooltip: context.l10n.commonBack,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
                    ),
                  ),
                  body: Center(child: Text(context.l10n.autoT0124)),
                );
              }

              final showDayPhotosMenu =
                  _dayPhotos.library.isSupported && _dayPhotosDay != null;
              // 阅读式版式在整页主题（配色基调、纸张深浅）之下构建：下面的
              // 组件都按换过的主题取色。始终包 Theme，主题切换时结构不变。
              Widget buildScaffold(BuildContext context) => Scaffold(
                backgroundColor: reading == null
                    ? pageColor
                    : diaryPreviewScaffoldColor(context, reading.resolved),
                appBar: reading != null
                    ? _buildReadingTopBar(context, frame: reading)
                    : AppTopBar(
                        contentMaxWidth: AppContentWidth.editor,
                        leading: IconButton(
                          tooltip: context.l10n.commonBack,
                          onPressed: _controller.attemptExit,
                          icon: const FaIcon(
                            FontAwesomeIcons.angleLeft,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          widget.entryMode == EditDiaryEntryMode.create
                              ? context.l10n.autoT0134
                              : context.l10n.autoT0135,
                        ),
                        actions: <Widget>[
                          ExpressiveMenuButton(
                            tooltip: context.l10n.diaryEditorMoreActions,
                            icon: const FaIcon(
                              FontAwesomeIcons.ellipsisVertical,
                              size: 18,
                            ),
                            items: <Widget>[
                              // 只在新建空白日记里出现（编辑已有日记、续写草稿时没有）。
                              if (_templates.enabled && templatesEnabled)
                                ExpressiveMenuItem(
                                  leadingIcon: const FaIcon(
                                    FontAwesomeIcons.wandMagicSparkles,
                                  ),
                                  onPressed:
                                      _saving ||
                                          _recordingPanelOpen ||
                                          _mediaImportController.isBusy
                                      ? null
                                      : () => _onEditorMenuAction(
                                          _EditorMenuAction.chooseTemplate,
                                        ),
                                  child: Text(context.l10n.diaryTemplateChoose),
                                ),
                              // 新建与编辑都有，与“自动显示当天照片”开关无关；未来日期
                              // 与不支持读取相册的平台没有。
                              if (showDayPhotosMenu)
                                ExpressiveMenuItem(
                                  leadingIcon: const FaIcon(
                                    FontAwesomeIcons.solidImages,
                                  ),
                                  onPressed:
                                      _saving ||
                                          _recordingPanelOpen ||
                                          _mediaImportController.isBusy
                                      ? null
                                      : () => _onEditorMenuAction(
                                          _EditorMenuAction.dayPhotos,
                                        ),
                                  child: Text(context.l10n.diaryDayPhotosMenu),
                                ),
                              if (ref.watch(
                                aiModuleAvailableProvider(AiModule.prompts),
                              ))
                                ExpressiveMenuItem(
                                  leadingIcon: const FaIcon(
                                    FontAwesomeIcons.lightbulb,
                                  ),
                                  onPressed: _saving || _bottomPanelOpen
                                      ? null
                                      : () => unawaited(_openAiPrompts()),
                                  child: Text(context.l10n.aiSlashPrompts),
                                ),
                              if (aiSuggest) ...<Widget>[
                                ExpressiveMenuItem(
                                  leadingIcon: const FaIcon(
                                    FontAwesomeIcons.heading,
                                  ),
                                  onPressed:
                                      _saving || _aiBusy || _bottomPanelOpen
                                      ? null
                                      : () => unawaited(
                                          _controller.suggestWithAi(
                                            titleOnly: true,
                                          ),
                                        ),
                                  child: Text(context.l10n.aiSuggestTitle),
                                ),
                                ExpressiveMenuItem(
                                  leadingIcon: const FaIcon(
                                    FontAwesomeIcons.wandMagicSparkles,
                                  ),
                                  onPressed:
                                      _saving || _aiBusy || _bottomPanelOpen
                                      ? null
                                      : () => unawaited(
                                          _controller.suggestWithAi(
                                            titleOnly: false,
                                          ),
                                        ),
                                  child: Text(context.l10n.aiSuggestMeta),
                                ),
                              ],
                              if (templatesEnabled)
                                ExpressiveMenuItem(
                                  leadingIcon: const FaIcon(
                                    FontAwesomeIcons.layerGroup,
                                  ),
                                  onPressed: () => _onEditorMenuAction(
                                    _EditorMenuAction.saveAsTemplate,
                                  ),
                                  child: Text(context.l10n.diaryTemplateSaveAs),
                                ),
                              ExpressiveMenuItem(
                                leadingIcon: const FaIcon(
                                  FontAwesomeIcons.penNib,
                                ),
                                onPressed: () => _onEditorMenuAction(
                                  _EditorMenuAction.editorSettings,
                                ),
                                child: Text(context.l10n.settingsEditorTitle),
                              ),
                            ],
                          ),
                          if (widget.entryMode == EditDiaryEntryMode.create)
                            IconButton(
                              onPressed:
                                  _saving ||
                                      _recordingPanelOpen ||
                                      _mediaImportController.isBusy
                                  ? null
                                  : _controller.openPublishPage,
                              icon: const FaIcon(FontAwesomeIcons.plus),
                              tooltip: context.l10n.autoT0136,
                            ),
                        ],
                      ),
                // 底部键盘弹起时（或打开了“始终显示工具栏”时）显示悬浮工具栏，并对
                // 正文底部做避让。
                body: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    // 软键盘“选择”模式的方向键在 Flutter 3.47 上只会移动光标，这里
                    // 为标题与正文补回扩选（见 [SoftKeyboardSelectionKeys]）。
                    // 桌面上可以把文件拖进正文（手机上 DiaryEditorDropTarget 原样
                    // 返回子树）；面板展开、录音或保存中不接收。
                    DiaryEditorDropTarget(
                      enabled:
                          !_saving &&
                          !_isEditPanelExpanded &&
                          !_bottomPanelOpen,
                      onDropFiles: (paths) =>
                          unawaited(_controller.insertDroppedFiles(paths)),
                      child: SoftKeyboardSelectionKeys(
                        child: _buildEditor(
                          context,
                          resolveBottomSpacer: resolveEditorBottomSpacer,
                          contentLocked:
                              _isEditPanelExpanded || _bottomPanelOpen,
                          appearance: appearance,
                          templatesEnabled: templatesEnabled,
                          reading: reading,
                        ),
                      ),
                    ),
                    if (showEditMetaPanel)
                      // 铺满 body、贴底对齐：面板据此拿到可用高度，矮屏时展开高度收缩。
                      // 两个浮层都带 key：面板插在已有的工具栏之前时，按位置匹配会
                      // 把工具栏的 Element 交给面板，工具栏重建、丢掉「更多」与颜色
                      // 面板的状态并重播入场动画。面板自己从底边升起（收起即离场），
                      // 不再套入场动画。
                      Positioned.fill(
                        key: const ValueKey<String>('edit-meta-panel'),
                        child: _metaPanelColumn(
                          (bool wide) => _buildMetaPanel(fillWidth: wide),
                        ),
                      ),
                    if (showFloatingToolbar)
                      Positioned(
                        key: const ValueKey<String>('edit-floating-toolbar'),
                        left: kDiaryFloatingToolbarInset,
                        right: kDiaryFloatingToolbarInset,
                        // Scaffold 已根据键盘缩小 body，高度不需要再叠加 keyboardInset。
                        bottom: 0,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final safeBottom = math.max(
                              MediaQuery.paddingOf(context).bottom,
                              8.0,
                            );
                            // 宽窗口里与正文列同宽居中（最宽 760）；手机上铺满。
                            return CenteredContent(
                              maxWidth: AppContentWidth.editor,
                              child: ExpressiveEntrance(
                                glass: toolbarGlass,
                                child: SafeArea(
                                  top: false,
                                  minimum: const EdgeInsets.only(bottom: 8),
                                  // 录音面板插入/移除时整列高度平滑变化，工具栏随之
                                  // 上移，不再瞬间跳到 300dp 之上。
                                  child: AnimatedSize(
                                    duration: ExpressiveMotion.durationNonZero(
                                      context,
                                      ExpressiveMotion.medium,
                                    ),
                                    curve: ExpressiveMotion.effects,
                                    alignment: Alignment.bottomCenter,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        DiaryFloatingToolbarSurface(
                                          child: Focus(
                                            focusNode: _toolbarFocusNode,
                                            // 焦点在正文与颜色代码输入框之间交接
                                            // 时，按新的焦点重新判断工具栏是否显示。
                                            onFocusChange: (_) =>
                                                setState(() {}),
                                            child: _buildFloatingToolbar(
                                              enabledToolbarOrder,
                                              // 面板最多铺满工具栏上方的整块正文
                                              // 区，极矮的窗口里改为面板内滚动而
                                              // 不溢出。
                                              maxPanelExtent:
                                                  constraints.maxHeight -
                                                  safeBottom -
                                                  diaryToolbarBarHeight(
                                                    _toolbarSize.scale,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        if (_recordingPanelOpen) ...[
                                          const SizedBox(height: 8),
                                          ExpressiveEntrance(
                                            glass: toolbarGlass,
                                            child: _buildRecordingPanel(),
                                          ),
                                        ],
                                        if (_aiSession case final session?) ...[
                                          const SizedBox(height: 8),
                                          ExpressiveEntrance(
                                            glass: toolbarGlass,
                                            child: _buildAiPanel(session),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    DiaryMediaImportOverlay(
                      copying: _mediaImportController.isCopying,
                    ),
                    // 阅读式版式里分享与导出时的加载遮罩（与预览页相同）。
                    if (reading != null)
                      Positioned.fill(
                        key: const ValueKey<String>('edit-reading-loading'),
                        child: ListenableBuilder(
                          listenable: _readingExport,
                          builder: (BuildContext context, Widget? _) =>
                              ActionLoadingOverlay(
                                visible: _readingExport.showLoading,
                                label: _readingExport.loadingLabel,
                              ),
                        ),
                      ),
                  ],
                ),
              );
              final scaffold = reading == null
                  ? buildScaffold(context)
                  : Theme(
                      data: reading.resolved.theme,
                      child: Builder(builder: buildScaffold),
                    );
              // 根节点必须恒为 PopScope：若按 `_recordingPanelOpen` 在 Scaffold 与
              // PopScope(Scaffold) 之间切换，根 widget 类型变化会销毁整棵子树，
              // 连带 原生块编辑器、播放器与输入法连接一起重建。只用 canPop 表达差异。
              return PopScope(
                // 编辑模式返回时先补存最后一次输入，面板和录音仍优先收起。
                canPop: !_isEditEntry && !_bottomPanelOpen,
                onPopInvokedWithResult: (didPop, result) {
                  if (!didPop) {
                    unawaited(_controller.attemptExit());
                    return;
                  }
                  // 新建模式直接返回：补存防抖窗口里的输入，草稿静默留在草稿箱。
                  if (_isCreateEntry) unawaited(_controller.flushCreateDraft());
                },
                // 桌面上 Esc 与顶栏返回按钮相同（补存、先收起面板与录音）。
                child: DesktopPageKeys(
                  onEscape: () => unawaited(_controller.attemptExit()),
                  child: scaffold,
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 绑定设置服务中的工具栏可见性配置。
  ///
  /// 设置页保存后只会更新 [SettingsService] 内部 ValueNotifier，
  /// 编辑页需要监听这些 notifier，才能在返回编辑器时立刻刷新悬浮工具栏。
  void _bindToolbarSettingsService(SettingsService settingsService) {
    if (identical(_boundToolbarSettingsService, settingsService)) {
      _applyToolbarSettings(settingsService, notify: false);
      return;
    }
    _unbindToolbarSettingsService();
    _boundToolbarSettingsService = settingsService;
    _toolbarSettingsListener = () {
      _applyToolbarSettings(settingsService, notify: true);
    };
    settingsService.diaryToolbarOrderRawNotifier.addListener(
      _toolbarSettingsListener!,
    );
    settingsService.diaryToolbarHiddenItemsRawNotifier.addListener(
      _toolbarSettingsListener!,
    );
    settingsService.diaryToolbarCurrentTimeFormatRawNotifier.addListener(
      _toolbarSettingsListener!,
    );
    settingsService.diaryToolbarAlwaysVisibleNotifier.addListener(
      _toolbarSettingsListener!,
    );
    settingsService.diaryToolbarSizeRawNotifier.addListener(
      _toolbarSettingsListener!,
    );
    _applyToolbarSettings(settingsService, notify: false);
  }

  void _unbindToolbarSettingsService() {
    final settingsService = _boundToolbarSettingsService;
    final listener = _toolbarSettingsListener;
    if (settingsService != null && listener != null) {
      settingsService.diaryToolbarOrderRawNotifier.removeListener(listener);
      settingsService.diaryToolbarHiddenItemsRawNotifier.removeListener(
        listener,
      );
      settingsService.diaryToolbarCurrentTimeFormatRawNotifier.removeListener(
        listener,
      );
      settingsService.diaryToolbarAlwaysVisibleNotifier.removeListener(
        listener,
      );
      settingsService.diaryToolbarSizeRawNotifier.removeListener(listener);
    }
    _boundToolbarSettingsService = null;
    _toolbarSettingsListener = null;
  }

  void _applyToolbarSettings(
    SettingsService settingsService, {
    required bool notify,
  }) {
    final nextOrder = decodeDiaryToolbarOrder(
      settingsService.diaryToolbarOrderRaw,
    );
    final nextHiddenItems = decodeDiaryToolbarHiddenItems(
      settingsService.diaryToolbarHiddenItemsRaw,
    );
    final nextCurrentTimeFormat =
        settingsService.diaryToolbarCurrentTimeFormatRaw;
    final nextAlwaysVisible = settingsService.isDiaryToolbarAlwaysVisible;
    final nextSize = DiaryToolbarSize.decode(
      settingsService.diaryToolbarSizeRaw,
    );
    if (nextAlwaysVisible == _toolbarAlwaysVisible &&
        nextSize == _toolbarSize &&
        _hasSameToolbarSettings(
          nextOrder,
          nextHiddenItems,
          nextCurrentTimeFormat,
        )) {
      return;
    }
    void apply() {
      _toolbarOrder = nextOrder;
      _toolbarHiddenItems = nextHiddenItems;
      _toolbarCurrentTimeFormatPattern = nextCurrentTimeFormat;
      _toolbarAlwaysVisible = nextAlwaysVisible;
      _toolbarSize = nextSize;
    }

    if (notify && mounted) {
      setState(apply);
      return;
    }
    apply();
  }

  bool _hasSameToolbarSettings(
    List<DiaryToolbarItem> nextOrder,
    Set<DiaryToolbarItem> nextHiddenItems,
    String? nextCurrentTimeFormat,
  ) {
    if (_toolbarOrder.length != nextOrder.length ||
        _toolbarHiddenItems.length != nextHiddenItems.length ||
        _toolbarCurrentTimeFormatPattern != nextCurrentTimeFormat) {
      return false;
    }
    for (var index = 0; index < nextOrder.length; index += 1) {
      if (_toolbarOrder[index] != nextOrder[index]) {
        return false;
      }
    }
    for (final item in nextHiddenItems) {
      if (!_toolbarHiddenItems.contains(item)) {
        return false;
      }
    }
    return true;
  }

  Widget _buildFloatingToolbar(
    List<DiaryToolbarItem> toolbarOrder, {
    required double maxPanelExtent,
  }) {
    return DiaryFloatingToolbar(
      controller: _contentController,
      order: toolbarOrder,
      hiddenItems: _effectiveToolbarHiddenItems,
      currentTimeFormatPattern: _toolbarCurrentTimeFormatPattern,
      onRecordingPressed: _toggleRecordingPanel,
      recordingOpen: _recordingPanelOpen,
      onAiPressed: _aiWritingAvailable
          ? () => unawaited(_controller.toggleAiPanel())
          : null,
      aiOpen: _aiPanelOpen,
      mediaImportController: _mediaImportController,
      onMediaPressed: (kind) => unawaited(_controller.importMedia(kind)),
      onCameraPressed: AppPlatform.supportsCameraCapture
          ? (kind) => unawaited(_controller.captureMedia(kind))
          : null,
      onPanelExtentChanged: _handleToolbarPanelExtentChanged,
      maxPanelExtent: maxPanelExtent,
      savedColors: ref.watch(diarySavedColorsProvider),
      onEditSavedColors: ref.read(diarySavedColorsProvider.notifier).edit,
      size: _toolbarSize,
    );
  }

  /// 「更多」面板展开/收起：正文末尾留白跟着变（见 [DiaryToolbarPanelReserve]）；
  /// 展开时若光标会被面板挡住，在留白生效的下一帧把它滚到面板上方。
  /// 编辑标题时光标不在正文里，不滚动。
  void _handleToolbarPanelExtentChanged(double extent) {
    if (!mounted) {
      return;
    }
    final grew = extent > _toolbarPanelExtent.value;
    _toolbarPanelExtent.value = extent;
    if (!grew || !_contentFocusNode.hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selection = _contentController.selection;
      if (!mounted || selection == null) {
        return;
      }
      revealDiaryEditorCaretAbove(
        _contentController,
        // 被遮住的高度 = 工具栏一排、底部留白与光标空隙（与平时的正文避让
        // 一致）+ 面板。
        coveredHeight: _editorBottomCover(),
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      );
    });
  }

  Widget _buildRecordingPanel() {
    return AnimatedBuilder(
      animation: _recordingController,
      builder: (BuildContext context, Widget? child) {
        return DiaryRecordingPanel(
          phase: _recordingController.phase,
          elapsed: _recordingController.elapsed,
          failure: _recordingController.failure,
          waveform: _recordingController.waveform,
          recordingName: _recordingController.name,
          onNameChanged: _recordingController.setName,
          onStart: () => unawaited(_controller.startRecording()),
          onPause: () => unawaited(_recordingController.pause()),
          onResume: () => unawaited(_recordingController.resume()),
          onFinish: () => unawaited(_controller.finishRecording()),
          onClose: _closeRecordingPanel,
        );
      },
    );
  }

  Widget _buildAiPanel(AiWritingSession session) {
    final l10n = context.l10n;
    final prefs = ref.watch(aiPreferencesProvider);
    return DiaryFloatingToolbarSurface(
      child: DiaryAiWritingPanel(
        session: session,
        actions: aiWritingActions(l10n, l10n, prefs),
        showReasoning: prefs.showReasoning,
        onAction: (action) => unawaited(_controller.runAiAction(action)),
        onInstruction: (text) => unawaited(_controller.runAiInstruction(text)),
        onApply: _controller.applyAiResult,
        onCopy: (text) => unawaited(copyAiResult(context, text)),
        onClose: _controller.closeAiPanel,
      ),
    );
  }

  /// 为这篇（新建时按所选日期）生成写作灵感。
  Future<List<String>?> _generateAiPrompts() => requestAiPrompts(
    context,
    ref,
    date: _isCreateEntry
        ? _templateDiaryDate
        : _draftPublishAt ?? DateTime.now(),
    weather: _meta.value.weather,
  );

  /// 把选中的问题按设置的样式插进正文（一步撤销）。
  void _insertAiPrompt(String question) {
    insertDiaryAiPrompt(
      _contentController,
      question,
      ref.read(aiPreferencesProvider).promptStyle,
    );
    _contentFocusNode.requestFocus();
  }

  /// 写作灵感面板（`/` 菜单与 ⋮ 菜单）：挑一个问题插在光标处。
  Future<void> _openAiPrompts() async {
    final question = await showDiaryAiPromptsSheet(
      context,
      generate: _generateAiPrompts,
    );
    if (question == null || !mounted) return;
    _insertAiPrompt(question);
  }

  void _toggleRecordingPanel() {
    if (_mediaImportController.isBusy) return;
    // 录音面板与 AI 写作面板在同一位置，打开一个先收起另一个。
    if (_aiPanelOpen) _controller.closeAiPanel();
    if (_recordingPanelOpen) {
      _closeRecordingPanel();
      return;
    }

    setState(() {
      _recordingPanelOpen = true;
      _recordingPanelGeneration++;
      _recordingSelection = _contentController.selection;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _closeRecordingPanel() {
    if (!_recordingPanelOpen) {
      return;
    }
    unawaited(_recordingController.cancel());
    setState(() {
      _recordingPanelOpen = false;
      _recordingPanelGeneration++;
      _recordingSelection = null;
    });
  }
}

/// 标题旁的“AI 生成标题”：标题为空、正文有字时才出现（跟随输入实时
/// 显隐），生成中显示加载状态。
class _AiTitleButton extends StatelessWidget {
  const _AiTitleButton({
    required this.visible,
    required this.busy,
    required this.title,
    required this.content,
    required this.onPressed,
  });

  final bool visible;
  final bool busy;
  final TextEditingController title;
  final editor.DiaryEditorController content;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[title, content]),
      builder: (BuildContext context, Widget? child) {
        if (title.text.trim().isNotEmpty || !content.hasContent) {
          return const SizedBox.shrink();
        }
        return IconButton(
          tooltip: context.l10n.aiSuggestTitle,
          visualDensity: VisualDensity.compact,
          onPressed: busy ? null : onPressed,
          icon: FaIcon(
            FontAwesomeIcons.wandMagicSparkles,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }
}

enum EditDiaryEntryMode { create, edit }

/// 顶栏菜单：选择模板（只在新建空白日记）、这天的照片（日记那天不晚于今天
/// 且平台能读相册时）、存为模板、编辑器设置。
enum _EditorMenuAction {
  chooseTemplate,
  dayPhotos,
  saveAsTemplate,
  editorSettings,
}
