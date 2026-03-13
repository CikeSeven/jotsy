// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

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
    return normalized.isEmpty
        ? _state.context.l10n.autoT0095
        : normalized;
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
      location: normalizeOptionalText(_state._locationController.text),
      locationAddressComponent: _state._locationAddressComponent,
      locationLatitude: _state._locationLatitude,
      locationLongitude: _state._locationLongitude,
      locationFromAuto: _state._locationFromAuto,
      weather: normalizeOptionalText(_state._weatherController.text),
      weatherIconCode: normalizeOptionalText(_state._weatherIconCode),
      moodEmoji: normalizeOptionalText(_state._moodEmoji),
      energyLevel: _state._energyLevel,
    );
  }

  /// 解析发布页初始发表时间。
  ///
  /// 规则：
  /// - 无历史值时取当前时间；
  /// - 仅包含“日期”的历史值（00:00:00）补齐当前时分秒；
  /// - 超出当前时间的值回退到当前时间，防止产生未来发表时间。
  DateTime resolveInitialPublishAt(DateTime? raw) {
    final now = DateTime.now();
    if (raw == null) {
      return now;
    }

    final local = raw.toLocal();
    final isDateOnly =
        local.hour == 0 &&
        local.minute == 0 &&
        local.second == 0 &&
        local.millisecond == 0 &&
        local.microsecond == 0;
    final normalized =
        isDateOnly
            ? DateTime(
              local.year,
              local.month,
              local.day,
              now.hour,
              now.minute,
              now.second,
              now.millisecond,
              now.microsecond,
            )
            : local;
    if (normalized.isAfter(now)) {
      return now;
    }
    return normalized;
  }

  /// 发表时间展示文案（固定到分钟）。
  String formatPublishTimeLabel(DateTime value) {
    final local = value.toLocal();
    if (_state.context.l10n.isZh) {
      final year = local.year.toString().padLeft(4, '0');
      final month = local.month.toString().padLeft(2, '0');
      final day = local.day.toString().padLeft(2, '0');
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$year年$month月$day日 $hour:$minute';
    }
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  /// 选择发表时间。
  ///
  /// 约束：
  /// - 日期不能超过今天；
  /// - 时间使用 24 小时制，精确到分钟。
  Future<void> pickPublishAt() async {
    final now = DateTime.now();
    final current = _state._publishAt.toLocal();
    final firstDate = DateTime(2010, 1, 1);
    final lastDate = DateUtils.dateOnly(now);
    final initialDate =
        DateUtils.dateOnly(current).isAfter(lastDate)
            ? lastDate
            : DateUtils.dateOnly(current);

    final pickedDate = await showDatePicker(
      context: _state.context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: _state.context.l10n.autoT0096,
    );
    if (pickedDate == null || !_state.mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: _state.context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: _state.context.l10n.autoT0097,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (pickedTime == null || !_state.mounted) {
      return;
    }

    _state.setState(() {
      _state._publishAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
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
      return _state.context.l10n.autoT0085;
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

  /// 自动定位成功后的地址文案：
  /// 优先展示“城市 · 街道”；仅命中其一时降级为单字段。
  String? _buildAutoLocationLabel({
    required Map<String, Object?>? addressComponent,
    required String? township,
  }) {
    final normalizedTownship = normalizeOptionalText(township);
    final city = _resolveLocationCity(addressComponent);
    if (city != null && normalizedTownship != null) {
      return '$city · $normalizedTownship';
    }
    if (city != null) {
      return city;
    }
    return normalizedTownship;
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
      await showHint(
        _state.context.l10n.autoT0088,
      );
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
      await showHint(
        _state.context.l10n.autoT0089(error.toString()),
      );
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
      await showHint(
        _state.context.l10n.autoT0090(error.toString()),
      );
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
        throw LocationResolveException(
          type: LocationResolveErrorType.missingApiKey,
          message: _state.context.l10n.autoT0204,
        );
      }

      final result = await service.resolveCurrentLocation();
      if (!_state.mounted) {
        return;
      }

      final autoLocationLabel = _buildAutoLocationLabel(
        addressComponent: result.addressComponent,
        township: result.township,
      );
      _state.setState(() {
        _state._locationTownship = result.township;
        _state._locationController.text = autoLocationLabel ?? '';
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
      await showHint(
        _state.context.l10n.autoT0091(error.toString()),
      );
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
      await showHint(
        _state.context.l10n.autoT0092,
      );
      return;
    }

    _state.setState(() => _state._weatherLoading = true);
    try {
      final service = await ensureWeatherService();
      if (service == null) {
        throw QWeatherException(
          type: QWeatherErrorType.missingConfig,
          message: _state.context.l10n.autoT0205,
        );
      }

      final weatherNow = await service.fetchNow(
        latitude: _state._locationLatitude!,
        longitude: _state._locationLongitude!,
        languageCode: (await _state.ref.read(settingsServiceProvider.future)).appLocaleCode,
      );
      if (!_state.mounted) {
        return;
      }
      _state.setState(() {
        _state._weatherController.text = weatherNow.displayText;
        _state._weatherIconCode = weatherNow.iconCode;
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
      await showHint(
        _state.context.l10n.autoT0093(error.toString()),
      );
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
      await db.createDiary(
        title: _state.widget.initialDraft.title,
        contentDocJson: _state.widget.initialDraft.contentDocJson,
        contentText: _state.widget.initialDraft.contentText,
        cover: normalizedCover,
        metadataJson: buildMetadataJson(generatedAt: DateTime.now()),
        tagIds: _state._selectedTagIds.toList(),
        createdAtOverride: _state._publishAt,
      );
      if (!_state.mounted) {
        return;
      }
      Navigator.of(_state.context).pop(true);
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      await showHint(
        _state.context.l10n.autoT0098(error.toString()),
      );
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
        createdAtOverride: _state._publishAt,
        metadataJson: buildMetadataJson(),
        selectedTagIds: <int>{..._state._selectedTagIds},
        location: normalizeOptionalText(_state._locationController.text),
        locationAddressComponent: _state._locationAddressComponent,
        locationLatitude: _state._locationLatitude,
        locationLongitude: _state._locationLongitude,
        locationFromAuto: _state._locationFromAuto,
        weather: normalizeOptionalText(_state._weatherController.text),
        weatherIconCode: normalizeOptionalText(_state._weatherIconCode),
        moodEmoji: normalizeOptionalText(_state._moodEmoji),
        energyLevel: _state._energyLevel,
      ),
    );
  }
}
