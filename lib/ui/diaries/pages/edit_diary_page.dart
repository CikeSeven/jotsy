import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_detail_provider.dart';
import 'package:node_diary/ui/diaries/widgets/create_tag_dialog.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/settings/pages/editor_settings_page.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

part '../controllers/edit_diary_controller.dart';

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
  });

  final String? diaryId;
  final EditDiaryEntryMode entryMode;
  final bool restoreCreateDraft;
  final DateTime? createDateOverride;

  @override
  ConsumerState<EditDiaryPage> createState() => _EditDiaryPageState();
}

class _EditDiaryPageState extends ConsumerState<EditDiaryPage> {
  static const double _floatingToolbarReservedSpace = 56.0;

  // ==================== 文本输入与焦点控制 ====================
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _weatherController = TextEditingController();
  String? _draftCover;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  final ScrollController _contentScrollController = ScrollController();
  final ScrollController _editorInnerScrollController = ScrollController();
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
  String? _draftWeather;
  String? _draftWeatherIconCode;
  String? _draftMoodEmoji;
  double? _draftEnergyLevel;
  DateTime? _draftCapsuleUnlockAt;
  String? _draftCapsulePrecision;
  bool _panelMetadataDirty = false;
  double _editPanelExpandProgress = 0;
  bool _locating = false;
  bool _weatherLoading = false;
  LocationResolverService? _locationResolverService;
  QWeatherWeatherService? _weatherService;
  late List<DiaryToolbarItem> _toolbarOrder;
  Set<DiaryToolbarItem> _toolbarHiddenItems = <DiaryToolbarItem>{};
  SettingsService? _boundToolbarSettingsService;
  VoidCallback? _toolbarSettingsListener;

  // ==================== 生命周期与保存状态 ====================
  bool _initialized = false;
  bool _saving = false;
  Timer? _createDraftSaveDebounceTimer;
  Timer? _editSaveSuccessIconTimer;
  String? _lastPersistedCreateDraftRaw;
  _EditPersistedSnapshot? _savedEditSnapshot;
  bool _hasPendingEditChanges = false;
  bool _showEditSaveSuccessIcon = false;

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
    _createDateOverride = widget.createDateOverride;
    _contentController = quill.QuillController(
      document: documentFromPlainText(''),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _toolbarOrder = List<DiaryToolbarItem>.from(kDefaultDiaryToolbarOrder);
    _controller = EditDiaryController(this);
    _titleController.addListener(_controller.onCreateDraftInputChanged);
    _contentController.addListener(_controller.onCreateDraftInputChanged);
    // 新建模式无需等详情查询，直接允许渲染编辑区域。
    _initialized = widget.diaryId == null;
    if (_isCreateEntry && widget.restoreCreateDraft) {
      unawaited(_controller.restoreCreateDraftIfExists());
    }
  }

