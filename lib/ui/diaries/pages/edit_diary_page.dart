import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
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
import 'package:node_diary/ui/diaries/models/diary_playback_gestures.dart';
import 'package:node_diary/ui/diaries/controllers/diary_location_preference.dart';
import 'package:node_diary/ui/diaries/controllers/diary_meta_actions.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_recording_controller.dart';
import 'package:node_diary/ui/diaries/controllers/debounced_auto_save_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_media_import_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_caret_follow_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_audio_player_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_day_photos_controller.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/utils/optional_text.dart';
import 'package:node_diary/ui/diaries/providers/diary_detail_provider.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_quill_styles.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_floating_toolbar_surface.dart';
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
import 'package:node_diary/ui/settings/widgets/style_editor/style_editor_common.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:node_diary/ui/widgets/soft_keyboard_selection_keys.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_entrance.dart';
import 'package:node_diary/ui/widgets/route_entrance_waiter.dart';

part '../controllers/edit_diary_controller.dart';
part '../controllers/edit_diary_persistence_controller.dart';
part '../controllers/edit_diary_recording_controller.dart';
part '../controllers/edit_diary_media_controller.dart';
part '../controllers/edit_diary_template_flow.dart';

/// 日记编辑页。
///
/// - `diaryId == null`：新建模式（[createDraftId] 为 null 时新建空白，否则续写
///   草稿箱里的那一份）；每次新建都是草稿箱里独立的一份，自动保存，发布后删除
/// - `diaryId != null`：编辑模式
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

  @override
  ConsumerState<EditDiaryPage> createState() => _EditDiaryPageState();
}

