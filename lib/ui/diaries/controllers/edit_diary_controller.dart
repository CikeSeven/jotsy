// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 编辑页业务控制器。
///
/// 职责边界：
/// - 处理草稿自动保存与恢复；
/// - 协调已有笔记自动保存、删除与新建发布跳转链路；
/// - 不构建 UI，仅协调页面状态与数据层。
class EditDiaryController {
  EditDiaryController(this._state) {
    _editAutoSave = EditDiaryAutoSaveController(
      readSnapshot: _captureEditSnapshot,
      writeSnapshot: _persistEditSnapshot,
      onError: (error) {
        if (_state.mounted) {
          unawaited(_showHint(_state.context.l10n.autoT0087(error.toString())));
        }
      },
    );
  }

  /// 页面状态引用，承载控制器需要读写的输入与临时状态。
  final _EditDiaryPageState _state;
  late final EditDiaryAutoSaveController _editAutoSave;

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

  /// 编辑态发表时间文案（精确到分钟）；详情回填前为 null。
  String? get publishTimeLabelForEdit {
    final publishAt = _state._draftPublishAt;
    if (publishAt == null) {
      return null;
    }
    return _state.context.l10n.formatDateTimeMinute(publishAt);
  }

  /// 替换正文控制器时同步管理监听，避免旧控制器泄漏。
  void replaceContentController(quill.QuillController nextController) {
    _state._mediaImportController.cancel();
    _state._contentController.removeListener(onCreateDraftInputChanged);
    _state._contentController.dispose();
    _state._contentController = nextController;
    _state._contentController.addListener(onCreateDraftInputChanged);
  }

  /// 新建模式保存草稿，已有笔记直接自动保存；详情回填阶段不触发写入。
  void onCreateDraftInputChanged() {
    if (_state._isCreateEntry) {
      scheduleCreateDraftAutoSave();
      return;
    }
    scheduleEditAutoSave();
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

    final settingsService = await _state.ref.read(
      settingsServiceProvider.future,
    );
    await settingsService.setCreateDiaryDraftRaw(rawDraft);
    _state._lastPersistedCreateDraftRaw = rawDraft;
  }

  /// 新建页初始化：先沿用上次选择的地址层级，再按需恢复草稿。两步串行，
  /// 草稿里保存的层级一定覆盖默认值，而不依赖两个异步回调的执行顺序。
  /// 新建页不展示面板，层级只随草稿带进发布页，因此无需 setState。
  Future<void> prepareCreateEntry({required bool restoreDraft}) async {
    final precision = await DiaryLocationPreference.load(_state.ref);
    if (!_state.mounted) return;
    _state._draftLocationPrecision = precision;
    if (restoreDraft) await restoreCreateDraftIfExists();
  }

