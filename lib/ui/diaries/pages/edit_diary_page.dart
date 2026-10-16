import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:path/path.dart' as path;
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/amap_config_channel.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_cover_storage_service.dart';
import 'package:node_diary/core/services/location_resolver_service.dart';
import 'package:node_diary/core/services/qweather_weather_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/core/services/diary_audio_storage_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/location_resolve_hint.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/models/edit_diary_snapshot.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/diaries/models/recording_insertion.dart';
import 'package:node_diary/ui/diaries/models/diary_playback_gestures.dart';
import 'package:node_diary/ui/diaries/controllers/diary_location_preference.dart';
import 'package:node_diary/ui/diaries/controllers/diary_recording_controller.dart';
import 'package:node_diary/ui/diaries/controllers/edit_diary_auto_save_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_media_import_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_player_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_audio_player_controller.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_detail_provider.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_quill_styles.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/create_tag_dialog.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_media_import_overlay.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:node_diary/ui/diaries/widgets/publish_time_picker.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/settings/pages/editor_settings_page.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_entrance.dart';
import 'package:node_diary/ui/widgets/route_entrance_waiter.dart';

part '../controllers/edit_diary_controller.dart';
part '../controllers/edit_diary_persistence_controller.dart';
part '../controllers/edit_diary_recording_controller.dart';
part '../controllers/edit_diary_media_controller.dart';

/// 日记编辑页。
///
/// - `diaryId == null`：新建模式
/// - `diaryId != null`：编辑模式
class EditDiaryPage extends ConsumerStatefulWidget {
  const EditDiaryPage({
    super.key,
    this.diaryId,
    this.entryMode = EditDiaryEntryMode.edit,
    this.restoreCreateDraft = true,
    this.createDateOverride,
    this.createCapsuleUnlockAt,
  });

  final String? diaryId;
  final EditDiaryEntryMode entryMode;
  final bool restoreCreateDraft;
  final DateTime? createDateOverride;

  /// 新建模式下预设的时间胶囊解封日（按“日期”精度）：日历从未来日期进入
  /// “写给这一天的时间胶囊”时传入，发布页打开即为该日解封的胶囊，用户仍可
  /// 在发布页修改或取消。恢复的草稿若自带胶囊设置则以草稿为准。
  final DateTime? createCapsuleUnlockAt;

  @override
  ConsumerState<EditDiaryPage> createState() => _EditDiaryPageState();
}

