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

  /// 时间胶囊封存卡片的入场（缩放回弹）时长，页面动画与返回前等待共用。
  static const Duration capsuleSealAnimationDuration = ExpressiveMotion.long;

  /// 封存提示入场完成后的停留时间，供用户读到“封存中”再返回。
  static const Duration _capsuleSealHoldDuration = Duration(milliseconds: 260);

  /// 发布页状态引用，控制器通过它访问输入值、临时状态与路由上下文。
  final _PublishDiaryPageState _state;

  /// 预览页展示标题：空标题回退为默认文案。
  String get title {
    final normalized = _state.widget.initialDraft.title.trim();
    return normalized.isEmpty ? _state.context.l10n.autoT0095 : normalized;
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
  ///
  /// 不返回 Future：showTrackedSnackBar 要等提示条关闭（约 4 秒）才完成，
  /// 在 try/catch 里 await 会把 finally 里的 loading/saving 复位拖到提示
  /// 消失之后，按钮在这段时间一直转圈或停用。
  void showHint(String message) {
    if (!_state.mounted) {
      return;
    }
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: _state.context,
        snackBar: SnackBar(content: Text(message)),
      ),
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
    final schedule = _state._timeCapsuleSchedule;
    final lockedAt = generatedAt ?? DateTime.now();
    return PublishMetadataComposer.compose(
      contentText: _state.widget.initialDraft.contentText,
      selectedTagIds: _state._selectedTagIds,
      hasCover: normalizedCover != null,
      deviceInfo: buildDeviceMetadata(),
      generatedAt: lockedAt,
      location: normalizeOptionalText(_state._locationController.text),
      locationAddressComponent: _state._locationAddressComponent,
      locationLatitude: _state._locationLatitude,
      locationLongitude: _state._locationLongitude,
      locationFromAuto: _state._locationFromAuto,
      locationPrecision: _state._locationPrecision,
      weather: normalizeOptionalText(_state._weatherController.text),
      weatherIconCode: normalizeOptionalText(_state._weatherIconCode),
      moodEmoji: normalizeOptionalText(_state._moodEmoji),
      energyLevel: _state._energyLevel,
      capsuleLockedAt: schedule == null ? null : lockedAt,
      capsuleUnlockAt: schedule?.normalizedUnlockAt,
      capsulePrecision: schedule == null
          ? null
          : TimeCapsuleSchedule.encodePrecision(schedule.precision),
    );
  }

  /// 实际发表时间：用户在本页选过就用所选（晚于现在时回退到现在），否则
  /// 按打开者带来的请求值现算（见 [resolvePublishAt]）。每次读取都重新计算，
  /// 发布时取的是提交那一刻。
  DateTime get effectivePublishAt {
    final now = DateTime.now();
    final explicit = _state._explicitPublishAt;
    if (explicit != null) {
      return explicit.isAfter(now) ? now : explicit;
    }
    return resolvePublishAt(
      _state.widget.initialDraft.createdAtOverride,
      now: now,
    );
  }

  /// 面板上的发表时间文案；既没选过、打开者也没指定时为 null，面板显示
  /// “自动获取当前时间”。
  String? get publishTimeLabel {
    if (_state._explicitPublishAt == null &&
        _state.widget.initialDraft.createdAtOverride == null) {
      return null;
    }
    return formatPublishTimeLabel(effectivePublishAt);
  }

  /// 发表时间展示文案（固定到分钟）。
  String formatPublishTimeLabel(DateTime value) =>
      _state.context.l10n.formatDateTimeMinute(value);

  String get timeCapsuleLabel {
    final l10n = _state.context.l10n;
    final schedule = _state._timeCapsuleSchedule;
    if (schedule == null) {
      return l10n.timeCapsuleUnset;
    }
    final unlockAt = schedule.normalizedUnlockAt;
    // “只按日期”的胶囊在当天零点解封，只显示日期，不显示一个用户没选过的 00:00。
    return l10n.timeCapsuleSet(
      schedule.precision == TimeCapsulePrecision.date
          ? l10n.formatFullDate(unlockAt)
          : formatPublishTimeLabel(unlockAt),
    );
  }

  /// 选择发表时间；约束见 [showPublishTimePicker]（与编辑已发布日记共用）。
  ///
  /// 原样确认（选回当前那一分钟，选择器返回 current 本身）不算选择，发表
  /// 时间继续跟随提交时刻。
  Future<void> pickPublishAt() async {
    final current = effectivePublishAt;
    final picked = await showPublishTimePicker(
      _state.context,
      current: current,
    );
    if (picked == null || picked == current || !_state.mounted) {
      return;
    }
    _state.setState(() => _state._explicitPublishAt = picked);
  }

  void updateTimeCapsule(TimeCapsuleSchedule picked) {
    _state.setState(() {
      _state._timeCapsuleSchedule = TimeCapsuleSchedule(
        unlockAt: picked.normalizedUnlockAt,
        precision: picked.precision,
      );
    });
  }

  void clearTimeCapsule() {
    _state.setState(() => _state._timeCapsuleSchedule = null);
  }

  /// 只重组已解析的地址，不触发定位或网络请求。仅当前文案仍是自动文案时
  /// 才按新层级改写；手动输入原样保留，避免用户调整下次定位的层级时丢失
  /// 自己写的地点名称。选择同时记为新建日记的默认层级。
  void updateLocationPrecision(DiaryLocationPrecision precision) {
    if (_state._locating || _state._saving) return;
    unawaited(DiaryLocationPreference.remember(_state.ref, precision));
    final components = _state._locationAddressComponent;
    final followsPrecision =
        _state._locationFromAuto &&
        DiaryLocationLabel.isAutoLabel(
          _state._locationController.text,
          components,
          _state._locationPrecision,
        );
    _state.setState(() {
      _state._locationPrecision = precision;
      if (followsPrecision) {
        _state._locationController.text =
            DiaryLocationLabel.format(components, precision) ?? '';
      }
    });
  }

  /// 手动修改地点不影响坐标：自动定位后补几个字仍记录在哪里写的日记。
  /// 清空地点则视为不记录位置，停止保存 geo，避免 metadata 残留用户看不到
  /// 的经纬度；内存中的坐标保留给天气查询，重新定位后恢复保存。
  void updateLocationText(String value) {
    if (normalizeOptionalText(value) != null || !_state._locationFromAuto) {
      return;
    }
    _state.setState(() => _state._locationFromAuto = false);
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
    _state._locationResolverService = LocationResolverService(
      webApiKey: apiKey,
    );
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
  /// 被替换的旧封面不在这里删除：它可能已写入持久化草稿，进程在草稿更新前
  /// 被杀会留下坏封面；无人引用后由 DiaryMediaCleanupService 回收。
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
      showHint(_state.context.l10n.autoT0088);
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

      _state.setState(() => _state._draftCover = importedPath);
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      showHint(_state.context.l10n.autoT0089(error.toString()));
    } finally {
      await DiaryMediaStorageService.discardPickerCopy(selectedPath);
    }
  }

  /// 清除封面；文件同样交给 DiaryMediaCleanupService 按引用回收。
  Future<void> clearCover() async {
    _state.setState(() => _state._draftCover = null);
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
      showHint(_state.context.l10n.autoT0090(error.toString()));
    }
  }

  /// 自动定位并逆地理解析：
  /// - 按选择的层级组装展示文案；
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

      final autoLocationLabel = DiaryLocationLabel.format(
        result.addressComponent,
        _state._locationPrecision,
      );
      _state.setState(() {
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
      showHint(locationResolveHint(_state.context.l10n, error.type));
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      showHint(_state.context.l10n.autoT0091(error.toString()));
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
      showHint(_state.context.l10n.autoT0092);
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
        languageCode: (await _state.ref.read(
          settingsServiceProvider.future,
        )).appLocaleCode,
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
      showHint(error.userMessage);
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      showHint(_state.context.l10n.autoT0093(error.toString()));
    } finally {
      if (_state.mounted) {
        _state.setState(() => _state._weatherLoading = false);
      }
    }
  }

  /// 执行发布写库。
  ///
  /// 成功后先通知打开者（[PublishDiaryPage.onPublished]，编辑页借此静默移出
  /// 路由栈），再以新日记 id 作为结果退场；失败时仅提示不退出。
  Future<void> publish() async {
    if (_state._leaveBlocked) {
      return;
    }
    // 解封时间必须仍在未来：日期精度选了今天、或恢复的草稿里那天已过，
    // 写入的就是一个立即解封的胶囊。拦下并提示重新选择，不写库。
    final pendingSchedule = _state._timeCapsuleSchedule;
    if (pendingSchedule != null &&
        !pendingSchedule.isUnlockInFuture(DateTime.now())) {
      showHint(_state.context.l10n.timeCapsuleUnlockPassed);
      return;
    }

    _state.setState(() => _state._saving = true);

    try {
      final db = _state.ref.read(appDatabaseProvider);
      final schedule = _state._timeCapsuleSchedule;
      final lockedAt = schedule == null ? null : DateTime.now();
      final diaryId = await db.createDiary(
        title: _state.widget.initialDraft.title,
        contentDocJson: _state.widget.initialDraft.contentDocJson,
        contentText: _state.widget.initialDraft.contentText,
        cover: normalizedCover,
        metadataJson: buildMetadataJson(generatedAt: lockedAt),
        tagIds: _state._selectedTagIds.toList(),
        createdAtOverride: TimeCapsuleSchedule.resolveDiaryCreatedAt(
          schedule: schedule,
          fallbackPublishAt: effectivePublishAt,
        ),
        capsuleUnlockAt: schedule?.normalizedUnlockAt,
        capsuleLockedAt: lockedAt,
      );
      if (!_state.mounted) {
        return;
      }
      _state._published = true;
      if (schedule != null) {
        _state.setState(() => _state._showCapsuleSealOverlay = true);
        // 封存是一次性的仪式动作：与封存卡片同时给出“成功”触觉。
        unawaited(HapticFeedback.successNotification());
        // 等封存卡片入场动画播完，再停留片刻让用户读到提示后返回；
        // 减少动画时入场时长为 0，只保留停留时间。
        await Future<void>.delayed(
          ExpressiveMotion.duration(
                _state.context,
                capsuleSealAnimationDuration,
              ) +
              _capsuleSealHoldDuration,
        );
        if (!_state.mounted) {
          return;
        }
      }
      _state.widget.onPublished?.call(diaryId);
      Navigator.of(_state.context).pop(diaryId);
    } catch (error) {
      if (!_state.mounted) {
        return;
      }
      showHint(_state.context.l10n.autoT0098(error.toString()));
    } finally {
      if (_state.mounted) {
        _state.setState(() => _state._saving = false);
      }
    }
  }

  /// 返回编辑页时带回发布页草稿上下文，确保往返不丢状态。
  ///
  /// 发布进行中或已发布时不返回：日记已（或即将）写库，带回草稿会让编辑页
  /// 保留它，用户可重复发布。
  void closeWithDraft() {
    if (_state._leaveBlocked) {
      return;
    }
    final schedule = _state._timeCapsuleSchedule;
    Navigator.of(_state.context).pop(
      _state.widget.initialDraft.copyWith(
        cover: normalizedCover,
        // 只带回用户亲自选的时间；没选过就原样带回打开者的请求值（如日历
        // 的按日新建），下次打开或发表时再现算，不把“打开发布页那一刻”
        // 冻结进草稿。
        createdAtOverride:
            _state._explicitPublishAt ??
            _state.widget.initialDraft.createdAtOverride,
        metadataJson: buildMetadataJson(),
        selectedTagIds: <int>{..._state._selectedTagIds},
        location: normalizeOptionalText(_state._locationController.text),
        locationAddressComponent: _state._locationAddressComponent,
        locationLatitude: _state._locationLatitude,
        locationLongitude: _state._locationLongitude,
        locationFromAuto: _state._locationFromAuto,
        locationPrecision: _state._locationPrecision,
        weather: normalizeOptionalText(_state._weatherController.text),
        weatherIconCode: normalizeOptionalText(_state._weatherIconCode),
        moodEmoji: normalizeOptionalText(_state._moodEmoji),
        energyLevel: _state._energyLevel,
        capsuleUnlockAt: schedule?.normalizedUnlockAt,
        capsulePrecision: schedule == null
            ? null
            : TimeCapsuleSchedule.encodePrecision(schedule.precision),
      ),
    );
  }
}
