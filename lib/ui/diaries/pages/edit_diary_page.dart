import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/amap_config_channel.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_cover_storage_service.dart';
import 'package:node_diary/core/services/location_resolver_service.dart';
import 'package:node_diary/core/services/qweather_weather_service.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_detail_provider.dart';
import 'package:node_diary/ui/diaries/widgets/create_tag_dialog.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_glass_panel.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

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
  // ==================== 文本输入与焦点控制 ====================
  final _titleController = TextEditingController();
  final _weatherController = TextEditingController();
  String? _draftCover;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  final ScrollController _contentScrollController = ScrollController();
  final ScrollController _editorInnerScrollController = ScrollController();
  final PublishDiaryGlassPanelController _editPanelController =
      PublishDiaryGlassPanelController();
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
  bool _panelMetadataDirty = false;
  double _editPanelExpandProgress = 0;
  bool _locating = false;
  bool _weatherLoading = false;
  LocationResolverService? _locationResolverService;
  QWeatherWeatherService? _weatherService;

  // ==================== 生命周期与保存状态 ====================
  bool _initialized = false;
  bool _saving = false;
  Timer? _createDraftSaveDebounceTimer;
  String? _lastPersistedCreateDraftRaw;
  _EditPersistedSnapshot? _savedEditSnapshot;
  bool _hasPendingEditChanges = false;

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
    _titleController.removeListener(_controller.onCreateDraftInputChanged);
    _contentController.removeListener(_controller.onCreateDraftInputChanged);
    _titleController.dispose();
    _weatherController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _contentScrollController.dispose();
    _editorInnerScrollController.dispose();
    _contentController.dispose();
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
    if (nextPending == _hasPendingEditChanges) {
      return;
    }
    if (!mounted) {
      _hasPendingEditChanges = nextPending;
      return;
    }
    setState(() => _hasPendingEditChanges = nextPending);
  }

  void _markEditSaved() {
    _savedEditSnapshot = _buildCurrentEditSnapshot();
    _panelMetadataDirty = false;
    _hasPendingEditChanges = false;
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
    if (!_isEditEntry || !_hasPendingEditChanges) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('未保存内容'),
          content: const Text('当前有未保存的内容，确定退出吗？'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true && mounted) {
      Navigator.of(context).pop();
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
    );
  }

  /// 标题输入框。
  ///
  /// 使用下划线风格，焦点态颜色高亮以提供明确输入反馈。
  Widget _buildTitleInput(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
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
        hintText: '标题',
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

  /// 主编辑区域：
  /// - 标题与正文放在同一个滚动容器内，保证滚动体验连续；
  /// - 键盘弹起时保持焦点，不因轻微滚动自动收起键盘。
  Widget _buildEditor(
    BuildContext context, {
    required double bottomSpacer,
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
                  _buildTitleInput(context),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    // 标题与正文处在同一可滚动容器，整体滚动体验保持一致。
                    constraints: BoxConstraints(
                      minHeight: minEditorHeight,
                    ),
                    child: quill.QuillEditor.basic(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      scrollController: _editorInnerScrollController,
                      config: quill.QuillEditorConfig(
                        autoFocus: widget.diaryId == null,
                        placeholder: '开始记录...',
                        scrollable: false,
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                        embedBuilders: buildDiaryQuillEmbedBuilders(),
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

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final showFloatingToolbar = _isMobileRuntime && keyboardInset > 0;
    final showEditMetaPanel = _isEditEntry;
    final editPanelSpacer =
        (showEditMetaPanel && !showFloatingToolbar)
            ? ((lerpDouble(140, 460, _editPanelExpandProgress) ?? 140) + 16)
            : 16.0;
    final settingsAsync = ref.watch(settingsServiceProvider);
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
            appBar: AppBar(
              leading: IconButton(
                tooltip: '返回',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
            ),
            body: Center(child: Text('加载失败: $error')),
          ),
      data: (DiaryWithTags? detail) {
        final toolbarOrder = settingsAsync.maybeWhen(
          data:
              (settingsService) => decodeDiaryToolbarOrder(
                settingsService.diaryToolbarOrderRaw,
              ),
          orElse: () => List<DiaryToolbarItem>.from(kDefaultDiaryToolbarOrder),
        );

        if (widget.diaryId != null && detail == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: '返回',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
            ),
            body: const Center(child: Text('日记不存在')),
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
            appBar: AppBar(
            leading: IconButton(
              tooltip: '返回',
              onPressed: _attemptExitEditPage,
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
            title: Text(
              widget.entryMode == EditDiaryEntryMode.create ? '新建日记' : '编辑日记',
            ),
            actions: <Widget>[
              if (widget.entryMode == EditDiaryEntryMode.create)
                IconButton(
                  onPressed: _saving ? null : _controller.openPublishPage,
                  icon: const FaIcon(FontAwesomeIcons.plus),
                  tooltip: '发布',
                )
              else
                IconButton(
                  onPressed: _canSaveEdit ? _controller.save : null,
                  icon: const Icon(Icons.save_outlined),
                  tooltip: '保存',
                ),
            ],
          ),
            // 底部键盘弹起时显示悬浮工具栏，并对正文底部做避让。
            body: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    0,
                    0,
                    showFloatingToolbar ? 68 : 0,
                  ),
                  child: _buildEditor(
                    context,
                    bottomSpacer: editPanelSpacer,
                  ),
                ),
                if (showEditMetaPanel && !showFloatingToolbar)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 0,
                    child: PublishDiaryGlassPanel(
                      controller: _editPanelController,
                      saving: _saving,
                      bottomInset: keyboardInset,
                      hasCover: _draftCover?.trim().isNotEmpty == true,
                      coverLabel: _controller.coverLabelForEdit,
                      locating: _locating,
                      weatherLoading: _weatherLoading,
                      locationLabel: _controller.locationLabelForEdit,
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
                        if ((progress - _editPanelExpandProgress).abs() < 0.0001) {
                          return;
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
                      actionLabel: '保存日记',
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
                              child: _buildFloatingToolbar(toolbarOrder),
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
          canPop: !_hasPendingEditChanges,
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

  Widget _buildFloatingToolbar(List<DiaryToolbarItem> toolbarOrder) {
    return buildDiaryFloatingToolbar(
      controller: _contentController,
      order: toolbarOrder,
    );
  }
}

enum EditDiaryEntryMode { create, edit }

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
