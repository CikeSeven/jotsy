part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 编辑页业务控制器。
///
/// 职责边界：
/// - 处理草稿自动保存与恢复；
/// - 处理保存、删除、发布跳转链路；
/// - 不构建 UI，仅协调页面状态与数据层。
class EditDiaryController {
  const EditDiaryController(this._state);

  final _EditDiaryPageState _state;

  void replaceContentController(quill.QuillController nextController) {
    _state._contentController.removeListener(onCreateDraftInputChanged);
    _state._contentController.dispose();
    _state._contentController = nextController;
    _state._contentController.addListener(onCreateDraftInputChanged);
  }

  void onCreateDraftInputChanged() {
    if (!_state._isCreateEntry) {
      return;
    }
    scheduleCreateDraftAutoSave();
  }

  void scheduleCreateDraftAutoSave() {
    _state._createDraftSaveDebounceTimer?.cancel();
    _state._createDraftSaveDebounceTimer = Timer(
      const Duration(milliseconds: 1300),
      () {
        unawaited(persistOrClearCreateDraftDebounced());
      },
    );
  }

  Future<void> persistOrClearCreateDraftDebounced() async {
    if (!_state.mounted || !_state._isCreateEntry || _state._saving) {
      return;
    }

    final draft = _state._currentCreateDraft;
    if (!draft.hasContent) {
      await clearCreateDraft();
      return;
    }

    final rawDraft = jsonEncode(draft.toJson());
    if (rawDraft == _state._lastPersistedCreateDraftRaw) {
      return;
    }

    final settingsService = await _state.ref.read(settingsServiceProvider.future);
    await settingsService.setCreateDiaryDraftRaw(rawDraft);
    _state._lastPersistedCreateDraftRaw = rawDraft;
  }

  Future<void> restoreCreateDraftIfExists() async {
    final settingsService = await _state.ref.read(settingsServiceProvider.future);
    final rawDraft = settingsService.createDiaryDraftRaw;
    if (rawDraft == null || rawDraft.trim().isEmpty || !_state.mounted) {
      return;
    }

    try {
      final decoded = jsonDecode(rawDraft);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final restoredDraft = NewDiaryDraft.fromJson(decoded.cast<String, Object?>());

      quill.Document restoredDocument;
      try {
        restoredDocument = decodeDiaryContentToDocument(
          restoredDraft.contentDocJson,
        );
      } catch (_) {
        restoredDocument = documentFromPlainText(restoredDraft.contentText);
      }

      _state._lastPersistedCreateDraftRaw = jsonEncode(restoredDraft.toJson());
      _state.setState(() {
        _state._titleController.text = restoredDraft.title;
        _state._draftCover = restoredDraft.cover;
        _state._metadataJson = restoredDraft.metadataJson;
        _state._draftLocation = restoredDraft.location;
        _state._draftLocationAddressComponent =
            restoredDraft.locationAddressComponent;
        _state._draftLocationLatitude = restoredDraft.locationLatitude;
        _state._draftLocationLongitude = restoredDraft.locationLongitude;
        _state._draftLocationFromAuto = restoredDraft.locationFromAuto;
        _state._draftWeather = restoredDraft.weather;
        _state._draftMoodEmoji = restoredDraft.moodEmoji;
        _state._draftEnergyLevel = restoredDraft.energyLevel;
        _state._selectedTagIds
          ..clear()
          ..addAll(restoredDraft.selectedTagIds);
        replaceContentController(
          quill.QuillController(
            document: restoredDocument,
            selection: const TextSelection.collapsed(offset: 0),
          ),
        );
      });
    } catch (_) {
      // 草稿反序列化失败时静默忽略，避免阻断新建流程。
    }
  }

  Future<void> clearCreateDraft() async {
    _state._createDraftSaveDebounceTimer?.cancel();
    final settingsService = await _state.ref.read(settingsServiceProvider.future);
    await settingsService.clearCreateDiaryDraft();
    _state._lastPersistedCreateDraftRaw = null;
  }

