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

  /// 当前焦点月份标题（用于头部显示）。
  String get focusedMonthTitle {
    return DateFormat('yyyy年M月').format(_state._focusedMonth);
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
    final normalizedFocusedMonth = DateTime(focusedDay.year, focusedDay.month);
    if (isSameDay(_state._selectedDay, normalizedSelectedDay) &&
        _state._focusedMonth.year == normalizedFocusedMonth.year &&
        _state._focusedMonth.month == normalizedFocusedMonth.month) {
      return;
    }
    _state.setState(() {
      _state._selectedDay = normalizedSelectedDay;
      _state._focusedMonth = normalizedFocusedMonth;
    });
  }

  /// 左右翻月后更新焦点月份，并触发该月份懒加载。
  void onPageChanged(DateTime focusedDay) {
    final normalizedFocusedMonth = DateTime(focusedDay.year, focusedDay.month);
    if (_state._focusedMonth.year == normalizedFocusedMonth.year &&
        _state._focusedMonth.month == normalizedFocusedMonth.month) {
      return;
    }
    _state.setState(() => _state._focusedMonth = normalizedFocusedMonth);
  }

  /// 一键回到今天：重置选中日、焦点月份和格式状态。
  void jumpToToday() {
    final now = DateTime.now();
    _state.setState(() {
      _state._selectedDay = DateUtils.dateOnly(now);
      _state._focusedMonth = DateTime(now.year, now.month);
      _state._calendarFormat = CalendarFormat.month;
    });
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

  /// 当天 marker 里的心情 emoji 提取优先级：
  /// 1) 先返回第一个非空 mood；
  /// 2) 若都为空，返回 null（由 UI 退化为普通 dot）。
  String? resolveMoodEmoji(List<DiaryCalendarMarker> markers) {
    for (final marker in markers) {
      final mood = marker.moodEmoji?.trim();
      if (mood != null && mood.isNotEmpty) {
        return mood;
      }
    }
    return null;
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
    final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: _state.context,
      snackBar: SnackBar(
        content: const Text('已删除日记'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {},
          textColor: Theme.of(_state.context).colorScheme.onPrimary,
        ),
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
