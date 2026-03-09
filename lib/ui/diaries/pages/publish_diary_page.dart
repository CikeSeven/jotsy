import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path/path.dart' as path;

import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/diaries/widgets/create_tag_dialog.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_cover_sliver.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_glass_panel.dart';

class PublishDiaryPage extends ConsumerStatefulWidget {
  const PublishDiaryPage({super.key, required this.initialDraft});

  final NewDiaryDraft initialDraft;

  @override
  ConsumerState<PublishDiaryPage> createState() => _PublishDiaryPageState();
}

class _PublishDiaryPageState extends ConsumerState<PublishDiaryPage> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _weatherController = TextEditingController();
  late final quill.QuillController _previewController;
  late final Set<int> _selectedTagIds;

  String? _draftCover;
  String? _moodEmoji;
  int _energyLevel = 3;
  double _panelExpandProgress = 0;
  bool _saving = false;

  String get _title {
    final normalized = widget.initialDraft.title.trim();
    return normalized.isEmpty ? '未命名日记' : normalized;
  }

  String? get _normalizedCover {
    final normalized = _draftCover?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? get _coverLabel {
    final cover = _normalizedCover;
    if (cover == null) {
      return null;
    }
    final uri = Uri.tryParse(cover);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return cover;
    }
    return path.basename(cover);
  }

  String? _normalizeOptionalText(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Map<String, Object?> _buildDeviceMetadata() {
    final dispatcher = PlatformDispatcher.instance;
    return <String, Object?>{
      'platform': defaultTargetPlatform.name,
      'locale': dispatcher.locale.toLanguageTag(),
      'brightness': dispatcher.platformBrightness.name,
    };
  }

  String _buildMetadataJson({DateTime? generatedAt}) {
    return PublishMetadataComposer.compose(
      contentText: widget.initialDraft.contentText,
      selectedTagIds: _selectedTagIds,
      hasCover: _normalizedCover != null,
      deviceInfo: _buildDeviceMetadata(),
      generatedAt: generatedAt ?? DateTime.now(),
      location: _normalizeOptionalText(_locationController.text),
      weather: _normalizeOptionalText(_weatherController.text),
      moodEmoji: _normalizeOptionalText(_moodEmoji),
      energyLevel: _energyLevel,
    );
  }

  String get _prettyMetadataPreview {
    try {
      return PublishMetadataComposer.pretty(_buildMetadataJson());
    } catch (_) {
      return '{}';
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedTagIds = <int>{...widget.initialDraft.selectedTagIds};
    _draftCover = _normalizeOptionalText(widget.initialDraft.cover);
    _locationController.text = widget.initialDraft.location ?? '';
    _weatherController.text = widget.initialDraft.weather ?? '';
    _moodEmoji = widget.initialDraft.moodEmoji;

    final initialEnergy = widget.initialDraft.energyLevel ?? 3;
    if (initialEnergy < 1) {
      _energyLevel = 1;
    } else if (initialEnergy > 5) {
      _energyLevel = 5;
    } else {
      _energyLevel = initialEnergy;
    }

    quill.Document previewDoc;
    try {
      previewDoc = decodeDiaryContentToDocument(widget.initialDraft.contentDocJson);
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

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || !mounted) {
      return;
    }

    final selectedPath = result.files.first.path?.trim();
    if (selectedPath == null || selectedPath.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未获取到可用的封面路径')));
      return;
    }

    setState(() => _draftCover = selectedPath);
  }

  Future<void> _createTagInline() async {
    final draft = await showCreateTagDialog(context);
    if (draft == null) {
      return;
    }

    try {
      final db = ref.read(appDatabaseProvider);
      final tagId = await db.createTag(name: draft.name, color: draft.color);
      if (!mounted) {
        return;
      }
      setState(() => _selectedTagIds.add(tagId));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('标签创建失败: $error')));
    }
  }

  Future<void> _publish() async {
    if (_saving) {
      return;
    }

    setState(() => _saving = true);

    try {
      final db = ref.read(appDatabaseProvider);
      await db.createDiary(
        title: widget.initialDraft.title,
        contentDocJson: widget.initialDraft.contentDocJson,
        contentText: widget.initialDraft.contentText,
        cover: _normalizedCover,
        metadataJson: _buildMetadataJson(generatedAt: DateTime.now()),
        tagIds: _selectedTagIds.toList(),
      );
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
      ).showSnackBar(SnackBar(content: Text('发布失败: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _closeWithDraft() {
    Navigator.of(context).pop(
      widget.initialDraft.copyWith(
        cover: _normalizedCover,
        metadataJson: _buildMetadataJson(),
        selectedTagIds: <int>{..._selectedTagIds},
        location: _normalizeOptionalText(_locationController.text),
        weather: _normalizeOptionalText(_weatherController.text),
        moodEmoji: _normalizeOptionalText(_moodEmoji),
        energyLevel: _energyLevel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final tagsAsync = ref.watch(tagListProvider);

    var tags = const <Tag>[];
    var tagsLoading = false;
    String? tagsError;
    tagsAsync.when(
      data: (data) => tags = data,
      loading: () => tagsLoading = true,
      error: (error, stackTrace) => tagsError = '$error',
    );

    final panelSpacer = lerpDouble(140, 460, _panelExpandProgress) ?? 140;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _closeWithDraft();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('发布日记'),
          leading: IconButton(
            onPressed: _closeWithDraft,
            icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 16),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: <Widget>[
                if (_normalizedCover != null)
                  PublishDiaryCoverSliver(cover: _normalizedCover!),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _title,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 16),
                        if (widget.initialDraft.contentText.trim().isEmpty)
                          Text(
                            '正文为空',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          quill.QuillEditor.basic(
                            controller: _previewController,
                            config: quill.QuillEditorConfig(
                              autoFocus: false,
                              scrollable: false,
                              padding: EdgeInsets.zero,
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
              left: 16,
              right: 16,
              bottom: 0,
              child: PublishDiaryGlassPanel(
                saving: _saving,
                bottomInset: keyboardInset,
                hasCover: _normalizedCover != null,
                coverLabel: _coverLabel,
                locationController: _locationController,
                weatherController: _weatherController,
                moodEmoji: _moodEmoji,
                energyLevel: _energyLevel,
                tags: tags,
                tagsLoading: tagsLoading,
                tagsError: tagsError,
                selectedTagIds: _selectedTagIds,
                metadataPreview: _prettyMetadataPreview,
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
                onPickCover: _pickCover,
                onClearCover:
                    _normalizedCover == null
                        ? null
                        : () {
                          setState(() => _draftCover = null);
                        },
                onCreateTag: _createTagInline,
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
                    () => _energyLevel = nextValue.round().clamp(1, 5).toInt(),
                  );
                },
                onLocationChanged: (_) {
                  setState(() {});
                },
                onWeatherChanged: (_) {
                  setState(() {});
                },
                onPublish: _publish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
