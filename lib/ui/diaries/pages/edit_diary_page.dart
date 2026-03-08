import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';

/// 单条日记详情 provider（含标签聚合）。
final diaryDetailProvider = FutureProvider.autoDispose.family<DiaryWithTags?, String>((
  Ref ref,
  String diaryId,
) {
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
  });

  final String? diaryId;
  final EditDiaryEntryMode entryMode;

  @override
  ConsumerState<EditDiaryPage> createState() => _EditDiaryPageState();
}

class _EditDiaryPageState extends ConsumerState<EditDiaryPage> {
  final _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  final Set<int> _selectedTagIds = <int>{};
  late EditorState _contentEditorState;
  String _metadataJson = '{}';
  bool _initialized = false;
  bool _saving = false;

  bool get _isMobileRuntime {
    final platform = defaultTargetPlatform;
    return !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
  }

  @override
  void initState() {
    super.initState();
    _contentEditorState = EditorState(document: documentFromPlainText(''));
    _initialized = widget.diaryId == null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  String get _currentContentText =>
      extractPlainTextFromDiaryDocument(_contentEditorState.document);

  String get _currentContentDocJson =>
      encodeDiaryDocumentToJson(_contentEditorState.document);

  bool _validateDraft() {
    final title = _titleController.text.trim();
    if (title.isEmpty &&
        !diaryDocumentHasVisibleContent(_contentEditorState.document)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标题和正文不能同时为空')));
      return false;
    }
    if (!isValidMetadataJsonObject(_metadataJson)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('metadata 必须是合法 JSON 对象')));
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (!_validateDraft()) {
      return;
    }

    setState(() => _saving = true);

    final db = ref.read(appDatabaseProvider);
    final title = _titleController.text;
    final contentText = _currentContentText;
    final contentDocJson = _currentContentDocJson;

    try {
      if (widget.diaryId == null) {
        await db.createDiary(
          title: title,
          contentDocJson: contentDocJson,
          contentText: contentText,
          metadataJson: _metadataJson,
          tagIds: _selectedTagIds.toList(),
        );
      } else {
        await db.updateDiary(
          diaryId: widget.diaryId!,
          title: title,
          contentDocJson: contentDocJson,
          contentText: contentText,
          metadataJson: _metadataJson,
          tagIds: _selectedTagIds.toList(),
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _softDelete() async {
    final diaryId = widget.diaryId;
    if (diaryId == null || _saving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除日记'),
          content: const Text('将执行软删除，后续可恢复。确定继续吗？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final db = ref.read(appDatabaseProvider);
    await db.softDeleteDiary(diaryId);

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _openPublishPage() async {
    if (!_validateDraft()) {
      return;
    }

    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute<Object>(
        builder: (BuildContext context) {
          return PublishDiaryPage(
            initialDraft: NewDiaryDraft(
              title: _titleController.text,
              contentDocJson: _currentContentDocJson,
              contentText: _currentContentText,
              metadataJson: _metadataJson,
              selectedTagIds: <int>{..._selectedTagIds},
            ),
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      Navigator.of(context).pop(true);
      return;
    }

    if (result is NewDiaryDraft) {
      setState(() {
        _metadataJson = result.metadataJson;
        _selectedTagIds
          ..clear()
          ..addAll(result.selectedTagIds);
      });
    }
  }

  Widget _buildEditor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget editor = AppFlowyEditor(
      editorState: _contentEditorState,
      autoFocus: widget.diaryId == null,
      editorStyle: EditorStyle.mobile(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        cursorColor: colorScheme.primary,
        dragHandleColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.24),
        textStyleConfiguration: TextStyleConfiguration(
          text: TextStyle(
            fontSize: 16,
            height: 1.58,
            color: colorScheme.onSurface,
          ),
          href: TextStyle(
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: colorScheme.primary.withValues(alpha: 0.8),
          ),
          code: TextStyle(
            color: colorScheme.tertiary,
            backgroundColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.86,
            ),
            fontFamily: 'monospace',
          ),
          autoComplete: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
      shrinkWrap: false,
    );

    if (_isMobileRuntime) {
      editor = MobileToolbarV2(
        editorState: _contentEditorState,
        toolbarItems: buildDiaryMobileToolbarItems(),
        backgroundColor: colorScheme.surface.withValues(alpha: 0.96),
        foregroundColor: colorScheme.onSurfaceVariant,
        iconColor: colorScheme.onSurface,
        itemHighlightColor: colorScheme.primary,
        itemOutlineColor: colorScheme.outlineVariant,
        outlineColor: colorScheme.outlineVariant,
        primaryColor: colorScheme.primary,
        onPrimaryColor: colorScheme.onPrimary,
        tabBarSelectedBackgroundColor: colorScheme.primaryContainer.withValues(
          alpha: 0.55,
        ),
        tabBarSelectedForegroundColor: colorScheme.onPrimaryContainer,
        toolbarHeight: 52,
        child: editor,
      );
    }

    return editor;
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync =
        widget.diaryId == null
            ? const AsyncData<DiaryWithTags?>(null)
            : ref.watch(diaryDetailProvider(widget.diaryId!));

    return detailAsync.when(
      loading:
          () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (Object error, StackTrace stackTrace) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('加载失败: $error')),
          ),
      data: (DiaryWithTags? detail) {
        if (widget.diaryId != null && detail == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('日记不存在')),
          );
        }

        if (!_initialized && detail != null) {
          _titleController.text = detail.diary.title;
          _contentEditorState = EditorState(
            document: decodeDiaryContentToDocument(detail.diary.content),
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
                  onPressed: _saving ? null : _openPublishPage,
                  icon: const FaIcon(FontAwesomeIcons.plus),
                  tooltip: '发布',
                )
              else
                IconButton(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  tooltip: '保存',
                ),
              if (widget.diaryId != null &&
                  widget.entryMode == EditDiaryEntryMode.edit)
                IconButton(
                  onPressed: _saving ? null : _softDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '软删除',
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  style: Theme.of(context).textTheme.headlineSmall,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: '标题',
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(),
                    focusedBorder: UnderlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildEditor(context)),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum EditDiaryEntryMode { create, edit }
