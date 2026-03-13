// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

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

  /// 编辑态封面标签文案：网络图展示 URL，本地图展示文件名。
  String? get coverLabelForEdit {
    final cover = _normalizeOptionalText(_state._draftCover);
    if (cover == null) {
      return null;
    }
    final uri = Uri.tryParse(cover);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return cover;
    }
    return path.basename(cover);
  }

  /// 编辑页定位展示文案，与发布页保持一致（城市 · 街道）。
  String? get locationLabelForEdit {
    final township = _normalizeOptionalText(_state._draftLocation);
    final city = _resolveLocationCity(_state._draftLocationAddressComponent);
    if (city != null && township != null) {
      return '$city · $township';
    }
    if (city != null) {
      return city;
    }
    if (township != null) {
      return township;
    }
    if (_state._draftLocationFromAuto) {
      return _state.context.l10n.autoT0085;
    }
    return null;
  }

  /// 替换正文控制器时同步管理监听，避免旧控制器泄漏。
  void replaceContentController(quill.QuillController nextController) {
    _state._contentController.removeListener(onCreateDraftInputChanged);
    _state._contentController.dispose();
    _state._contentController = nextController;
    _state._contentController.addListener(onCreateDraftInputChanged);
  }

  /// 新建模式下的标题/正文输入监听回调。
  void onCreateDraftInputChanged() {
    if (_state._isCreateEntry) {
      scheduleCreateDraftAutoSave();
      return;
    }
    // 编辑模式下的输入变更仅更新“未保存状态”，不触发自动草稿写入。
    _state._refreshPendingEditChanges();
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
        _state._createDateOverride =
            restoredDraft.createdAtOverride ?? _state._createDateOverride;
        _state._draftCover = restoredDraft.cover;
        _state._metadataJson = restoredDraft.metadataJson;
        _state._draftLocation = restoredDraft.location;
        _state._locationController.text = restoredDraft.location ?? '';
        _state._draftLocationAddressComponent =
            restoredDraft.locationAddressComponent;
        _state._draftLocationLatitude = restoredDraft.locationLatitude;
        _state._draftLocationLongitude = restoredDraft.locationLongitude;
        _state._draftLocationFromAuto = restoredDraft.locationFromAuto;
        _state._draftWeather = restoredDraft.weather;
        _state._draftWeatherIconCode = restoredDraft.weatherIconCode;
        _state._weatherController.text = restoredDraft.weather ?? '';
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
          snackBar: SnackBar(
            content: Text(
              _state.context.l10n.autoT0086,
            ),
          ),
        ),
      );
      return false;
    }
    if (!isValidMetadataJsonObject(_state._metadataJson)) {
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: _state.context,
          snackBar: SnackBar(
            content: Text(
              _state.context.l10n.autoT0203,
            ),
          ),
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
    // 仅编辑模式存在底部面板，且仅在面板发生变更时重算 metadata。
    if (_state._isEditEntry && _state._panelMetadataDirty) {
      _state._metadataJson = _buildMetadataJsonForEdit();
      _state._panelMetadataDirty = false;
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
        final createdAtForCreate = _resolveCreatedAtForCreate(
          _state._createDateOverride,
        );
        await db.createDiary(
          title: title,
          contentDocJson: contentDocJson,
          contentText: contentText,
          cover: cover,
          metadataJson: _state._metadataJson,
          tagIds: _state._selectedTagIds.toList(),
          createdAtOverride: createdAtForCreate,
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
        if (!_state.mounted) {
          return;
        }
        Navigator.of(_state.context).pop(true);
        return;
      }

      // 编辑模式保存成功后留在当前页：不弹提示、不自动返回。
      _state._markEditSaved();
      _state._showEditSavedSuccessIcon();
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await HomeHintVisibilityScope.showTrackedSnackBar(
        context: _state.context,
          snackBar: SnackBar(
          content: Text(_state.context.l10n.autoT0087(error.toString())),
        ),
      );
    } finally {
      if (_state.mounted) {
        _state.setState(() => _state._saving = false);
        _state._refreshPendingEditChanges();
      }
    }
  }

  /// 编辑态封面选择：导入到应用私有目录，替换时清理旧封面。
  Future<void> pickCoverForEdit() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || !_state.mounted) {
      return;
    }

    final selectedPath = result.files.first.path?.trim();
    if (selectedPath == null || selectedPath.isEmpty) {
      await _showHint(
        _state.context.l10n.autoT0088,
      );
      return;
    }

    final previousCover = _normalizeOptionalText(_state._draftCover);
    try {
      final importedPath = await DiaryCoverStorageService.importCover(selectedPath);
      if (!_state.mounted) {
        await DiaryCoverStorageService.deleteManagedCover(importedPath);
        return;
      }
      _state.setState(() {
        _state._draftCover = importedPath;
        _state._markEditPanelDirty();
      });
      if (previousCover != null && previousCover != importedPath) {
        await DiaryCoverStorageService.deleteManagedCover(previousCover);
      }
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await _showHint(
        _state.context.l10n.autoT0089(error.toString()),
      );
    }
  }

  /// 编辑态清除封面并删除托管文件（若存在）。
  Future<void> clearCoverForEdit() async {
    final coverToDelete = _normalizeOptionalText(_state._draftCover);
    _state.setState(() {
      _state._draftCover = null;
      _state._markEditPanelDirty();
    });
    await DiaryCoverStorageService.deleteManagedCover(coverToDelete);
  }

  /// 编辑态内联创建标签，并自动选中新标签。
  Future<void> createTagInlineForEdit() async {
    final draft = await showCreateTagDialog(_state.context);
    if (draft == null) {
      return;
    }

    try {
      final db = _state.ref.read(appDatabaseProvider);
      final tagId = await db.createTag(name: draft.name, color: draft.color);
      if (!_state.mounted) {
        return;
      }
      _state.setState(() {
        _state._selectedTagIds.add(tagId);
        _state._markEditPanelDirty();
      });
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await _showHint(
        _state.context.l10n.autoT0090(error.toString()),
      );
    }
  }

  /// 编辑态定位：获取最新地址并写入面板字段。
  Future<void> resolveLocationForEdit() async {
    if (_state._locating) {
      return;
    }
    _state.setState(() => _state._locating = true);
    try {
      final service = await _ensureLocationResolverService();
      if (service == null) {
        throw LocationResolveException(
          type: LocationResolveErrorType.missingApiKey,
          message: _state.context.l10n.autoT0204,
        );
      }

      final result = await service.resolveCurrentLocation();
      if (!_state.mounted) {
        return;
      }
      _state.setState(() {
        _state._draftLocation = result.township;
        _state._locationController.text = result.township ?? '';
        _state._draftLocationAddressComponent = result.addressComponent;
        _state._draftLocationLatitude = result.latitude;
        _state._draftLocationLongitude = result.longitude;
        _state._draftLocationFromAuto = true;
        _state._markEditPanelDirty();
      });
    } on LocationResolveException catch (error) {
      if (!_state.mounted) {
        return;
      }
      await _showHint(error.userMessage);
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await _showHint(
        _state.context.l10n.autoT0091(error.toString()),
      );
    } finally {
      if (_state.mounted) {
        _state.setState(() => _state._locating = false);
      }
    }
  }

  /// 编辑态天气获取：依赖当前定位坐标。
  Future<void> resolveWeatherForEdit() async {
    if (_state._weatherLoading) {
      return;
    }
    if (_state._draftLocationLatitude == null ||
        _state._draftLocationLongitude == null) {
      await _showHint(
        _state.context.l10n.autoT0092,
      );
      return;
    }

    _state.setState(() => _state._weatherLoading = true);
    try {
      final service = await _ensureWeatherService();
      if (service == null) {
        throw QWeatherException(
          type: QWeatherErrorType.missingConfig,
          message: _state.context.l10n.autoT0205,
        );
      }

      final weatherNow = await service.fetchNow(
        latitude: _state._draftLocationLatitude!,
        longitude: _state._draftLocationLongitude!,
        languageCode: (await _state.ref.read(settingsServiceProvider.future)).appLocaleCode,
      );
      if (!_state.mounted) {
        return;
      }
      _state.setState(() {
        _state._weatherController.text = weatherNow.displayText;
        _state._draftWeather = weatherNow.displayText;
        _state._draftWeatherIconCode = weatherNow.iconCode;
        _state._markEditPanelDirty();
      });
    } on QWeatherException catch (error) {
      if (!_state.mounted) {
        return;
      }
      await _showHint(error.userMessage);
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await _showHint(
        _state.context.l10n.autoT0093(error.toString()),
      );
    } finally {
      if (_state.mounted) {
        _state.setState(() => _state._weatherLoading = false);
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
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.autoT0094),
          content: Text(
            l10n.autoT0206,
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
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
              createdAtOverride: _state._createDateOverride,
              cover: _state._draftCover,
              metadataJson: _state._metadataJson,
              selectedTagIds: <int>{..._state._selectedTagIds},
              location: _state._draftLocation,
              locationAddressComponent: _state._draftLocationAddressComponent,
              locationLatitude: _state._draftLocationLatitude,
              locationLongitude: _state._draftLocationLongitude,
              locationFromAuto: _state._draftLocationFromAuto,
              weather: _state._draftWeather,
              weatherIconCode: _state._draftWeatherIconCode,
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
      if (!_state.mounted) {
        return;
      }
      Navigator.of(_state.context).pop(true);
      return;
    }

    if (result is NewDiaryDraft) {
      _state.setState(() {
        _state._createDateOverride =
            result.createdAtOverride ?? _state._createDateOverride;
        _state._draftCover = result.cover;
        _state._metadataJson = result.metadataJson;
        _state._draftLocation = result.location;
        _state._locationController.text = result.location ?? '';
        _state._draftLocationAddressComponent = result.locationAddressComponent;
        _state._draftLocationLatitude = result.locationLatitude;
        _state._draftLocationLongitude = result.locationLongitude;
        _state._draftLocationFromAuto = result.locationFromAuto;
        _state._draftWeather = result.weather;
        _state._draftWeatherIconCode = result.weatherIconCode;
        _state._draftMoodEmoji = result.moodEmoji;
        _state._draftEnergyLevel = result.energyLevel;
        _state._weatherController.text = result.weather ?? '';
        _state._markEditPanelDirty();
        _state._selectedTagIds
          ..clear()
          ..addAll(result.selectedTagIds);
      });
      scheduleCreateDraftAutoSave();
    }
  }

  /// 从已存 metadata 中恢复发布上下文字段，供编辑页底部面板展示。
  ///
  /// 仅在进入编辑页首次加载详情时调用；不触发 setState，避免 build 期重入。
  void restorePublishContextFromMetadata(String metadataRaw) {
    try {
      final decoded = jsonDecode(metadataRaw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final context = decoded['context'];
      if (context is! Map<String, dynamic>) {
        return;
      }
      _state._draftLocation = _normalizeOptionalText(context['location']?.toString());
      _state._draftWeather = _normalizeOptionalText(context['weather']?.toString());
      _state._draftWeatherIconCode = _normalizeOptionalText(
        context['weatherIconCode']?.toString(),
      );
      _state._draftMoodEmoji = _normalizeOptionalText(context['moodEmoji']?.toString());
      _state._locationController.text = _state._draftLocation ?? '';
      _state._weatherController.text = _state._draftWeather ?? '';

      final energyRaw = context['energyLevel'];
      final parsedEnergy = switch (energyRaw) {
        num value => value.toDouble(),
        String value => double.tryParse(value),
        _ => null,
      };
      if (parsedEnergy != null) {
        _state._draftEnergyLevel = parsedEnergy.clamp(1, 5).toDouble();
      }

      final geo = context['geo'];
      if (geo is Map<String, dynamic>) {
        _state._draftLocationLatitude = (geo['latitude'] as num?)?.toDouble();
        _state._draftLocationLongitude = (geo['longitude'] as num?)?.toDouble();
        _state._draftLocationFromAuto = true;
        _state._draftLocationAddressComponent = _parseObjectMap(
          geo['addressComponent'],
        );
      }
    } catch (_) {
      // metadata 非标准结构时不阻断编辑流程，保持默认空态。
    }
  }

  String _buildMetadataJsonForEdit({DateTime? generatedAt}) {
    return PublishMetadataComposer.compose(
      contentText: _state._currentContentText,
      selectedTagIds: _state._selectedTagIds,
      hasCover: _normalizeOptionalText(_state._draftCover) != null,
      deviceInfo: _buildDeviceMetadata(),
      generatedAt: generatedAt ?? DateTime.now(),
      location: _normalizeOptionalText(_state._locationController.text),
      locationAddressComponent: _state._draftLocationAddressComponent,
      locationLatitude: _state._draftLocationLatitude,
      locationLongitude: _state._draftLocationLongitude,
      locationFromAuto: _state._draftLocationFromAuto,
      weather: _normalizeOptionalText(_state._weatherController.text),
      weatherIconCode: _normalizeOptionalText(_state._draftWeatherIconCode),
      moodEmoji: _normalizeOptionalText(_state._draftMoodEmoji),
      energyLevel: _state._draftEnergyLevel,
    );
  }

  Map<String, Object?> _buildDeviceMetadata() {
    final dispatcher = PlatformDispatcher.instance;
    return <String, Object?>{
      'platform': defaultTargetPlatform.name,
      'locale': dispatcher.locale.toLanguageTag(),
      'brightness': dispatcher.platformBrightness.name,
    };
  }

  Future<LocationResolverService?> _ensureLocationResolverService() async {
    if (_state._locationResolverService != null) {
      return _state._locationResolverService;
    }
    final apiKey = await AMapConfigChannel.getAmapWebApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }
    _state._locationResolverService = LocationResolverService(webApiKey: apiKey);
    return _state._locationResolverService;
  }

  Future<QWeatherWeatherService?> _ensureWeatherService() async {
    if (_state._weatherService != null) {
      return _state._weatherService;
    }
    final apiKey = await AMapConfigChannel.getQWeatherApiKey();
    final credentialId = await AMapConfigChannel.getQWeatherCredentialId();
    final apiHost = await AMapConfigChannel.getQWeatherApiHost();
    if (apiKey == null || apiKey.trim().isEmpty) {
      return null;
    }
    final config = QWeatherConfig(
      apiKey: apiKey,
      credentialId: credentialId,
      apiHost: apiHost,
    );
    _state._weatherService = QWeatherWeatherService(config: config);
    return _state._weatherService;
  }

  Future<void> _showHint(String message) async {
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(content: Text(message)),
    );
  }

  String? _normalizeOptionalText(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 将“只含日期”的补写需求转为真实创建时间。
  ///
  /// 规则：使用选中日期的年月日 + 当前时分秒，既保持“归属日正确”，
  /// 又让同一天内的多条记录仍有自然时间顺序。
  ///
  /// 若上游已经给出了明确的时分秒（例如发布页手动选择发表时间），
  /// 则直接保留该时间，不再覆盖。
  DateTime? _resolveCreatedAtForCreate(DateTime? dateOverride) {
    if (dateOverride == null) {
      return null;
    }
    if (dateOverride.hour != 0 ||
        dateOverride.minute != 0 ||
        dateOverride.second != 0 ||
        dateOverride.millisecond != 0 ||
        dateOverride.microsecond != 0) {
      return dateOverride;
    }
    final now = DateTime.now();
    return DateTime(
      dateOverride.year,
      dateOverride.month,
      dateOverride.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  String? _resolveLocationCity(Map<String, Object?>? addressComponent) {
    if (addressComponent == null || addressComponent.isEmpty) {
      return null;
    }
    final city = _normalizeAddressComponentText(addressComponent['city']);
    if (city != null) {
      return city;
    }
    return _normalizeAddressComponentText(addressComponent['province']);
  }

  String? _normalizeAddressComponentText(Object? raw) {
    if (raw is String) {
      return _normalizeOptionalText(raw);
    }
    if (raw is List) {
      for (final item in raw) {
        final normalized = _normalizeAddressComponentText(item);
        if (normalized != null) {
          return normalized;
        }
      }
    }
    return null;
  }

  Map<String, Object?>? _parseObjectMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final normalized = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      if (key == null || key.isEmpty) {
        continue;
      }
      normalized[key] = _normalizeJsonValue(entry.value);
    }
    return normalized;
  }

  Object? _normalizeJsonValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is Map) {
      final nested = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key?.toString();
        if (key == null || key.isEmpty) {
          continue;
        }
        nested[key] = _normalizeJsonValue(entry.value);
      }
      return nested;
    }
    if (value is List) {
      return value.map(_normalizeJsonValue).toList(growable: false);
    }
    return value.toString();
  }
}