  @override
  void dispose() {
    _createDraftSaveDebounceTimer?.cancel();
    _editSaveSuccessIconTimer?.cancel();
    _titleController.removeListener(_controller.onCreateDraftInputChanged);
    _contentController.removeListener(_controller.onCreateDraftInputChanged);
    _titleController.dispose();
    _locationController.dispose();
    _weatherController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _contentScrollController.dispose();
    _editorInnerScrollController.dispose();
    _contentController.dispose();
    _unbindToolbarSettingsService();
    super.dispose();
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
  bool get _canSaveEdit => _isEditEntry && !_saving && _hasPendingEditChanges;
  bool get _isEditPanelExpanded =>
      _isEditEntry && _editPanelExpandProgress >= 0.56;
  bool get _isEditingNoteText =>
      _titleFocusNode.hasFocus || _contentFocusNode.hasFocus;

  String? _normalizeOptionalText(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  _EditPersistedSnapshot _buildCurrentEditSnapshot() {
    return _EditPersistedSnapshot(
      title: _titleController.text,
      contentDocJson: _currentContentDocJson,
      cover: _normalizeOptionalText(_draftCover),
      metadataJson: _metadataJson.trim(),
      selectedTagIds: <int>{..._selectedTagIds},
    );
  }

  void _refreshPendingEditChanges() {
    if (!_isEditEntry || !_initialized || _saving) {
      return;
    }
    final nextPending =
        _panelMetadataDirty ||
        (_savedEditSnapshot != null &&
            _buildCurrentEditSnapshot() != _savedEditSnapshot);
    final shouldClearSuccessIcon = nextPending && _showEditSaveSuccessIcon;
    if (nextPending == _hasPendingEditChanges && !shouldClearSuccessIcon) {
      return;
    }
    if (!mounted) {
      _hasPendingEditChanges = nextPending;
      if (shouldClearSuccessIcon) {
        _editSaveSuccessIconTimer?.cancel();
        _showEditSaveSuccessIcon = false;
      }
      return;
    }
    setState(() {
      _hasPendingEditChanges = nextPending;
      if (shouldClearSuccessIcon) {
        _editSaveSuccessIconTimer?.cancel();
        _showEditSaveSuccessIcon = false;
      }
    });
  }

  void _markEditSaved() {
    _savedEditSnapshot = _buildCurrentEditSnapshot();
    _panelMetadataDirty = false;
    _hasPendingEditChanges = false;
  }

  /// 编辑模式保存成功后临时展示成功图标。
  ///
  /// 交互规则：展示 `check` 1 秒，然后自动恢复为保存图标。
  void _showEditSavedSuccessIcon() {
    _editSaveSuccessIconTimer?.cancel();
    if (!mounted) {
      _showEditSaveSuccessIcon = true;
      return;
    }
    setState(() => _showEditSaveSuccessIcon = true);
    _editSaveSuccessIconTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) {
        return;
      }
      setState(() => _showEditSaveSuccessIcon = false);
    });
  }

  /// 标记编辑态 metadata 相关字段已变更，并立即让保存按钮可用。
  ///
  /// 该方法只在编辑模式生效；新建模式仍走草稿自动保存链路。
  void _markEditPanelDirty() {
    _panelMetadataDirty = true;
    if (_isEditEntry) {
      _hasPendingEditChanges = true;
    }
  }

  Future<void> _attemptExitEditPage() async {
    // 返回键优先级：
    // 1) 标签子页 -> 回到主面板；
    // 2) 主面板展开 -> 收起面板；
    // 3) 再进入页面退出判定（未保存提示或直接退出）。
    if (_editPanelController.canPopInnerPage) {
      await _editPanelController.popInnerPage();
      return;
    }
    if (_editPanelController.isExpanded) {
      await _editPanelController.collapse();
      return;
    }

    if (!_isEditEntry || !_hasPendingEditChanges) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final exitDecision = await showDialog<_EditExitDecision>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(context.l10n.autoT0131),
          content: Text(context.l10n.autoT0207),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed:
                  () =>
                      Navigator.of(dialogContext).pop(_EditExitDecision.cancel),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(_EditExitDecision.exitWithoutSaving),
              child: Text(context.l10n.autoT0132),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(_EditExitDecision.saveAndExit),
              child: Text(context.l10n.editSaveAndExit),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (exitDecision == _EditExitDecision.exitWithoutSaving) {
      Navigator.of(context).pop();
      return;
    }
    if (exitDecision == _EditExitDecision.saveAndExit) {
      await _controller.save();
      if (!mounted) {
        return;
      }
      if (!_hasPendingEditChanges && !_saving) {
        Navigator.of(context).pop();
      }
    }
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
  /// 使用下划线风格，焦点态颜色高亮以提供明确输入反馈。
  Widget _buildTitleInput(BuildContext context, {required bool contentLocked}) {
    final colorScheme = Theme.of(context).colorScheme;
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
      style: Theme.of(context).textTheme.headlineSmall,
      maxLength: 200,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
        hintText: context.l10n.autoT0106,
        hintStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
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

  /// 主编辑区域：
  /// - 标题与正文放在同一个滚动容器内，保证滚动体验连续；
  /// - 键盘弹起时保持焦点，不因轻微滚动自动收起键盘。
  quill.DefaultStyles _buildEditorCustomStyles({
    required BuildContext context,
    required double bodyFontSize,
    required double bodyLineHeight,
  }) {
    final defaults = quill.DefaultStyles.getInstance(context);
    quill.DefaultTextBlockStyle? applyTextBlock(
      quill.DefaultTextBlockStyle? style,
    ) {
      return style?.copyWith(
        style: style.style.copyWith(
          fontSize: bodyFontSize,
          height: bodyLineHeight,
        ),
      );
    }

    quill.DefaultListBlockStyle? applyListBlock(
      quill.DefaultListBlockStyle? style,
    ) {
      return style?.copyWith(
        style: style.style.copyWith(
          fontSize: bodyFontSize,
          height: bodyLineHeight,
        ),
      );
    }

    return quill.DefaultStyles(
      paragraph: applyTextBlock(defaults.paragraph),
      placeHolder: applyTextBlock(defaults.placeHolder),
      lists: applyListBlock(defaults.lists),
      quote: applyTextBlock(defaults.quote),
      code: applyTextBlock(defaults.code),
    );
  }

  Widget _buildEditor(
    BuildContext context, {
    required double bottomSpacer,
    required bool contentLocked,
    required double bodyFontSize,
    required double bodyLineHeight,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final minEditorHeight =
            constraints.maxHeight > 420 ? constraints.maxHeight - 140 : 280.0;
        return SingleChildScrollView(
          controller: _contentScrollController,
          // 编辑态保持输入焦点，避免轻微滚动时键盘立即收起。
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          padding: EdgeInsets.fromLTRB(8, 0, 8, bottomSpacer),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildTitleInput(context, contentLocked: contentLocked),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    // 标题与正文处在同一可滚动容器，整体滚动体验保持一致。
                    constraints: BoxConstraints(minHeight: minEditorHeight),
                    child: IgnorePointer(
                      ignoring: contentLocked,
                      child: quill.QuillEditor.basic(
                        controller: _contentController,
                        focusNode: _contentFocusNode,
                        scrollController: _editorInnerScrollController,
                        config: quill.QuillEditorConfig(
                          autoFocus: widget.diaryId == null,
                          placeholder: context.l10n.autoT0133,
                          scrollable: false,
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                          customStyles: _buildEditorCustomStyles(
                            context: context,
                            bodyFontSize: bodyFontSize,
                            bodyLineHeight: bodyLineHeight,
                          ),
                          embedBuilders: buildDiaryQuillEmbedBuilders(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditorWithLiveTextSettings(
    BuildContext context, {
    required AsyncValue<SettingsService> settingsAsync,
    required double bottomSpacer,
    required bool contentLocked,
  }) {
    return settingsAsync.when(
      data: (settingsService) {
        return ValueListenableBuilder<EditorBodyFontSizePreset>(
          valueListenable: settingsService.editorBodyFontSizePresetNotifier,
          builder: (
            BuildContext context,
            EditorBodyFontSizePreset fontSizePreset,
            Widget? child,
          ) {
            return ValueListenableBuilder<EditorBodyLineHeightPreset>(
              valueListenable:
                  settingsService.editorBodyLineHeightPresetNotifier,
              builder: (
                BuildContext context,
                EditorBodyLineHeightPreset lineHeightPreset,
                Widget? child,
              ) {
                return _buildEditor(
                  context,
                  bottomSpacer: bottomSpacer,
                  contentLocked: contentLocked,
                  bodyFontSize: fontSizePreset.fontSize,
                  bodyLineHeight: lineHeightPreset.lineHeight,
                );
              },
            );
          },
        );
      },
      loading:
          () => _buildEditor(
            context,
            bottomSpacer: bottomSpacer,
            contentLocked: contentLocked,
            bodyFontSize:
                SettingsService.defaultEditorBodyFontSizePreset.fontSize,
            bodyLineHeight:
                SettingsService.defaultEditorBodyLineHeightPreset.lineHeight,
          ),
      error:
          (_, __) => _buildEditor(
            context,
            bottomSpacer: bottomSpacer,
            contentLocked: contentLocked,
            bodyFontSize:
                SettingsService.defaultEditorBodyFontSizePreset.fontSize,
            bodyLineHeight:
                SettingsService.defaultEditorBodyLineHeightPreset.lineHeight,
          ),
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
    final enabledToolbarOrder = filterEnabledDiaryToolbarOrder(
      _toolbarOrder,
      _toolbarHiddenItems,
    );
    final showFloatingToolbar =
        rawShowFloatingToolbar && enabledToolbarOrder.isNotEmpty;
    final editPanelSpacer =
        showEditMetaPanel
            ? ((lerpDouble(140, 460, _editPanelExpandProgress) ?? 140) + 16)
            : 16.0;
    final editorBottomSpacer =
        showEditMetaPanel && (!showFloatingToolbar || _isEditPanelExpanded)
            ? editPanelSpacer
            : 16.0;
    final effectiveEditorBottomSpacer =
        showFloatingToolbar
            ? _floatingToolbarReservedSpace
            : editorBottomSpacer;
    final tagsAsync = ref.watch(tagListProvider);

    var tags = const <Tag>[];
    var tagsLoading = false;
    String? tagsError;
    tagsAsync.when(
      data: (data) => tags = data,
      loading: () => tagsLoading = true,
      error: (error, stackTrace) => tagsError = '$error',
    );

    final detailAsync =
        widget.diaryId == null
            ? const AsyncData<DiaryWithTags?>(null)
            : ref.watch(diaryDetailProvider(widget.diaryId!));

    // 编辑页统一处理三态：加载中 / 加载失败 / 数据可用。
    return detailAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (Object error, StackTrace stackTrace) => Scaffold(
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
          _selectedTagIds
            ..clear()
            ..addAll(detail.tags.map((Tag t) => t.id));
          _savedEditSnapshot = _buildCurrentEditSnapshot();
          _hasPendingEditChanges = false;
          _panelMetadataDirty = false;
          _initialized = true;
        }

        final scaffold = Scaffold(
          appBar: AppTopBar(
            leading: IconButton(
              tooltip: context.l10n.commonBack,
              onPressed: _attemptExitEditPage,
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
                  onPressed: _saving ? null : _controller.openPublishPage,
                  icon: const FaIcon(FontAwesomeIcons.plus),
                  tooltip: context.l10n.autoT0136,
                )
              else
                IconButton(
                  onPressed: _canSaveEdit ? _controller.save : null,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child:
                        _showEditSaveSuccessIcon
                            ? Icon(
                              Icons.check_rounded,
                              key: const ValueKey<String>('edit_save_success'),
                              color: Theme.of(context).colorScheme.primary,
                            )
                            : const Icon(
                              Icons.save_outlined,
                              key: ValueKey<String>('edit_save_default'),
                            ),
                  ),
                  tooltip: context.l10n.commonSave,
                ),
            ],
          ),
          // 底部键盘弹起时显示悬浮工具栏，并对正文底部做避让。
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildEditorWithLiveTextSettings(
                context,
                settingsAsync: settingsAsync,
                bottomSpacer: effectiveEditorBottomSpacer,
                contentLocked: _isEditPanelExpanded,
              ),
              if (showEditMetaPanel &&
                  (!showFloatingToolbar || _isEditPanelExpanded))
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: PublishDiaryPanel(
                    controller: _editPanelController,
                    saving: _saving,
                    bottomInset: keyboardInset,
                    hasCover: _draftCover?.trim().isNotEmpty == true,
                    coverLabel: _controller.coverLabelForEdit,
                    locating: _locating,
                    weatherLoading: _weatherLoading,
                    locationController: _locationController,
                    weatherController: _weatherController,
                    weatherIconCode: _draftWeatherIconCode,
                    moodEmoji: _draftMoodEmoji,
                    energyLevel: _draftEnergyLevel ?? 4,
                    tags: tags,
                    tagsLoading: tagsLoading,
                    tagsError: tagsError,
                    selectedTagIds: _selectedTagIds,
                    onProgressChanged: (progress) {
                      if (!mounted) {
                        return;
                      }
                      if ((progress - _editPanelExpandProgress).abs() <
                          0.0001) {
                        return;
                      }
                      final wasExpanded = _isEditPanelExpanded;
                      final nextExpanded = progress >= 0.56;
                      if (!wasExpanded && nextExpanded) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      }
                      setState(() => _editPanelExpandProgress = progress);
                    },
                    onPickCover: _controller.pickCoverForEdit,
                    onClearCover:
                        _draftCover?.trim().isNotEmpty == true
                            ? _controller.clearCoverForEdit
                            : null,
                    onCreateTag: _controller.createTagInlineForEdit,
                    onResolveLocation: _controller.resolveLocationForEdit,
                    onResolveWeather: _controller.resolveWeatherForEdit,
                    onLocationChanged: (nextLocation) {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _draftLocation =
                            nextLocation.trim().isEmpty
                                ? null
                                : nextLocation.trim();
                        _markEditPanelDirty();
                      });
                    },
                    onWeatherChanged: (nextWeather) {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _draftWeather =
                            nextWeather.trim().isEmpty
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
                        _draftEnergyLevel = nextValue.clamp(1, 5).toDouble();
                        _markEditPanelDirty();
                      });
                    },
                    onPublish: _controller.save,
                    actionLabel: context.l10n.autoT0137,
                  ),
                ),
              if (showFloatingToolbar)
                Positioned(
                  left: 12,
                  right: 12,
                  // Scaffold 已根据键盘缩小 body，高度不需要再叠加 keyboardInset。
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 8),
                    child: Material(
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
                          child: SizedBox(
                            height: 44,
                            child: _buildFloatingToolbar(enabledToolbarOrder),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        if (!_isEditEntry) {
          return scaffold;
        }
        return PopScope(
          // 编辑页返回统一交给 `_attemptExitEditPage`，
          // 避免面板展开态下系统直接 pop 路由。
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _attemptExitEditPage();
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
    if (_hasSameToolbarSettings(nextOrder, nextHiddenItems)) {
      return;
    }
    void apply() {
      _toolbarOrder = nextOrder;
      _toolbarHiddenItems = nextHiddenItems;
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
  ) {
    if (_toolbarOrder.length != nextOrder.length ||
        _toolbarHiddenItems.length != nextHiddenItems.length) {
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

  Widget _buildFloatingToolbar(List<DiaryToolbarItem> toolbarOrder) {
    return buildDiaryFloatingToolbar(
      controller: _contentController,
      order: toolbarOrder,
    );
  }
}

enum EditDiaryEntryMode { create, edit }

enum _EditExitDecision { cancel, exitWithoutSaving, saveAndExit }

class _EditPersistedSnapshot {
  const _EditPersistedSnapshot({
    required this.title,
    required this.contentDocJson,
    required this.cover,
    required this.metadataJson,
    required this.selectedTagIds,
  });

  final String title;
  final String contentDocJson;
  final String? cover;
  final String metadataJson;
  final Set<int> selectedTagIds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _EditPersistedSnapshot &&
        other.title == title &&
        other.contentDocJson == contentDocJson &&
        other.cover == cover &&
        other.metadataJson == metadataJson &&
        other.selectedTagIds.length == selectedTagIds.length &&
        other.selectedTagIds.containsAll(selectedTagIds);
  }

  @override
  int get hashCode {
    final sortedTagIds = selectedTagIds.toList()..sort();
    return Object.hash(
      title,
      contentDocJson,
      cover,
      metadataJson,
      Object.hashAll(sortedTagIds),
    );
  }
}
