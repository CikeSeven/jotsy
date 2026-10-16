// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';

/// 发布页业务控制器。
///
/// 职责边界：
/// - 发表时间、胶囊文案与发布提交流程；
/// - 组装元数据并回传草稿；
/// - 封面、标签、定位、天气等面板动作在 DiaryMetaActions（与编辑页共用）；
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

  /// 封面展示文案：
  /// - 网络图显示完整 URL；
  /// - 本地图显示文件名，避免路径过长污染 UI。
  String? get coverLabel {
    final cover = _state._meta.value.cover;
    if (cover == null) {
      return null;
    }
    final uri = Uri.tryParse(cover);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return cover;
    }
    return path.basename(cover);
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

  /// 组装最终 metadata JSON；[generatedAt] 同时作为胶囊的封存时刻。
  String buildMetadataJson({DateTime? generatedAt}) {
    final lockedAt = generatedAt ?? DateTime.now();
    return PublishMetadataComposer.composeDraft(
      draft: _state._meta.value,
      contentText: _state.widget.initialDraft.contentText,
      generatedAt: lockedAt,
      capsuleLockedAt: lockedAt,
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
    final schedule = _state._meta.value.capsule;
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
    final draft = _state._meta.value;
    final pendingSchedule = draft.capsule;
    if (pendingSchedule != null &&
        !pendingSchedule.isUnlockInFuture(DateTime.now())) {
      showHint(_state.context.l10n.timeCapsuleUnlockPassed);
      return;
    }

    _state.setState(() => _state._saving = true);

    try {
      final db = _state.ref.read(appDatabaseProvider);
      final schedule = draft.capsule;
      final lockedAt = schedule == null ? null : DateTime.now();
      final diaryId = await db.createDiary(
        title: _state.widget.initialDraft.title,
        contentDocJson: _state.widget.initialDraft.contentDocJson,
        contentText: _state.widget.initialDraft.contentText,
        cover: draft.cover,
        metadataJson: buildMetadataJson(generatedAt: lockedAt),
        tagIds: draft.tagIds.toList(),
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
      debugPrint('Publish failed: $error');
      showHint(_state.context.l10n.publishFailed);
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
    Navigator.of(_state.context).pop(
      _state._meta.value.applyTo(
        _state.widget.initialDraft.copyWith(
          // 只带回用户亲自选的时间；没选过就原样带回打开者的请求值（如日历
          // 的按日新建），下次打开或发表时再现算，不把“打开发布页那一刻”
          // 冻结进草稿。
          createdAtOverride:
              _state._explicitPublishAt ??
              _state.widget.initialDraft.createdAtOverride,
          metadataJson: buildMetadataJson(),
        ),
      ),
    );
  }
}
