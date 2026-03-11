import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

part '../controllers/edit_diary_controller.dart';

/// 单条日记详情 provider（含标签聚合）。
final diaryDetailProvider = FutureProvider.autoDispose
    .family<DiaryWithTags?, String>((Ref ref, String diaryId) {
      final db = ref.watch(appDatabaseProvider);
      return db.getDiaryWithTagsByDiaryId(diaryId);
    });

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
  });

  final String? diaryId;
  final EditDiaryEntryMode entryMode;
  final bool restoreCreateDraft;

  @override
  ConsumerState<EditDiaryPage> createState() => _EditDiaryPageState();
}

class _EditDiaryPageState extends ConsumerState<EditDiaryPage> {
  final _titleController = TextEditingController();
  String? _draftCover;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  final ScrollController _contentScrollController = ScrollController();
  final ScrollController _editorInnerScrollController = ScrollController();

  final Set<int> _selectedTagIds = <int>{};
  late quill.QuillController _contentController;
  String _metadataJson = '{}';
  String? _draftLocation;
  Map<String, Object?>? _draftLocationAddressComponent;
  double? _draftLocationLatitude;
  double? _draftLocationLongitude;
  bool _draftLocationFromAuto = false;
  String? _draftWeather;
  String? _draftMoodEmoji;
  int? _draftEnergyLevel;
  bool _initialized = false;
  bool _saving = false;
  Timer? _createDraftSaveDebounceTimer;
  String? _lastPersistedCreateDraftRaw;
  late final EditDiaryController _controller;

  bool get _isMobileRuntime {
    final platform = defaultTargetPlatform;
    return !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
  }

  @override
  void initState() {
    super.initState();
    _contentController = quill.QuillController(
      document: documentFromPlainText(''),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _controller = EditDiaryController(this);
    _titleController.addListener(_controller.onCreateDraftInputChanged);
    _contentController.addListener(_controller.onCreateDraftInputChanged);
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
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _contentScrollController.dispose();
    _editorInnerScrollController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String get _currentContentText =>
      extractPlainTextFromDiaryDocument(_contentController.document);

  String get _currentContentDocJson =>
      encodeDiaryDocumentToJson(_contentController.document);

  bool get _isCreateEntry =>
      widget.diaryId == null && widget.entryMode == EditDiaryEntryMode.create;

  NewDiaryDraft get _currentCreateDraft {
    return NewDiaryDraft(
      title: _titleController.text,
      contentDocJson: _currentContentDocJson,
      contentText: _currentContentText,
      cover: _draftCover,
      metadataJson: _metadataJson,
      selectedTagIds: <int>{..._selectedTagIds},
      location: _draftLocation,
      locationAddressComponent: _draftLocationAddressComponent,
      locationLatitude: _draftLocationLatitude,
      locationLongitude: _draftLocationLongitude,
      locationFromAuto: _draftLocationFromAuto,
      weather: _draftWeather,
      moodEmoji: _draftMoodEmoji,
      energyLevel: _draftEnergyLevel,
    );
  }

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

  Widget _buildEditor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final minEditorHeight =
            constraints.maxHeight > 420 ? constraints.maxHeight - 140 : 280.0;
        return SingleChildScrollView(
          controller: _contentScrollController,
          // 编辑态保持输入焦点，避免轻微滚动时键盘立即收起。
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
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
    final settingsAsync = ref.watch(settingsServiceProvider);

    final detailAsync =
        widget.diaryId == null
            ? const AsyncData<DiaryWithTags?>(null)
            : ref.watch(diaryDetailProvider(widget.diaryId!));

    return detailAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (Object error, StackTrace stackTrace) => Scaffold(
            appBar: AppBar(),
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
            appBar: AppBar(),
            body: const Center(child: Text('日记不存在')),
          );
        }

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
          _selectedTagIds
            ..clear()
            ..addAll(detail.tags.map((Tag t) => t.id));
          _initialized = true;
        }

        return Scaffold(
            appBar: AppBar(
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
                  onPressed: _saving ? null : _controller.save,
                  icon: const Icon(Icons.save_outlined),
                  tooltip: '保存',
                ),
              if (widget.diaryId != null &&
                  widget.entryMode == EditDiaryEntryMode.edit)
                IconButton(
                  onPressed: _saving ? null : _controller.softDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '软删除',
                ),
            ],
          ),
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
                  child: _buildEditor(context),
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