  /// 进入新建页时尝试恢复历史草稿。
  Future<void> restoreCreateDraftIfExists() async {
    final settingsService = await _state.ref.read(
      settingsServiceProvider.future,
    );
    final rawDraft = settingsService.createDiaryDraftRaw;
    if (rawDraft == null || rawDraft.trim().isEmpty || !_state.mounted) {
      return;
    }

    try {
      final decoded = jsonDecode(rawDraft);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final restoredDraft = NewDiaryDraft.fromJson(
        decoded.cast<String, Object?>(),
      );

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
        _state._draftLocationPrecision = restoredDraft.locationPrecision;
        _state._draftWeather = restoredDraft.weather;
        _state._draftWeatherIconCode = restoredDraft.weatherIconCode;
        _state._weatherController.text = restoredDraft.weather ?? '';
        _state._draftMoodEmoji = restoredDraft.moodEmoji;
        _state._draftEnergyLevel = restoredDraft.energyLevel;
        // 与发表日期覆盖值同一规则：草稿自带胶囊设置时以草稿为准，否则保留
        // 入口预设的解封日（见 EditDiaryPage.createCapsuleUnlockAt）。
        if (restoredDraft.capsuleUnlockAt != null) {
          _state._draftCapsuleUnlockAt = restoredDraft.capsuleUnlockAt;
          _state._draftCapsulePrecision = restoredDraft.capsulePrecision;
        }
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
    final settingsService = await _state.ref.read(
      settingsServiceProvider.future,
    );
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
          snackBar: SnackBar(content: Text(_state.context.l10n.autoT0086)),
        ),
      );
      return false;
    }
    if (!isValidMetadataJsonObject(_state._metadataJson)) {
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: _state.context,
          snackBar: SnackBar(content: Text(_state.context.l10n.autoT0203)),
        ),
      );
      return false;
    }
    return true;
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
      await _showHint(_state.context.l10n.autoT0088);
      return;
    }

    try {
      final importedPath = await DiaryCoverStorageService.importCover(
        selectedPath,
      );
      if (!_state.mounted) {
        await DiaryCoverStorageService.deleteManagedCover(importedPath);
        return;
      }
      // 自动保存完成前旧封面仍被数据库引用，不能提前删除；
      // 更新成功且无人引用后由 DiaryMediaCleanupService 回收。
      _state.setState(() {
        _state._draftCover = importedPath;
        _state._markEditPanelDirty();
      });
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await _showHint(_state.context.l10n.autoT0089(error.toString()));
    } finally {
      await DiaryMediaStorageService.discardPickerCopy(selectedPath);
    }
  }

  /// 编辑态清除封面；理由同上，文件不在编辑期删除。
  Future<void> clearCoverForEdit() async {
    _state.setState(() {
      _state._draftCover = null;
      _state._markEditPanelDirty();
    });
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
      await _showHint(_state.context.l10n.autoT0090(error.toString()));
    }
  }

  /// 层级变化只改写仍是自动文案的地址，手动地点（含旧版本自动定位后手改、
  /// metadata 仍带 geo 的日记）不被覆盖；变更与其他面板字段一起自动保存，
  /// 并记为新建日记的默认层级。
  void updateLocationPrecisionForEdit(DiaryLocationPrecision precision) {
    if (_state._locating || _state._saving) return;
    unawaited(DiaryLocationPreference.remember(_state.ref, precision));
    final components = _state._draftLocationAddressComponent;
    final followsPrecision =
        _state._draftLocationFromAuto &&
        DiaryLocationLabel.isAutoLabel(
          _state._draftLocation,
          components,
          _state._draftLocationPrecision,
        );
    _state.setState(() {
      _state._draftLocationPrecision = precision;
      if (followsPrecision) {
        final label = DiaryLocationLabel.format(components, precision);
        _state._draftLocation = label;
        _state._locationController.text = label ?? '';
      }
      _state._markEditPanelDirty();
    });
  }

  /// 与发布页一致：手改地点保留坐标，清空地点则停止保存 geo。
  void updateLocationTextForEdit(String value) {
    _state.setState(() {
      _state._draftLocation = _normalizeOptionalText(value);
      if (_state._draftLocation == null) {
        _state._draftLocationFromAuto = false;
      }
      _state._markEditPanelDirty();
    });
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
      final autoLocationLabel = DiaryLocationLabel.format(
        result.addressComponent,
        _state._draftLocationPrecision,
      );
      _state.setState(() {
        _state._draftLocation = autoLocationLabel;
        _state._locationController.text = autoLocationLabel ?? '';
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
      // 提示的关闭 Future 不属于定位请求，避免错误已经显示后仍禁用按钮。
      unawaited(
        _showHint(locationResolveHint(_state.context.l10n, error.type)),
      );
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      unawaited(_showHint(_state.context.l10n.autoT0091(error.toString())));
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
      await _showHint(_state.context.l10n.autoT0092);
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
        languageCode: (await _state.ref.read(
          settingsServiceProvider.future,
        )).appLocaleCode,
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
      await _showHint(_state.context.l10n.autoT0093(error.toString()));
    } finally {
      if (_state.mounted) {
        _state.setState(() => _state._weatherLoading = false);
      }
    }
  }

  /// 修改已发布日记的发表时间，与其他面板字段一样自动保存。
  ///
  /// 发表时间写入 created_at 而不在 metadata 里，所以只排程自动保存、不标记
  /// 面板脏位：标记会整体重组 metadata（刷新 generatedAt、设备信息等），改
  /// 时间不该波及这些字段。选回原来那一分钟时选择器原样返回旧值，快照不变，
  /// 不会写库，也就不会刷新“最后编辑”时间。
  Future<void> pickPublishAtForEdit() async {
    final current = _state._draftPublishAt;
    if (current == null || _state._saving) {
      return;
    }
    final picked = await showPublishTimePicker(
      _state.context,
      current: current,
    );
    if (picked == null || !_state.mounted) {
      return;
    }
    _state.setState(() => _state._draftPublishAt = picked);
    scheduleEditAutoSave();
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
          content: Text(l10n.autoT0206),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(
                  dialogContext,
                ).colorScheme.onSurfaceVariant,
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

  /// 发布成功、发布页即将退场时调用：清除新建草稿，并把编辑页静默移出路由栈。
  ///
  /// 必须赶在发布页退场之前：导航器只允许在上层路由静止且不透明时立即移除
  /// 下层路由，若等发布页开始退场再移除，会被推迟到退场结束——编辑页先露出
  /// 再瞬间消失。此前的做法是发布页退场后编辑页再 pop 一次，两段退场叠在
  /// 一起。现在发布页滑走时露出的直接是列表；新日记 id 作为编辑页的结果交给
  /// 打开者，列表据此播放新卡片的出现动画。草稿清理不依赖页面状态，页面被
  /// 移除后继续完成。
  void _handlePublished(String diaryId) {
    unawaited(clearCreateDraft());
    final route = ModalRoute.of(_state.context);
    if (route != null && route.isActive) {
      Navigator.of(_state.context).removeRoute(route, diaryId);
    }
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
            onPublished: _handlePublished,
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
              locationPrecision: _state._draftLocationPrecision,
              weather: _state._draftWeather,
              weatherIconCode: _state._draftWeatherIconCode,
              moodEmoji: _state._draftMoodEmoji,
              energyLevel: _state._draftEnergyLevel,
              capsuleUnlockAt: _state._draftCapsuleUnlockAt,
              capsulePrecision: _state._draftCapsulePrecision,
            ),
          );
        },
      ),
    );

    if (!_state.mounted) {
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
        _state._draftLocationPrecision = result.locationPrecision;
        _state._draftWeather = result.weather;
        _state._draftWeatherIconCode = result.weatherIconCode;
        _state._draftMoodEmoji = result.moodEmoji;
        _state._draftEnergyLevel = result.energyLevel;
        _state._draftCapsuleUnlockAt = result.capsuleUnlockAt;
        _state._draftCapsulePrecision = result.capsulePrecision;
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
      _state._draftLocationPrecision = DiaryLocationPrecision.parse(
        context['locationPrecision'],
      );
      _state._draftLocation = _normalizeOptionalText(
        context['location']?.toString(),
      );
      _state._draftWeather = _normalizeOptionalText(
        context['weather']?.toString(),
      );
      _state._draftWeatherIconCode = _normalizeOptionalText(
        context['weatherIconCode']?.toString(),
      );
      _state._draftMoodEmoji = _normalizeOptionalText(
        context['moodEmoji']?.toString(),
      );
      _state._locationController.text = _state._draftLocation ?? '';
      _state._weatherController.text = _state._draftWeather ?? '';

      final energyRaw = context['energyLevel'];
      final parsedEnergy = switch (energyRaw) {
        num value => value.toDouble(),
        String value => double.tryParse(value),
        _ => null,
      };
      _state._draftEnergyLevel = parsedEnergy?.clamp(1, 5).toDouble();

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
      locationPrecision: _state._draftLocationPrecision,
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
    _state._locationResolverService = LocationResolverService(
      webApiKey: apiKey,
    );
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
