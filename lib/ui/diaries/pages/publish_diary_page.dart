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
import 'package:node_diary/core/services/amap_config_channel.dart';
import 'package:node_diary/core/services/diary_cover_storage_service.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/location_resolver_service.dart';
import 'package:node_diary/core/services/qweather_weather_service.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/diaries/widgets/create_tag_dialog.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_cover_sliver.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_glass_panel.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

part '../controllers/publish_diary_controller.dart';

class PublishDiaryPage extends ConsumerStatefulWidget {
  const PublishDiaryPage({super.key, required this.initialDraft});

  final NewDiaryDraft initialDraft;

  @override
  ConsumerState<PublishDiaryPage> createState() => _PublishDiaryPageState();
}

class _PublishDiaryPageState extends ConsumerState<PublishDiaryPage> {
  final TextEditingController _weatherController = TextEditingController();
  final PublishDiaryGlassPanelController _panelController =
      PublishDiaryGlassPanelController();
  late final quill.QuillController _previewController;
  late final Set<int> _selectedTagIds;

  String? _draftCover;
  String? _moodEmoji;
  String? _locationTownship;
  Map<String, Object?>? _locationAddressComponent;
  double? _locationLatitude;
  double? _locationLongitude;
  bool _locationFromAuto = false;
  int _energyLevel = 3;
  double _panelExpandProgress = 0;
  bool _saving = false;
  bool _locating = false;
  bool _weatherLoading = false;
  LocationResolverService? _locationResolverService;
  QWeatherWeatherService? _weatherService;
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
    _weatherController.dispose();
    _previewController.dispose();
    super.dispose();
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
        appBar: AppBar(
          title: const Text('发表日记'),
          leading: IconButton(
            onPressed: _controller.closeWithDraft,
            icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 16),
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _controller.title,
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
                controller: _panelController,
                saving: _saving,
                bottomInset: keyboardInset,
                hasCover: _controller.normalizedCover != null,
                coverLabel: _controller.coverLabel,
                locating: _locating,
                weatherLoading: _weatherLoading,
                locationLabel: _controller.locationLabel,
                weatherController: _weatherController,
                moodEmoji: _moodEmoji,
                energyLevel: _energyLevel,
                tags: tags,
                tagsLoading: tagsLoading,
                tagsError: tagsError,
                selectedTagIds: _selectedTagIds,
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
                onPublish: _controller.publish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
