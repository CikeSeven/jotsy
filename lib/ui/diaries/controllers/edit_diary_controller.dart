part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 编辑页业务控制器。
///
/// 职责边界：
/// - 处理草稿自动保存与恢复；
/// - 处理保存、删除、发布跳转链路；
/// - 不构建 UI，仅协调页面状态与数据层。
class EditDiaryController {
  const EditDiaryController(this._state);

  /// 页面状态引用，承载控制器需要读写的输入与临时状态。
  final _EditDiaryPageState _state;

  /// 替换正文控制器时同步管理监听，避免旧控制器泄漏。
  void replaceContentController(quill.QuillController nextController) {
    _state._contentController.removeListener(onCreateDraftInputChanged);
    _state._contentController.dispose();
    _state._contentController = nextController;
    _state._contentController.addListener(onCreateDraftInputChanged);
  }

  /// 新建模式下的标题/正文输入监听回调。
  void onCreateDraftInputChanged() {
    if (!_state._isCreateEntry) {
      return;
    }
    scheduleCreateDraftAutoSave();
  }

  /// 1.3 秒防抖自动保存草稿。
  void scheduleCreateDraftAutoSave() {
    _state._createDraftSaveDebounceTimer?.cancel();
    _state._createDraftSaveDebounceTimer = Timer(
      const Duration(milliseconds: 1300),
      () {
        unawaited(persistOrClearCreateDraftDebounced());
      },
    );
  }

  /// 执行防抖后的草稿写入（或清空）。
  Future<void> persistOrClearCreateDraftDebounced() async {
    if (!_state.mounted || !_state._isCreateEntry || _state._saving) {
      return;
    }

    final draft = _state._currentCreateDraft;
    // 标题和正文都为空时自动清草稿，避免下次新建反复弹“继续编辑”提示。
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

  /// 进入新建页时尝试恢复历史草稿。
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

      // 优先恢复富文本文档；若 JSON 不可用则降级为纯文本，保证可读可编辑。
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

  /// 主动清除新建草稿（发布成功或用户显式清空场景）。
  Future<void> clearCreateDraft() async {
    _state._createDraftSaveDebounceTimer?.cancel();
    final settingsService = await _state.ref.read(settingsServiceProvider.future);
    await settingsService.clearCreateDiaryDraft();
    _state._lastPersistedCreateDraftRaw = null;
  }

  /// 保存前校验：至少需要标题或正文其一非空。
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

  /// 保存日记（创建或更新）。
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
      // 新建与编辑共用同一入口，但写库动作不同。
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

  /// 软删除当前日记（仅编辑模式可用）。
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

  /// 跳转到发布页，并在返回后回写发布页修改过的草稿上下文。
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
