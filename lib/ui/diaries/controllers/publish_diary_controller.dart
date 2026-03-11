part of 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';

/// 发布页业务控制器。
///
/// 职责边界：
/// - 处理封面、位置、天气、标签与发布提交流程；
/// - 组装元数据并回传草稿；
/// - 不参与页面结构渲染。
class PublishDiaryController {
  const PublishDiaryController(this._state);

  final _PublishDiaryPageState _state;

  String get title {
    final normalized = _state.widget.initialDraft.title.trim();
    return normalized.isEmpty ? '未命名日记' : normalized;
  }

  String? get normalizedCover {
    final normalized = _state._draftCover?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? get coverLabel {
    final cover = normalizedCover;
    if (cover == null) {
      return null;
    }
    final uri = Uri.tryParse(cover);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return cover;
    }
    return path.basename(cover);
  }

  String? normalizeOptionalText(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<void> showHint(String message) async {
    if (!_state.mounted) {
      return;
    }
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(content: Text(message)),
    );
  }

  Map<String, Object?> buildDeviceMetadata() {
    final dispatcher = PlatformDispatcher.instance;
    return <String, Object?>{
      'platform': defaultTargetPlatform.name,
      'locale': dispatcher.locale.toLanguageTag(),
      'brightness': dispatcher.platformBrightness.name,
    };
  }

  String buildMetadataJson({DateTime? generatedAt}) {
    return PublishMetadataComposer.compose(
      contentText: _state.widget.initialDraft.contentText,
      selectedTagIds: _state._selectedTagIds,
      hasCover: normalizedCover != null,
      deviceInfo: buildDeviceMetadata(),
      generatedAt: generatedAt ?? DateTime.now(),
      location: locationLabel,
      locationAddressComponent: _state._locationAddressComponent,
      locationLatitude: _state._locationLatitude,
      locationLongitude: _state._locationLongitude,
      locationFromAuto: _state._locationFromAuto,
      weather: normalizeOptionalText(_state._weatherController.text),
      moodEmoji: normalizeOptionalText(_state._moodEmoji),
      energyLevel: _state._energyLevel,
    );
  }

  String? get locationLabel {
    final township = normalizeOptionalText(_state._locationTownship);
    final city = _resolveLocationCity(_state._locationAddressComponent);
    if (city != null && township != null) {
      return '$city · $township';
    }
    if (city != null) {
      return city;
    }
    if (township != null) {
      return township;
    }
    if (_state._locationFromAuto) {
      return '暂无街道信息';
    }
    return null;
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
      return normalizeOptionalText(raw);
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

  Future<LocationResolverService?> ensureLocationResolverService() async {
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

  Future<QWeatherWeatherService?> ensureWeatherService() async {
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

  Future<void> pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || !_state.mounted) {
      return;
    }

    final selectedPath = result.files.first.path?.trim();
    if (selectedPath == null || selectedPath.isEmpty) {
      await showHint('未获取到可用的封面路径');
      return;
    }

    final previousCover = normalizedCover;
    try {
      final importedPath = await DiaryCoverStorageService.importCover(selectedPath);
      if (!_state.mounted) {
        await DiaryCoverStorageService.deleteManagedCover(importedPath);
        return;
      }

      _state.setState(() => _state._draftCover = importedPath);
      if (previousCover != null && previousCover != importedPath) {
        await DiaryCoverStorageService.deleteManagedCover(previousCover);
      }
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await showHint('封面导入失败: $error');
    }
  }

  Future<void> clearCover() async {
    final coverToDelete = normalizedCover;
    _state.setState(() => _state._draftCover = null);
    await DiaryCoverStorageService.deleteManagedCover(coverToDelete);
  }

  Future<void> createTagInline() async {
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
      _state.setState(() => _state._selectedTagIds.add(tagId));
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await showHint('标签创建失败: $error');
    }
  }

  Future<void> resolveLocation() async {
    if (_state._locating) {
      return;
    }

    _state.setState(() => _state._locating = true);

    try {
      final service = await ensureLocationResolverService();
      if (service == null) {
        throw const LocationResolveException(
          type: LocationResolveErrorType.missingApiKey,
          message: '未检测到高德 Web 服务 key，请先配置 amap.web.api.key',
        );
      }

      final result = await service.resolveCurrentLocation();
      if (!_state.mounted) {
        return;
      }

      _state.setState(() {
        _state._locationTownship = result.township;
        _state._locationAddressComponent = result.addressComponent;
        _state._locationLatitude = result.latitude;
        _state._locationLongitude = result.longitude;
        _state._locationFromAuto = true;
      });
    } on LocationResolveException catch (error) {
      if (!_state.mounted) {
        return;
      }
      await showHint(error.userMessage);
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await showHint('获取位置失败: $error');
    } finally {
      if (_state.mounted) {
        _state.setState(() => _state._locating = false);
      }
    }
  }

  Future<void> resolveWeather() async {
    if (_state._weatherLoading) {
      return;
    }
    if (_state._locationLatitude == null || _state._locationLongitude == null) {
      await showHint('请先获取当前位置');
      return;
    }

    _state.setState(() => _state._weatherLoading = true);
    try {
      final service = await ensureWeatherService();
      if (service == null) {
        throw const QWeatherException(
          type: QWeatherErrorType.missingConfig,
          message: '未检测到和风天气 key，请先配置 qweather.api_key',
        );
      }

      final weatherNow = await service.fetchNow(
        latitude: _state._locationLatitude!,
        longitude: _state._locationLongitude!,
      );
      if (!_state.mounted) {
        return;
      }
      _state.setState(() {
        _state._weatherController.text = weatherNow.displayText;
      });
    } on QWeatherException catch (error) {
      if (!_state.mounted) {
        return;
      }
      await showHint(error.userMessage);
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await showHint('获取天气失败: $error');
    } finally {
      if (_state.mounted) {
        _state.setState(() => _state._weatherLoading = false);
      }
    }
  }

  Future<void> publish() async {
    if (_state._saving) {
      return;
    }

    _state.setState(() => _state._saving = true);

    try {
      final db = _state.ref.read(appDatabaseProvider);
      await db.createDiary(
        title: _state.widget.initialDraft.title,
        contentDocJson: _state.widget.initialDraft.contentDocJson,
        contentText: _state.widget.initialDraft.contentText,
        cover: normalizedCover,
        metadataJson: buildMetadataJson(generatedAt: DateTime.now()),
        tagIds: _state._selectedTagIds.toList(),
      );
      if (!_state.mounted) {
        return;
      }
      Navigator.of(_state.context).pop(true);
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await showHint('发布失败: $error');
    } finally {
      if (_state.mounted) {
        _state.setState(() => _state._saving = false);
      }
    }
  }

  void closeWithDraft() {
    Navigator.of(_state.context).pop(
      _state.widget.initialDraft.copyWith(
        cover: normalizedCover,
        metadataJson: buildMetadataJson(),
        selectedTagIds: <int>{..._state._selectedTagIds},
        location: _state._locationTownship,
        locationAddressComponent: _state._locationAddressComponent,
        locationLatitude: _state._locationLatitude,
        locationLongitude: _state._locationLongitude,
        locationFromAuto: _state._locationFromAuto,
        weather: normalizeOptionalText(_state._weatherController.text),
        moodEmoji: normalizeOptionalText(_state._moodEmoji),
        energyLevel: _state._energyLevel,
      ),
    );
  }
}