class _EditDiaryPageState extends ConsumerState<EditDiaryPage>
    with WidgetsBindingObserver {
  static const double _floatingToolbarReservedSpace = 56.0;
  static const double _recordingPanelReservedSpace = 310.0;
  // 键盘弹起时光标与悬浮工具栏之间留出的空隙：光标贴着工具栏时下一行没有
  // 余地、读起来像被压住。底部占位同样加上它，最后一行才能被顶到这么高。
  static const double _caretToolbarClearance = 40.0;

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
  final ScrollController _contentScrollController = ScrollController();
  final ScrollController _editorInnerScrollController = ScrollController();
  // 用于取光标矩形：「更多」面板展开时把光标滚到面板上方。
  final GlobalKey<quill.EditorState> _quillEditorKey =
      GlobalKey<quill.EditorState>();
  // 悬浮工具栏「更多」面板的目标高度（收起为 0），驱动正文末尾的额外留白。
  final ValueNotifier<double> _toolbarPanelExtent = ValueNotifier<double>(0);
  // 打字、键盘扩选与软键盘弹起时把光标保持在底部浮层上方（正文不自带滚动）。
  late final DiaryCaretFollowController _caretFollow;
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
  late quill.QuillController _contentController;
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
  // 缓存 QuillEditor widget 实例：键盘动画期间页面会随 viewInsets 逐帧重建，
  // LayoutBuilder 也会随 body 高度逐帧重跑；返回同一实例时 Element 直接跳过
  // 更新，避免 QuillRawEditor 对整篇文档逐行重建子树。输入变化时才重建。
  Widget? _cachedQuillEditor;
  Object? _cachedQuillEditorInputs;
  late List<DiaryToolbarItem> _toolbarOrder;
  Set<DiaryToolbarItem> _toolbarHiddenItems = <DiaryToolbarItem>{};
  String? _toolbarCurrentTimeFormatPattern;
  SettingsService? _boundToolbarSettingsService;
  VoidCallback? _toolbarSettingsListener;
  bool _recordingPanelOpen = false;
  int _recordingPanelGeneration = 0;
  TextSelection? _recordingSelection;

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

  bool get _isMobileRuntime {
    final platform = defaultTargetPlatform;
    return !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
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
    final presetCapsule = widget.createCapsuleUnlockAt;
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
      onUsed: (templateId) async {
        final settings = await ref.read(settingsServiceProvider.future);
        await recordDiaryTemplateUse(settings, templateId);
      },
    );
    _contentController = quill.QuillController(
      document: documentFromPlainText(''),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _caretFollow = DiaryCaretFollowController(
      editorKey: _quillEditorKey,
      focusNode: _contentFocusNode,
      coveredHeight: _editorBottomCover,
      revealDuration: () =>
          ExpressiveMotion.duration(context, ExpressiveMotion.fast),
    )..attach(_contentController);
    _toolbarOrder = List<DiaryToolbarItem>.from(kDefaultDiaryToolbarOrder);
    _controller = EditDiaryController(this);
    _mediaImportController.addListener(_onMediaImportChanged);
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
    _caretFollow.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _toolbarFocusNode.dispose();
    _contentScrollController.dispose();
    _editorInnerScrollController.dispose();
    _editPanelExpandProgress.dispose();
    _toolbarPanelExtent.dispose();
    _contentController.dispose();
    _recordingController.dispose();
    _unbindToolbarSettingsService();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = mounted ? View.maybeOf(context) : null;
    if (view != null) {
      _caretFollow.handleKeyboardInset(view.viewInsets.bottom);
    }
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
  String get _currentContentText =>
      extractPlainTextFromDiaryDocument(_contentController.document);

  /// 当前正文 Delta JSON（用于富文本持久化）。
  String get _currentContentDocJson =>
      encodeDiaryDocumentToJson(_contentController.document);

  /// 模板变量按哪天展开、推荐按哪天判断：补写时是那一天，否则是今天。
  DateTime get _templateDiaryDate => _createDateOverride ?? _templateClock();

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
  /// 悬浮工具栏（连同光标上方的空隙）/录音面板优先；否则编辑模式按元数据
  /// 面板展开进度在 140~460 之间插值。
  double _editorBottomSpacer(
    double panelProgress, {
    required bool showFloatingToolbar,
  }) {
    if (showFloatingToolbar) {
      return _recordingPanelOpen
          ? _recordingPanelReservedSpace
          : _floatingToolbarReservedSpace + _caretToolbarClearance;
    }
    if (!_isEditEntry) {
      return 16.0;
    }
    return (lerpDouble(140, 460, panelProgress) ?? 140) + 16;
  }

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

  /// 编辑模式底部元数据面板（与发布页同一组件）；区块直接写共享草稿，
  /// 变化经 [_onMetaChanged] 自动保存，这里只做装配。
  Widget _buildMetaPanel() {
    return PublishDiaryPanel(
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
        // setState（切换正文锁定、悬浮工具栏等离散状态）。
        _editPanelExpandProgress.value = progress;
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
    );
  }

  Widget _buildQuillEditor(
    BuildContext context, {
    required DiaryTextAppearance appearance,
  }) {
    final placeholder = context.l10n.autoT0133;
    // QuillController 未覆写 ==，按实例比较；ThemeData 与正文外观为值比较。
    final inputs = (
      _contentController,
      placeholder,
      Theme.of(context),
      appearance,
    );
    final cached = _cachedQuillEditor;
    if (cached != null && _cachedQuillEditorInputs == inputs) {
      return cached;
    }
    // 样式在编辑器位置（Scaffold 之下）生成，见 [DiaryQuillStylesBuilder]。
    final editor = DiaryQuillStylesBuilder(
      appearance: appearance,
      builder: (BuildContext context, quill.DefaultStyles styles) {
        return quill.QuillEditor.basic(
          controller: _contentController,
          focusNode: _contentFocusNode,
          scrollController: _editorInnerScrollController,
          // 新建时不在构建期自动聚焦：键盘会与页面滑入同时弹出并逐帧挤压布局。
          // 改由 [RouteEntranceWaiter] 在转场结束后聚焦（见 initState）。
          config: quill.QuillEditorConfig(
            editorKey: _quillEditorKey,
            autoFocus: false,
            placeholder: placeholder,
            scrollable: false,
            onTapUp: (details, getPosition) => isDiaryPlaybackTap(
              _contentController,
              getPosition(details.globalPosition),
            ),
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
            customStyles: styles,
            embedBuilders: buildDiaryQuillEmbedBuilders(),
          ),
        );
      },
    );
    _cachedQuillEditor = editor;
    _cachedQuillEditorInputs = inputs;
    return editor;
  }

  /// 主编辑区域：
  /// - 标题与正文放在同一个滚动容器内，保证滚动体验连续；
  /// - 键盘弹起时保持焦点，不因轻微滚动自动收起键盘；
  /// - 标题字体与正文排版跟随“正文字体与排版”设置，修改后即时生效。
  Widget _buildEditor(
    BuildContext context, {
    required double Function(double panelProgress) resolveBottomSpacer,
    required bool contentLocked,
    required DiaryTextAppearance appearance,
  }) {
    final quillEditor = _buildQuillEditor(context, appearance: appearance);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final minEditorHeight = constraints.maxHeight > 420
            ? constraints.maxHeight - 140
            : 280.0;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildTitleInput(
              context,
              contentLocked: contentLocked,
              appearance: appearance,
            ),
            if (_isCreateEntry)
              IgnorePointer(
                ignoring: contentLocked,
                child: DiaryTemplateStrip(
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
              ),
            if (_isCreateEntry)
              IgnorePointer(
                ignoring: contentLocked,
                child: DiaryDayPhotosStrip(
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
              ),
            const SizedBox(height: 12),
            ConstrainedBox(
              // 标题与正文处在同一可滚动容器，整体滚动体验保持一致。
              constraints: BoxConstraints(minHeight: minEditorHeight),
              child: IgnorePointer(ignoring: contentLocked, child: quillEditor),
            ),
            // 「更多」面板展开时额外让位，自身监听高度，不牵动整列重建。
            DiaryToolbarPanelReserve(extent: _toolbarPanelExtent),
          ],
        );
        // 底部占位随面板拖拽进度连续变化，仅重建滚动容器这一层。
        return ValueListenableBuilder<double>(
          valueListenable: _editPanelExpandProgress,
          child: content,
          builder: (BuildContext context, double progress, Widget? child) {
            return SingleChildScrollView(
              controller: _contentScrollController,
              // 编辑态保持输入焦点，避免轻微滚动时键盘立即收起。
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                resolveBottomSpacer(progress),
              ),
              child: child,
            );
          },
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    // 焦点在工具栏内（颜色代码输入框）时不看键盘高度：焦点从正文交给输入框
    // 时，输入法可能先收起再弹出（如小米对可见密码类输入框换成系统安全
    // 键盘），键盘高度会短暂归零；此时卸载工具栏会连同面板与输入框一起丢掉。
    final rawShowFloatingToolbar =
        _isMobileRuntime &&
        (keyboardInset > 0 || _toolbarFocusNode.hasFocus) &&
        _isEditingNoteText &&
        !_isEditPanelExpanded;
    final showEditMetaPanel = _isEditEntry;
    final settingsAsync = ref.watch(settingsServiceProvider);
    settingsAsync.whenData(_bindToolbarSettingsService);
    settingsAsync.whenData(_bindDayPhotoSettings);
    final enabledToolbarOrder = filterEnabledDiaryToolbarOrder(
      _toolbarOrder,
      _toolbarHiddenItems,
    );
    final showFloatingToolbar =
        enabledToolbarOrder.isNotEmpty &&
        (rawShowFloatingToolbar ||
            (_isMobileRuntime && _recordingPanelOpen && !_isEditPanelExpanded));
    _floatingToolbarShown = showFloatingToolbar;
    // 面板进度由 ValueNotifier 驱动，占位随之局部刷新，不触发整页重建。
    double resolveEditorBottomSpacer(double panelProgress) =>
        _editorBottomSpacer(
          panelProgress,
          showFloatingToolbar: showFloatingToolbar,
        );

    final detailAsync = widget.diaryId == null
        ? const AsyncData<DiaryWithTags?>(null)
        : ref.watch(diaryDetailProvider(widget.diaryId!));

    // 编辑页统一处理三态：加载中 / 加载失败 / 数据可用。
    return detailAsync.when(
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const DelayedLoadingIndicator(),
      ),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppTopBar(
          leading: IconButton(
            tooltip: context.l10n.commonBack,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          ),
        ),
        body: Center(child: Text(context.l10n.autoT0121(error.toString()))),
      ),
      data: (DiaryWithTags? detail) {
        // 工具栏顺序和启用状态已在外层解析，避免详情流重建时重复解析设置。

        if (widget.diaryId != null && detail == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppTopBar(
              leading: IconButton(
                tooltip: context.l10n.commonBack,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
            ),
            body: Center(child: Text(context.l10n.autoT0124)),
          );
        }

        // 首次拿到详情时回填编辑器与草稿上下文，后续重建不重复执行。
        if (!_initialized && detail != null) {
          _titleController.text = detail.diary.title;
          _controller.replaceContentController(
            quill.QuillController(
              document: decodeDiaryContentToDocument(detail.diary.content),
              selection: const TextSelection.collapsed(offset: 0),
            ),
          );
          try {
            _metadataJson = prettyMetadataJson(detail.diary.metadata);
          } catch (_) {
            _metadataJson = detail.diary.metadata;
          }
          // 面板字段从 metadata 读回；封面与标签以日记表的列为准。
          _meta.restore(
            PublishMetadataComposer.parse(detail.diary.metadata).copyWith(
              cover: normalizeOptionalText(detail.diary.cover),
              tagIds: Set<int>.unmodifiable(
                detail.tags.map((Tag tag) => tag.id),
              ),
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
        }

        final showDayPhotosMenu =
            _dayPhotos.library.isSupported && _dayPhotosDay != null;
        final scaffold = Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppTopBar(
            leading: IconButton(
              tooltip: context.l10n.commonBack,
              onPressed: _controller.attemptExit,
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
            title: Text(
              widget.entryMode == EditDiaryEntryMode.create
                  ? context.l10n.autoT0134
                  : context.l10n.autoT0135,
            ),
            actions: <Widget>[
              ExpressiveMenuButton(
                tooltip: context.l10n.diaryEditorMoreActions,
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
                items: <Widget>[
                  // 只在新建空白日记里出现（编辑已有日记、续写草稿时没有）。
                  if (_templates.enabled)
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
                      leadingIcon: const FaIcon(FontAwesomeIcons.solidImages),
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
                  ExpressiveMenuItem(
                    leadingIcon: const FaIcon(FontAwesomeIcons.layerGroup),
                    onPressed: () =>
                        _onEditorMenuAction(_EditorMenuAction.saveAsTemplate),
                    child: Text(context.l10n.diaryTemplateSaveAs),
                  ),
                  ExpressiveMenuItem(
                    leadingIcon: const FaIcon(FontAwesomeIcons.penNib),
                    onPressed: () =>
                        _onEditorMenuAction(_EditorMenuAction.editorSettings),
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
          // 底部键盘弹起时显示悬浮工具栏，并对正文底部做避让。
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // 软键盘“选择”模式的方向键在 Flutter 3.47 上只会移动光标，这里
              // 为标题与正文补回扩选（见 [SoftKeyboardSelectionKeys]）。
              SoftKeyboardSelectionKeys(
                child: _buildEditor(
                  context,
                  resolveBottomSpacer: resolveEditorBottomSpacer,
                  contentLocked: _isEditPanelExpanded || _recordingPanelOpen,
                  appearance: ref.watch(diaryTextAppearanceProvider),
                ),
              ),
              if (showEditMetaPanel &&
                  (!showFloatingToolbar || _isEditPanelExpanded))
                // 铺满 body、贴底对齐：面板据此拿到可用高度，矮屏时展开高度收缩。
                Positioned.fill(
                  left: 16,
                  right: 16,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    // 键盘收起后面板与悬浮工具栏互换时淡入上移，而非硬切。
                    child: ExpressiveEntrance(child: _buildMetaPanel()),
                  ),
                ),
              if (showFloatingToolbar)
                Positioned(
                  left: kDiaryFloatingToolbarInset,
                  right: kDiaryFloatingToolbarInset,
                  // Scaffold 已根据键盘缩小 body，高度不需要再叠加 keyboardInset。
                  bottom: 0,
                  child: LayoutBuilder(
                    builder: (context, constraints) => ExpressiveEntrance(
                      child: SafeArea(
                        top: false,
                        minimum: const EdgeInsets.only(bottom: 8),
                        // 录音面板插入/移除时整列高度平滑变化，工具栏随之上移，
                        // 不再瞬间跳到 300dp 之上。
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
                                  // 焦点在正文与颜色代码输入框之间交接时，
                                  // 按新的焦点重新判断工具栏是否显示。
                                  onFocusChange: (_) => setState(() {}),
                                  child: _buildFloatingToolbar(
                                    enabledToolbarOrder,
                                    // 面板最多铺满工具栏上方的整块正文区，
                                    // 极矮的窗口里改为面板内滚动而不溢出。
                                    maxPanelExtent:
                                        constraints.maxHeight -
                                        MediaQuery.paddingOf(
                                          context,
                                        ).bottom.clamp(8.0, double.infinity) -
                                        kDiaryToolbarBarHeight,
                                  ),
                                ),
                              ),
                              if (_recordingPanelOpen) ...[
                                const SizedBox(height: 8),
                                ExpressiveEntrance(
                                  child: _buildRecordingPanel(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              DiaryMediaImportOverlay(
                copying: _mediaImportController.isCopying,
              ),
            ],
          ),
        );
        // 根节点必须恒为 PopScope：若按 `_recordingPanelOpen` 在 Scaffold 与
        // PopScope(Scaffold) 之间切换，根 widget 类型变化会销毁整棵子树，
        // 连带 QuillEditor、播放器与输入法连接一起重建。只用 canPop 表达差异。
        return PopScope(
          // 编辑模式返回时先补存最后一次输入，面板和录音仍优先收起。
          canPop: !_isEditEntry && !_recordingPanelOpen,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              unawaited(_controller.attemptExit());
              return;
            }
            // 新建模式直接返回：补存防抖窗口里的输入，草稿静默留在草稿箱。
            if (_isCreateEntry) unawaited(_controller.flushCreateDraft());
          },
          child: scaffold,
        );
      },
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
    if (_hasSameToolbarSettings(
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
      hiddenItems: _toolbarHiddenItems,
      currentTimeFormatPattern: _toolbarCurrentTimeFormatPattern,
      onRecordingPressed: _toggleRecordingPanel,
      recordingOpen: _recordingPanelOpen,
      mediaImportController: _mediaImportController,
      onMediaPressed: (kind) => unawaited(_controller.importMedia(kind)),
      onPanelExtentChanged: _handleToolbarPanelExtentChanged,
      maxPanelExtent: maxPanelExtent,
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
      if (!mounted || !selection.isValid) {
        return;
      }
      revealDiaryCaretAbove(
        _quillEditorKey,
        position: selection.extent,
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

  void _toggleRecordingPanel() {
    if (_mediaImportController.isBusy) return;
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

enum EditDiaryEntryMode { create, edit }

/// 顶栏菜单：选择模板（只在新建空白日记）、这天的照片（日记那天不晚于今天
/// 且平台能读相册时）、存为模板、编辑器设置。
enum _EditorMenuAction {
  chooseTemplate,
  dayPhotos,
  saveAsTemplate,
  editorSettings,
}
