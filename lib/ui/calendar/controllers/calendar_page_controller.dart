part of 'package:node_diary/ui/calendar/pages/calendar_page.dart';

/// 日历页业务控制器。
///
/// 职责边界：
/// - 处理日历视图状态（月/周、焦点月份、选中日期）；
/// - 处理从日历创建新日记（含草稿分流）；
/// - 处理预览页导航；
/// - 不负责具体 UI 组件构建。
class CalendarPageController {
  const CalendarPageController(this._state);

  final _CalendarPageState _state;
  static const List<String> _moodScale = <String>[
    '😭',
    '😢',
    '😞',
    '😕',
    '😐',
    '🙂',
    '😊',
    '😄',
    '😀',
    '🤩',
  ];
  static const Map<String, int> _moodWeights = <String, int>{
    '😭': 1,
    '😢': 2,
    '😞': 3,
    '😕': 4,
    '😐': 5,
    '🙂': 6,
    '😊': 7,
    '😄': 8,
    '😀': 9,
    '🤩': 10,
  };

  /// 当前焦点月份标题（用于头部显示）。
  String get focusedMonthTitle {
    return DateFormat('yyyy年MM月').format(_state._focusedMonth);
  }

  /// 保存 TableCalendar 内部页面控制器，供头部「上月/下月」按钮直接驱动翻页。
  void onCalendarCreated(PageController pageController) {
    _state._calendarPageController = pageController;
  }

  /// 日历月/周格式切换回调（支持上下滑手势触发）。
  void onCalendarFormatChanged(CalendarFormat format) {
    if (_state._calendarFormat == format) {
      return;
    }
    _state.setState(() => _state._calendarFormat = format);
  }