  bool validateDraft() {
    final title = _state._titleController.text.trim();
    if (title.isEmpty &&
        !diaryDocumentHasVisibleContent(_state._contentController.document)) {
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: _state.context,
          snackBar: const SnackBar(content: Text('标题和正文不能同时为空')),
        ),
      );
      return false;
    }
    if (!isValidMetadataJsonObject(_state._metadataJson)) {
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: _state.context,
          snackBar: const SnackBar(content: Text('metadata 必须是合法 JSON 对象')),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> save() async {
    if (_state._saving) {
      return;
    }
    if (!validateDraft()) {
      return;
    }

    _state.setState(() => _state._saving = true);

    final db = _state.ref.read(appDatabaseProvider);
    final title = _state._titleController.text;
    final contentText = _state._currentContentText;
    final contentDocJson = _state._currentContentDocJson;
    final cover = _state._draftCover;

    try {
      if (_state.widget.diaryId == null) {
        await db.createDiary(
          title: title,
          contentDocJson: contentDocJson,
          contentText: contentText,
          cover: cover,
          metadataJson: _state._metadataJson,
          tagIds: _state._selectedTagIds.toList(),
        );
      } else {
        await db.updateDiary(
          diaryId: _state.widget.diaryId!,
          title: title,
          contentDocJson: contentDocJson,
          contentText: contentText,
          cover: cover,
          metadataJson: _state._metadataJson,
          tagIds: _state._selectedTagIds.toList(),
        );
      }

      if (!_state.mounted) {
        return;
      }
      if (_state._isCreateEntry) {
        await clearCreateDraft();
      }
      Navigator.of(_state.context).pop(true);
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await HomeHintVisibilityScope.showTrackedSnackBar(
        context: _state.context,
        snackBar: SnackBar(content: Text('保存失败: $error')),
      );
    } finally {
      if (_state.mounted) {
        _state.setState(() => _state._saving = false);
      }
    }
  }

  Future<void> softDelete() async {
    final diaryId = _state.widget.diaryId;
    if (diaryId == null || _state._saving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: _state.context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除日记'),
          content: const Text('将执行软删除，后续可恢复。确定继续吗？'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
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

    final db = _state.ref.read(appDatabaseProvider);
    await db.softDeleteDiary(diaryId);

    if (!_state.mounted) {
      return;
    }
    Navigator.of(_state.context).pop(true);
  }

  Future<void> openPublishPage() async {
    if (!validateDraft()) {
      return;
    }

    final result = await Navigator.of(_state.context).push<Object>(
      MaterialPageRoute<Object>(
        builder: (BuildContext context) {
          return PublishDiaryPage(
            initialDraft: NewDiaryDraft(
              title: _state._titleController.text,
              contentDocJson: _state._currentContentDocJson,
              contentText: _state._currentContentText,
              cover: _state._draftCover,
              metadataJson: _state._metadataJson,
              selectedTagIds: <int>{..._state._selectedTagIds},
              location: _state._draftLocation,
              locationAddressComponent: _state._draftLocationAddressComponent,
              locationLatitude: _state._draftLocationLatitude,
              locationLongitude: _state._draftLocationLongitude,
              locationFromAuto: _state._draftLocationFromAuto,
              weather: _state._draftWeather,
              moodEmoji: _state._draftMoodEmoji,
              energyLevel: _state._draftEnergyLevel,
            ),
          );
        },
      ),
    );

    if (!_state.mounted) {
      return;
    }

    if (result == true) {
      await clearCreateDraft();
      Navigator.of(_state.context).pop(true);
      return;
    }

    if (result is NewDiaryDraft) {
      _state.setState(() {
        _state._draftCover = result.cover;
        _state._metadataJson = result.metadataJson;
        _state._draftLocation = result.location;
        _state._draftLocationAddressComponent = result.locationAddressComponent;
        _state._draftLocationLatitude = result.locationLatitude;
        _state._draftLocationLongitude = result.locationLongitude;
        _state._draftLocationFromAuto = result.locationFromAuto;
        _state._draftWeather = result.weather;
        _state._draftMoodEmoji = result.moodEmoji;
        _state._draftEnergyLevel = result.energyLevel;
        _state._selectedTagIds
          ..clear()
          ..addAll(result.selectedTagIds);
      });
      scheduleCreateDraftAutoSave();
    }
  }
}
