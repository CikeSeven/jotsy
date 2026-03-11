part of 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';

/// 发布页业务控制器。
///
/// 职责边界：
/// - 处理封面、位置、天气、标签与发布提交流程；
/// - 组装元数据并回传草稿；
/// - 不参与页面结构渲染。
class PublishDiaryController {
  const PublishDiaryController(this._state);

  /// 发布页状态引用，控制器通过它访问输入值、临时状态与路由上下文。
  final _PublishDiaryPageState _state;

  /// 预览页展示标题：空标题回退为默认文案。
  String get title {
    final normalized = _state.widget.initialDraft.title.trim();
    return normalized.isEmpty ? '未命名日记' : normalized;
  }

  /// 规范化封面路径，空字符串按“无封面”处理。
  String? get normalizedCover {
    final normalized = _state._draftCover?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 封面展示文案：
  /// - 网络图显示完整 URL；
  /// - 本地图显示文件名，避免路径过长污染 UI。
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

  /// 通用可选文本标准化，统一去掉空白输入。
  String? normalizeOptionalText(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 页面内轻提示封装。
  Future<void> showHint(String message) async {
    if (!_state.mounted) {
      return;
    }
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(content: Text(message)),
    );
  }

  /// 组装设备上下文信息，写入 metadata.device。
  Map<String, Object?> buildDeviceMetadata() {
    final dispatcher = PlatformDispatcher.instance;
    return <String, Object?>{
      'platform': defaultTargetPlatform.name,
      'locale': dispatcher.locale.toLanguageTag(),
      'brightness': dispatcher.platformBrightness.name,
    };
  }

  /// 组装最终 metadata JSON。
  ///
  /// 合并当前页面可编辑字段与自动采集字段，输出结构化字符串。
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

  /// 发布页用于显示的地址文案。
  ///
  /// 优先展示“城市 · 街道”，仅有其一时降级显示单字段。
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

  /// 解析展示城市：
  /// - 常规城市取 city；
  /// - 直辖市 city 为空时回退 province。
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

  /// 地址组件值标准化（兼容字符串/列表混合结构）。
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

  /// 获取定位服务实例（按需懒加载，避免页面初始化即做网络准备）。
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

  /// 获取天气服务实例（按需懒加载）。
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

  /// 选择封面并拷贝到应用私有目录。
  ///
  /// 若之前已有私有封面文件，会在替换后尝试清理旧文件。
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

  /// 清除封面并删除私有目录中的旧文件（若存在）。
  Future<void> clearCover() async {
    final coverToDelete = normalizedCover;
    _state.setState(() => _state._draftCover = null);
    await DiaryCoverStorageService.deleteManagedCover(coverToDelete);
  }

  /// 发布页内联创建标签，成功后自动加入当前选中集合。
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

  /// 自动定位并逆地理解析：
  /// - 保存 township 作为展示文案来源；
  /// - 保存 addressComponent + 经纬度用于 metadata 组装。
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

  /// 依据当前位置坐标请求天气并回填环境信息字段。
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

  /// 执行发布写库。
  ///
  /// 成功后返回上一级页面，失败时仅提示不退出。
  Future<void> publish() async {
    if (_state._saving) {
      return;
    }

    _state.setState(() => _state._saving = true);

    try {
      final db = _state.ref.read(appDatabaseProvider);
      final createdAtForCreate = _resolveCreatedAtForCreate(
        _state.widget.initialDraft.createdAtOverride,
      );
      await db.createDiary(
        title: _state.widget.initialDraft.title,
        contentDocJson: _state.widget.initialDraft.contentDocJson,
        contentText: _state.widget.initialDraft.contentText,
        cover: normalizedCover,
        metadataJson: buildMetadataJson(generatedAt: DateTime.now()),
        tagIds: _state._selectedTagIds.toList(),
        createdAtOverride: createdAtForCreate,
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

  /// 返回编辑页时带回发布页草稿上下文，确保往返不丢状态。
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

  /// 与编辑页保持一致：补写仅锁定“日期”，时分秒沿用当前时刻。
  DateTime? _resolveCreatedAtForCreate(DateTime? dateOverride) {
    if (dateOverride == null) {
      return null;
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
}