  /// 日期选中回调：联动“选中日列表”和“焦点月份”。
  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final normalizedSelectedDay = DateUtils.dateOnly(selectedDay);
    final normalizedFocusedDay = DateUtils.dateOnly(focusedDay);
    if (isSameDay(_state._selectedDay, normalizedSelectedDay) &&
        isSameDay(_state._focusedMonth, normalizedFocusedDay)) {
      return;
    }
    _state.setState(() {
      _state._selectedDay = normalizedSelectedDay;
      _state._focusedMonth = normalizedFocusedDay;
    });
  }

  /// 翻页后更新焦点日期，并触发对应月份打点懒加载。
  void onPageChanged(DateTime focusedDay) {
    final normalizedFocusedDay = DateUtils.dateOnly(focusedDay);
    if (isSameDay(_state._focusedMonth, normalizedFocusedDay)) {
      return;
    }
    _state.setState(() => _state._focusedMonth = normalizedFocusedDay);
  }

  /// 一键回到今天：重置选中日、焦点月份和格式状态。
  void jumpToToday() {
    final now = DateTime.now();
    _state.setState(() {
      _state._selectedDay = DateUtils.dateOnly(now);
      _state._focusedMonth = DateUtils.dateOnly(now);
      _state._calendarFormat = CalendarFormat.month;
    });
  }

  /// 头部「上个月」快捷动作。
  void goToPreviousMonth() {
    _switchMonth(-1);
  }

  /// 头部「下个月」快捷动作。
  void goToNextMonth() {
    _switchMonth(1);
  }

  /// 打开日期选择弹窗并跳转到指定日期。
  ///
  /// 交互约束：
  /// - 日期范围与日历组件保持一致（2010-01-01 ~ 2100-12-31）；
  /// - 选择完成后同步更新选中日和焦点月份；
  /// - 跳转时统一切到月视图，便于用户定位月份上下文。
  Future<void> pickDateAndJump() async {
    final firstDate = DateTime(2010, 1, 1);
    final lastDate = DateTime(2100, 12, 31);

    final pickedDate = await showDatePicker(
      context: _state.context,
      initialDate: _state._selectedDay,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('zh', 'CN'),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (pickedDate == null || !_state.mounted) {
      return;
    }

    final normalizedDay = DateUtils.dateOnly(pickedDate);
    _state.setState(() {
      _state._selectedDay = normalizedDay;
      _state._focusedMonth = normalizedDay;
      _state._calendarFormat = CalendarFormat.month;
    });
  }

  /// 统一处理头部快捷翻月：
  /// 1) 先确保处于月视图；
  /// 2) 优先使用 TableCalendar 的 PageController 做原生翻页动画；
  /// 3) 若控制器暂不可用，回退为直接更新焦点月份。
  void _switchMonth(int offset) {
    if (_state._calendarFormat != CalendarFormat.month) {
      _state.setState(() => _state._calendarFormat = CalendarFormat.month);
    }

    final pageController = _state._calendarPageController;
    if (pageController != null && pageController.hasClients) {
      if (offset < 0) {
        pageController.previousPage(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        pageController.nextPage(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    final fallbackFocusedMonth = DateTime(
      _state._focusedMonth.year,
      _state._focusedMonth.month + offset,
    );
    _state.setState(() => _state._focusedMonth = fallbackFocusedMonth);
  }

  /// 月份打点按“本地日期”聚合，供 TableCalendar 的 eventLoader 使用。
  Map<DateTime, List<DiaryCalendarMarker>> groupMarkersByDay(
    List<DiaryCalendarMarker> markers,
  ) {
    final buckets = <DateTime, List<DiaryCalendarMarker>>{};
    for (final marker in markers) {
      final day = DateUtils.dateOnly(marker.createdAt.toLocal());
      final bucket = buckets.putIfAbsent(day, () => <DiaryCalendarMarker>[]);
      bucket.add(marker);
    }
    return buckets;
  }

  /// 基于当天所有非空心情计算“平均权重”，并映射到最近的 emoji。
  ///
  /// 规则：
  /// 1) 仅统计在权重表中的 emoji；
  /// 2) 计算平均值后四舍五入；
  /// 3) 按 1~10 映射回固定心情梯度。
  String? resolveMoodEmoji(List<DiaryCalendarMarker> markers) {
    var totalWeight = 0;
    var validCount = 0;

    for (final marker in markers) {
      final mood = marker.moodEmoji?.trim();
      if (mood == null || mood.isEmpty) {
        continue;
      }
      final weight = _moodWeights[mood];
      if (weight == null) {
        continue;
      }
      totalWeight += weight;
      validCount += 1;
    }

    if (validCount == 0) {
      return null;
    }

    final averageWeight = totalWeight / validCount;
    final roundedWeight = averageWeight.round().clamp(1, _moodScale.length) as int;
    return _moodScale[roundedWeight - 1];
  }

  /// 打开日记预览页（与主页列表行为保持一致）。
  void openPreview(String diaryId) {
    Navigator.of(_state.context)
        .push<DiaryPreviewResult?>(
      MaterialPageRoute<DiaryPreviewResult?>(
        builder: (BuildContext context) => DiaryPreviewPage(diaryId: diaryId),
      ),
    )
        .then((DiaryPreviewResult? result) async {
      if (!_state.mounted || result != DiaryPreviewResult.deleted) {
        return;
      }

      final undoRequested = await _showDeleteUndoSnackBar();
      if (!_state.mounted || !undoRequested) {
        return;
      }

      try {
        final db = _state.ref.read(appDatabaseProvider);
        await db.restoreDiary(diaryId, touchUpdatedAt: false);
        if (!_state.mounted) {
          return;
        }
        await _showInfoSnackBar('已恢复删除的日记');
      } catch (_) {
        if (!_state.mounted) {
          return;
        }
        await _showInfoSnackBar('恢复失败，请重试');
      }
    });
  }

  /// 显示“删除成功 + 撤销”提示，并等待用户动作结果。
  Future<bool> _showDeleteUndoSnackBar() async {
    final messenger = ScaffoldMessenger.maybeOf(_state.context);
    if (messenger == null) {
      return false;
    }
    messenger.hideCurrentSnackBar();

    final tracker = _resolveHomeHintTracker();
    tracker?.onHintShown();

    final controller = messenger.showSnackBar(
      SnackBar(
        content: const Text('已删除日记'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {},
          textColor: Theme.of(_state.context).colorScheme.onPrimary,
        ),
      ),
    );
    final reason = await controller.closed;
    tracker?.onHintClosed();
    return reason == SnackBarClosedReason.action;
  }

  /// 统一轻提示出口，避免控制器中散落重复 SnackBar 构造。
  Future<void> _showInfoSnackBar(String message) async {
    final messenger = ScaffoldMessenger.maybeOf(_state.context);
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    final tracker = _resolveHomeHintTracker();
    tracker?.onHintShown();

    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
    await controller.closed;
    tracker?.onHintClosed();
  }

  /// 解析 Home 提示可见性跟踪器：
  /// - 优先使用当前页面上下文；
  /// - 当前上下文取不到时回退到 rootNavigator 上下文。
  HomeHintVisibilityController? _resolveHomeHintTracker() {
    final fromPageContext = HomeHintVisibilityScope.maybeController(_state.context);
    if (fromPageContext != null) {
      return fromPageContext;
    }
    final rootNavigatorContext =
        Navigator.of(_state.context, rootNavigator: true).context;
    return HomeHintVisibilityScope.maybeController(rootNavigatorContext);
  }

  /// 从日历进入新建流程：
  /// - 先处理草稿分流；
  /// - 最终进入创建页并附带“选中日期”作为创建日期覆盖值。
  Future<void> openCreateEditorWithDraftPrompt() async {
    final settingsService =
        await _state.ref.read(settingsServiceProvider.future);
    final existingDraft = _tryDecodeCreateDraft(
      settingsService.createDiaryDraftRaw,
    );
    if (!_state.mounted) {
      return;
    }

    var restoreCreateDraft = true;
    if (existingDraft?.hasContent == true) {
      final decision = await _showCreateDraftDecisionDialog();
      if (!_state.mounted || decision == null) {
        return;
      }
      if (decision == _CalendarCreateDraftDecision.newEmpty) {
        await settingsService.clearCreateDiaryDraft();
        restoreCreateDraft = false;
      }
    }

    if (!_state.mounted) {
      return;
    }

    await Navigator.of(_state.context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return EditDiaryPage(
            entryMode: EditDiaryEntryMode.create,
            restoreCreateDraft: restoreCreateDraft,
            createDateOverride: DateUtils.dateOnly(_state._selectedDay),
          );
        },
      ),
    );
  }

  Future<_CalendarCreateDraftDecision?> _showCreateDraftDecisionDialog() {
    return showDialog<_CalendarCreateDraftDecision>(
      context: _state.context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('发现未完成日记'),
          content: const Text('检测到你上次有未保存的日记，是否继续编辑？'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(_CalendarCreateDraftDecision.newEmpty);
              },
              child: const Text('新建空笔记'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(_CalendarCreateDraftDecision.continueEditing);
              },
              child: const Text('继续编辑'),
            ),
          ],
        );
      },
    );
  }

  NewDiaryDraft? _tryDecodeCreateDraft(String? rawDraft) {
    if (rawDraft == null || rawDraft.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(rawDraft);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return NewDiaryDraft.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }
}
