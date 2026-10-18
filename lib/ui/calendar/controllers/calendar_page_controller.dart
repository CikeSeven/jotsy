part of 'package:node_diary/ui/calendar/pages/calendar_page.dart';

/// 日历页业务控制器。
///
/// 职责边界：
/// - 处理日历视图状态（月/周/年、焦点月份、选中日期）；
/// - 处理长按日期的快捷操作与预览页导航；
/// - 选一段日期做统计见 calendar_range_actions.dart，纪念日入口见
///   calendar_anniversary_actions.dart；
/// - 从日历新建日记（含草稿分流）见 calendar_create_actions.dart，显示选项
///   与年视图导出分别见 calendar_display_options_actions.dart、
///   calendar_year_actions.dart；
/// - 不负责具体 UI 组件构建。
class _CalendarPageController {
  const _CalendarPageController(this._state);

  final _CalendarPageState _state;

  /// 头部标题：月/周视图为“2026年10月”，年视图为“2026年”。
  String get focusedMonthTitle {
    final locale = _state.context.l10n.localeName;
    return _state._yearMode
        ? DateFormat.y(locale).format(_state._focusedMonth)
        : DateFormat.yMMM(locale).format(_state._focusedMonth);
  }

  /// 点按头部标题：月/周视图缩放到年视图（与 iOS 日历一致）；年视图下打开
  /// 日期选择器做远距离跳转。
  void onTitlePressed() {
    if (_state._yearMode) {
      unawaited(pickDateAndJump());
      return;
    }
    _state.applyState(() {
      _state._yearMode = true;
      _state._range = null;
    });
  }

  /// 在年视图中点按某个迷你月份：回到该月的月视图。选中日在该月时焦点落在
  /// 选中日上，否则落在 1 号；选中日本身不变。
  void openMonthFromYear(DateTime month) {
    final selected = _state._selectedDay;
    final focused = selected.year == month.year && selected.month == month.month
        ? selected
        : DateTime(month.year, month.month);
    _state.applyState(() {
      _state._yearMode = false;
      _state._calendarFormat = CalendarFormat.month;
      _state._focusedMonth = focused;
    });
  }

  /// 长按日期：系统长按反馈后弹出快捷操作面板，再执行所选操作。
  ///
  /// table_calendar 的长按手势不经过 InkWell，Android 不会自动震动；
  /// `Feedback.forLongPress` 按平台惯例补上（iOS 上为空操作）。
  Future<void> onDayLongPressed(DateTime day) async {
    final normalizedDay = DateUtils.dateOnly(day);
    unawaited(Feedback.forLongPress(_state.context));
    final action = await showCalendarDayActionsSheet(
      _state.context,
      day: normalizedDay,
      now: DateTime.now(),
      isSelected: isSameDay(normalizedDay, _state._selectedDay),
    );
    if (action == null || !_state.mounted) {
      return;
    }
    switch (action) {
      case CalendarDayAction.view:
        exitRange();
        onDaySelected(normalizedDay, normalizedDay);
      case CalendarDayAction.range:
        startRange(normalizedDay);
      case CalendarDayAction.write:
        await openCreateEditorWithDraftPrompt(day: normalizedDay);
      case CalendarDayAction.capsule:
        await openCreateEditorWithDraftPrompt(
          day: normalizedDay,
          capsuleUnlockAt: normalizedDay,
        );
      case CalendarDayAction.anniversary:
        await addAnniversary(normalizedDay);
    }
  }

  /// 日历月/周格式切换回调（支持上下滑手势触发）。
  void onCalendarFormatChanged(CalendarFormat format) {
    if (_state._calendarFormat == format) {
      return;
    }
    _state.applyState(() => _state._calendarFormat = format);
  }