class _EditDiaryPageState extends ConsumerState<EditDiaryPage>
    with WidgetsBindingObserver {
  static const double _floatingToolbarReservedSpace = 56.0;
  static const double _recordingPanelReservedSpace = 310.0;

  // ==================== 文本输入与焦点控制 ====================
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _weatherController = TextEditingController();
  String? _draftCover;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  final RouteEntranceWaiter _routeEntranceWaiter = RouteEntranceWaiter();
  final ScrollController _contentScrollController = ScrollController();
  final ScrollController _editorInnerScrollController = ScrollController();
  // 用于取光标矩形：「更多」面板展开时把光标滚到面板上方。
  final GlobalKey<quill.EditorState> _quillEditorKey =
      GlobalKey<quill.EditorState>();
  // 悬浮工具栏「更多」面板的目标高度（收起为 0），驱动正文末尾的额外留白。
  final ValueNotifier<double> _toolbarPanelExtent = ValueNotifier<double>(0);
  final DiaryRecordingController _recordingController =
      DiaryRecordingController();
  final DiaryMediaImportController _mediaImportController =
      DiaryMediaImportController();
  final PublishDiaryPanelController _editPanelController =
      PublishDiaryPanelController();
  DateTime? _createDateOverride;

  // ==================== 发布上下文草稿字段 ====================
  final Set<int> _selectedTagIds = <int>{};
  late quill.QuillController _contentController;
  String _metadataJson = '{}';
  String? _draftLocation;
  Map<String, Object?>? _draftLocationAddressComponent;
  double? _draftLocationLatitude;
  double? _draftLocationLongitude;
  bool _draftLocationFromAuto = false;
  DiaryLocationPrecision _draftLocationPrecision =
      DiaryLocationPrecision.township;
  String? _draftWeather;
  String? _draftWeatherIconCode;
  String? _draftMoodEmoji;
  double? _draftEnergyLevel = 4;
  DateTime? _draftCapsuleUnlockAt;
  String? _draftCapsulePrecision;
  // 已发布日记的发表时间（created_at）：详情回填时取库中原值，面板改选后随
  // 自动保存写回。新建模式不用它，发表时间经 _createDateOverride 交给发布页。
  DateTime? _draftPublishAt;
  bool _panelMetadataDirty = false;
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
  bool _locating = false;
  bool _weatherLoading = false;
  LocationResolverService? _locationResolverService;
  QWeatherWeatherService? _weatherService;
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
  Timer? _createDraftSaveDebounceTimer;
  String? _lastPersistedCreateDraftRaw;

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
    _createDateOverride = widget.createDateOverride;
    final presetCapsule = widget.createCapsuleUnlockAt;
    if (presetCapsule != null) {
      _draftCapsuleUnlockAt = TimeCapsuleSchedule.normalizeUnlockAt(
        presetCapsule,
        precision: TimeCapsulePrecision.date,
      );
      _draftCapsulePrecision = TimeCapsuleSchedule.encodePrecision(
        TimeCapsulePrecision.date,
      );
    }
    _contentController = quill.QuillController(
      document: documentFromPlainText(''),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _toolbarOrder = List<DiaryToolbarItem>.from(kDefaultDiaryToolbarOrder);
    _controller = EditDiaryController(this);
    _mediaImportController.addListener(_onMediaImportChanged);
    _titleController.addListener(_controller.onCreateDraftInputChanged);
    _contentController.addListener(_controller.onCreateDraftInputChanged);
    // 新建模式无需等详情查询，直接允许渲染编辑区域。
    _initialized = widget.diaryId == null;
    if (_isCreateEntry) {
      unawaited(
        _controller.prepareCreateEntry(restoreDraft: widget.restoreCreateDraft),
      );
    }
    if (widget.diaryId == null) {
      _routeEntranceWaiter.schedule(this, _contentFocusNode.requestFocus);
    }
  }

  @override
  void dispose() {
    _routeEntranceWaiter.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _createDraftSaveDebounceTimer?.cancel();
    _titleController.removeListener(_controller.onCreateDraftInputChanged);
    _contentController.removeListener(_controller.onCreateDraftInputChanged);
    _mediaImportController.removeListener(_onMediaImportChanged);
    _mediaImportController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _weatherController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isEditEntry &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      unawaited(_controller.flushEditAutoSave());
    }
  }

  /// 当前正文纯文本（用于搜索、字数统计和空内容判断）。
  String get _currentContentText =>
      extractPlainTextFromDiaryDocument(_contentController.document);

  /// 当前正文 Delta JSON（用于富文本持久化）。
  String get _currentContentDocJson =>
      encodeDiaryDocumentToJson(_contentController.document);

  bool get _isCreateEntry =>
      widget.diaryId == null && widget.entryMode == EditDiaryEntryMode.create;
  bool get _isEditEntry =>
      widget.diaryId != null && widget.entryMode == EditDiaryEntryMode.edit;
  bool get _isEditPanelExpanded =>
      _isEditEntry && _editPanelExpandProgress.value >= 0.56;
  bool get _isEditingNoteText =>
      _titleFocusNode.hasFocus || _contentFocusNode.hasFocus;

  void _onMediaImportChanged() {
    if (mounted) setState(() {});
  }

  /// 面板输入同正文一样自动保存，新建模式继续沿用草稿链路。
  void _markEditPanelDirty() {
    _panelMetadataDirty = true;
    _controller.scheduleEditAutoSave();
  }

  /// 汇总当前编辑态数据，形成可持久化的新建草稿对象。
  NewDiaryDraft get _currentCreateDraft {
    return NewDiaryDraft(
      title: _titleController.text,
      contentDocJson: _currentContentDocJson,
      contentText: _currentContentText,
      createdAtOverride: _createDateOverride,
      cover: _draftCover,
      metadataJson: _metadataJson,
      selectedTagIds: <int>{..._selectedTagIds},
      location: _draftLocation,
      locationAddressComponent: _draftLocationAddressComponent,
      locationLatitude: _draftLocationLatitude,
      locationLongitude: _draftLocationLongitude,
      locationFromAuto: _draftLocationFromAuto,
      locationPrecision: _draftLocationPrecision,
      weather: _draftWeather,
      weatherIconCode: _draftWeatherIconCode,
      moodEmoji: _draftMoodEmoji,
      energyLevel: _draftEnergyLevel,
      capsuleUnlockAt: _draftCapsuleUnlockAt,
      capsulePrecision: _draftCapsulePrecision,
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

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final rawShowFloatingToolbar =
        _isMobileRuntime &&
        keyboardInset > 0 &&
        _isEditingNoteText &&
        !_isEditPanelExpanded;
    final showEditMetaPanel = _isEditEntry;
    final settingsAsync = ref.watch(settingsServiceProvider);
    settingsAsync.whenData(_bindToolbarSettingsService);
    final moodOptionsAsync = ref.watch(moodOptionsProvider);
    final moodOptions = moodOptionsAsync.maybeWhen(
      data: (options) => options,
      orElse: () => SettingsService.defaultMoodOptions,
    );
    final enabledToolbarOrder = filterEnabledDiaryToolbarOrder(
      _toolbarOrder,
      _toolbarHiddenItems,
    );
    final showFloatingToolbar =
        enabledToolbarOrder.isNotEmpty &&
        (rawShowFloatingToolbar ||
            (_isMobileRuntime && _recordingPanelOpen && !_isEditPanelExpanded));
    // 正文底部占位：悬浮工具栏/录音面板优先；否则编辑模式按面板展开进度
    // 在 140~460 之间插值（进度由 ValueNotifier 驱动，不触发整页重建）。
    double resolveEditorBottomSpacer(double panelProgress) {
      if (showFloatingToolbar) {
        return _recordingPanelOpen
            ? _recordingPanelReservedSpace
            : _floatingToolbarReservedSpace;
      }
      if (!showEditMetaPanel) {
        return 16.0;
      }
      return (lerpDouble(140, 460, panelProgress) ?? 140) + 16;
    }

    final tagsAsync = ref.watch(tagListProvider);

    var tags = const <Tag>[];
    var tagsLoading = false;
    String? tagsError;
    tagsAsync.when(
      data: (data) => tags = data,
      loading: () => tagsLoading = true,
      error: (error, stackTrace) => tagsError = '$error',
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
          _draftCover = detail.diary.cover;
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
          _controller.restorePublishContextFromMetadata(detail.diary.metadata);
          _draftPublishAt = detail.diary.createdAt;
          _selectedTagIds
            ..clear()
            ..addAll(detail.tags.map((Tag t) => t.id));
          _panelMetadataDirty = false;
          _controller.initializeEditAutoSave();
          _initialized = true;
        }

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
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return const EditorSettingsPage();
                      },
                    ),
                  );
                },
                icon: const FaIcon(FontAwesomeIcons.gear, size: 16),
                tooltip: context.l10n.settingsEditorTitle,
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
              _buildEditor(
                context,
                resolveBottomSpacer: resolveEditorBottomSpacer,
                contentLocked: _isEditPanelExpanded || _recordingPanelOpen,
                appearance: ref.watch(diaryTextAppearanceProvider),
              ),
              if (showEditMetaPanel &&
                  (!showFloatingToolbar || _isEditPanelExpanded))
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  // 键盘收起后面板与悬浮工具栏互换时淡入上移，而非硬切。
                  child: ExpressiveEntrance(
                    child: PublishDiaryPanel(
                      controller: _editPanelController,
                      saving: _saving,
                      hasCover: _draftCover?.trim().isNotEmpty == true,
                      coverLabel: _controller.coverLabelForEdit,
                      locating: _locating,
                      weatherLoading: _weatherLoading,
                      locationController: _locationController,
                      locationPrecision: _draftLocationPrecision,
                      locationAddressComponent: _draftLocationFromAuto
                          ? _draftLocationAddressComponent
                          : null,
                      onLocationPrecisionChanged:
                          _controller.updateLocationPrecisionForEdit,
                      weatherController: _weatherController,
                      weatherIconCode: _draftWeatherIconCode,
                      moodEmoji: _draftMoodEmoji,
                      moodOptions: moodOptions,
                      energyLevel: _draftEnergyLevel,
                      tags: tags,
                      tagsLoading: tagsLoading,
                      tagsError: tagsError,
                      selectedTagIds: _selectedTagIds,
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
                      onPickCover: _controller.pickCoverForEdit,
                      onClearCover: _draftCover?.trim().isNotEmpty == true
                          ? _controller.clearCoverForEdit
                          : null,
                      onCreateTag: _controller.createTagInlineForEdit,
                      onResolveLocation: _controller.resolveLocationForEdit,
                      onResolveWeather: _controller.resolveWeatherForEdit,
                      onLocationChanged: _controller.updateLocationTextForEdit,
                      showPublishTimeOption: true,
                      publishTimeLabel: _controller.publishTimeLabelForEdit,
                      onPickPublishTime: _controller.pickPublishAtForEdit,
                      onWeatherChanged: (nextWeather) {
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _draftWeather = nextWeather.trim().isEmpty
                              ? null
                              : nextWeather.trim();
                          // 用户手动改天气文案后，旧 code 可能已不匹配，需要清空。
                          _draftWeatherIconCode = null;
                          _markEditPanelDirty();
                        });
                      },
                      onToggleTag: (tagId, selected) {
                        setState(() {
                          if (selected) {
                            _selectedTagIds.add(tagId);
                          } else {
                            _selectedTagIds.remove(tagId);
                          }
                          _markEditPanelDirty();
                        });
                      },
                      onMoodChanged: (nextMood) {
                        setState(() {
                          _draftMoodEmoji = nextMood;
                          _markEditPanelDirty();
                        });
                      },
                      onEnergyChanged: (nextValue) {
                        setState(() {
                          _draftEnergyLevel = nextValue?.clamp(1, 5).toDouble();
                          _markEditPanelDirty();
                        });
                      },
                    ),
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
                              Material(
                                color: Theme.of(context).colorScheme.surface,
                                elevation: 8,
                                borderRadius: BorderRadius.circular(18),
                                clipBehavior: Clip.antiAlias,
                                child: MediaQuery(
                                  data: MediaQuery.of(
                                    context,
                                  ).copyWith(textScaler: TextScaler.noScaling),
                                  child: IconTheme(
                                    data: const IconThemeData(size: 16),
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
            }
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
        // 被遮住的高度 = 工具栏一排及其底部留白（与平时的正文避让一致）+ 面板。
        coveredHeight: _floatingToolbarReservedSpace + extent,
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