  /// 日期选中回调：联动“选中日列表”和“焦点月份”；范围选择中改为定首尾。
  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (tapInRange(selectedDay, focusedDay)) {
      return;
    }
    final normalizedSelectedDay = DateUtils.dateOnly(selectedDay);
    final normalizedFocusedDay = DateUtils.dateOnly(focusedDay);
    if (isSameDay(_state._selectedDay, normalizedSelectedDay) &&
        isSameDay(_state._focusedMonth, normalizedFocusedDay)) {
      return;
    }
    _state.applyState(() {
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
    _state.applyState(() => _state._focusedMonth = normalizedFocusedDay);
  }

  /// 一键回到今天：重置选中日、焦点月份和格式状态（年视图回到月视图）。
  void jumpToToday() {
    final now = DateTime.now();
    _state.applyState(() {
      _state._yearMode = false;
      _state._range = null;
      _state._selectedDay = DateUtils.dateOnly(now);
      _state._focusedMonth = DateUtils.dateOnly(now);
      _state._calendarFormat = CalendarFormat.month;
    });
  }

  /// 头部「上个月」快捷动作；年视图下为上一年。
  void goToPreviousMonth() {
    _state._yearMode ? _switchYear(-1) : _switchMonth(-1);
  }

  /// 头部「下个月」快捷动作；年视图下为下一年。
  void goToNextMonth() {
    _state._yearMode ? _switchYear(1) : _switchMonth(1);
  }

  /// 年视图翻年：保留月份，回到月视图时仍落在同一个月。
  void _switchYear(int offset) {
    final focused = _state._focusedMonth;
    _state.applyState(
      () =>
          _state._focusedMonth = DateTime(focused.year + offset, focused.month),
    );
  }

  /// 打开日期选择弹窗并跳转到指定日期。
  ///
  /// 交互约束：
  /// - 日期范围与日历组件保持一致（2010-01-01 ~ 2100-12-31）；
  /// - 从当前浏览日期打开，选择完成后同步更新选中日和焦点月份；
  /// - 跳转时统一切到月视图，便于用户定位月份上下文。
  Future<void> pickDateAndJump() async {
    final firstDate = CalendarMonthGrid.firstDay;
    final lastDate = CalendarMonthGrid.lastDay;
    // 浏览年/月不会改变选中日；沿用选中日会让弹窗突然回到上次选择的年份。
    // 年视图可浏览到范围外，弹窗仍须把初始日期限制在月历支持的范围内。
    final focused = DateUtils.dateOnly(_state._focusedMonth);
    final initialDate = focused.isBefore(firstDate)
        ? firstDate
        : focused.isAfter(lastDate)
        ? lastDate
        : focused;

    final pickedDate = await showDatePicker(
      context: _state.context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: Localizations.localeOf(_state.context),
      helpText: _state.context.l10n.autoT0177,
      cancelText: _state.context.l10n.commonCancel,
      confirmText: _state.context.l10n.commonConfirm,
    );
    if (pickedDate == null || !_state.mounted) {
      return;
    }

    final normalizedDay = DateUtils.dateOnly(pickedDate);
    _state.applyState(() {
      _state._yearMode = false;
      _state._selectedDay = normalizedDay;
      _state._focusedMonth = normalizedDay;
      _state._calendarFormat = CalendarFormat.month;
    });
  }

  /// 统一处理头部快捷翻月：在同一次 setState 中提交月视图格式与目标月份，
  /// 由 TableCalendar 根据 focusedDay 变化自行播放翻页动画（时长/曲线与
  /// 减少动画开关在页面上统一配置）。
  ///
  /// 周视图下不能「先切格式、再 nextPage」：此刻 PageController 仍是周分页，
  /// 下一帧 TableCalendar 因格式变化在 didUpdateWidget 中 jumpToPage，会打断
  /// 正在进行的翻页动画，结果只切回月视图却没有翻月。
  void _switchMonth(int offset) {
    final targetMonth = DateTime(
      _state._focusedMonth.year,
      _state._focusedMonth.month + offset,
    );
    _state.applyState(() {
      _state._calendarFormat = CalendarFormat.month;
      _state._focusedMonth = targetMonth;
    });
  }

  /// 打开日记预览页（与主页列表行为保持一致）。
  ///
  /// [coverHero] 为从时间线缩略图抓取的共享元素画面，所有权转交预览页；
  /// [sequence] 为左右滑动的顺序（当天列表、那年今日），单篇入口不传。
  void openPreview(
    String diaryId, {
    DiaryWithTags? initialDetail,
    ImageViewerHero? coverHero,
    DiaryPreviewSequence? sequence,
  }) {
    Navigator.of(_state.context)
        .push<DiaryPreviewResult?>(
          MaterialPageRoute<DiaryPreviewResult?>(
            builder: (BuildContext context) => DiaryPreviewPage(
              diaryId: diaryId,
              initialDetail: initialDetail,
              coverHero: coverHero,
              sequence: sequence,
            ),
          ),
        )
        .then((DiaryPreviewResult? result) async {
          // 预览页里可能已滑到别的日记再删除：恢复的是结果里的那一篇。
          final deletedId = result?.diaryId;
          if (!_state.mounted || deletedId == null) {
            return;
          }

          final undoRequested = await _showDeleteUndoSnackBar();
          if (!_state.mounted || !undoRequested) {
            return;
          }

          try {
            final db = _state.ref.read(appDatabaseProvider);
            await db.restoreDiary(deletedId, touchUpdatedAt: false);
            if (!_state.mounted) {
              return;
            }
            await _showInfoSnackBar(_state.context.l10n.autoT0076);
          } catch (_) {
            if (!_state.mounted) {
              return;
            }
            await _showInfoSnackBar(_state.context.l10n.autoT0077);
          }
        });
  }

  /// 显示“删除成功 + 撤销”提示，并等待用户动作结果。
  ///
  /// 统一经 [HomeHintVisibilityScope.showTrackedSnackBar]：它在应用根部
  /// 注册，任何路由都找得到，并上报提示条高度，Home 的 FAB 随之上移。
  Future<bool> _showDeleteUndoSnackBar() async {
    final l10n = _state.context.l10n;
    final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(
        content: Text(l10n.autoT0075),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(label: l10n.commonUndo, onPressed: () {}),
      ),
    );
    return reason == SnackBarClosedReason.action;
  }

  /// 统一轻提示出口，避免控制器中散落重复 SnackBar 构造。
  Future<void> _showInfoSnackBar(String message) async {
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
