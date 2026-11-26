part of 'calendar_page.dart';

/// 选中日的内容（页面装配的一部分）：日记与待办的时间线、卡片样式、空状态，
/// 以及时间线要用的待办数据与操作。
extension _CalendarPageDay on _CalendarPageState {
  /// 选中日的日记与待办。
  ///
  /// - 既没有日记也没有待办（含今天的逾期）：空状态，主按钮写日记（未来
  ///   日期为时间胶囊），待办开启时旁边多一个“添加待办”；
  /// - 时间线样式：日记与待办在同一条时间线上（[CalendarTimelineSection]）；
  /// - 卡片样式：有待办时先是一条只有待办的时间线，再是日记卡片；没有日记
  ///   时就只有那条时间线（末尾带写日记入口）。
  List<Widget> _buildDayDiaryContentSlivers(
    _CalendarDayContent day,
    CalendarDisplayOptions options, {
    CalendarTimelineTodos? todos,
  }) {
    final l10n = context.l10n;
    final today = DateUtils.dateOnly(DateTime.now());
    final isFutureDay = day.day.isAfter(today);
    // 时间胶囊功能关闭时隐藏入口，数据保留：未来日期只留文案、不放按钮。
    final capsulesEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.timeCapsules),
    );
    // 未来日期：写一封在这天解封的时间胶囊；回到今天在页头。
    final VoidCallback? onWrite = !isFutureDay
        ? _openCreateForSelectedDay
        : capsulesEnabled
        ? () => unawaited(
            _controller.openCreateEditorWithDraftPrompt(
              capsuleUnlockAt: _selectedDay,
            ),
          )
        : null;
    final writeLabel = isFutureDay
        ? l10n.calendarFutureCapsuleAction
        : l10n.autoT0181;
    final hasTodos =
        todos != null && (todos.entries.isNotEmpty || todos.overdue.isNotEmpty);

    if (day.diaries.isEmpty && !hasTodos) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildDayContentTransition(
            loading: day.loading,
            errorMessage: day.errorMessage,
            child: CalendarDayEmptyState(
              key: ValueKey<String>(
                'empty_${_selectedDay.millisecondsSinceEpoch}_$isFutureDay',
              ),
              onAction: onWrite,
              message: isFutureDay ? l10n.autoT0211 : l10n.autoT0182,
              actionLabel: writeLabel,
              onSecondaryAction: todos?.onAdd,
              secondaryActionLabel: l10n.calendarAddTodo,
            ),
          ),
        ),
      ];
    }

    void openDiary(
      DiaryWithTags diary,
      ImageViewerHero? coverHero,
      ContainerTransformOrigin? origin,
    ) {
      _controller.openPreview(
        diary.diary.diaryId,
        initialDetail: diary,
        coverHero: coverHero,
        sequence: DiaryPreviewSequence.fromItems(day.diaries),
        origin: origin,
      );
    }

    // [offerWrite] 为 false：卡片样式下日记另以卡片列在下面，这条只有待办
    // 的时间线末尾不放“写日记”。
    Widget timeline({
      required List<DiaryWithTags> diaries,
      bool offerWrite = true,
    }) => _buildDayContentTransition(
      loading: day.loading,
      errorMessage: day.errorMessage,
      child: CalendarTimelineSection(
        key: ValueKey<String>('timeline_${day.day.millisecondsSinceEpoch}'),
        selectedDay: day.day,
        diaries: diaries,
        onOpenDiary: openDiary,
        todos: todos,
        onWrite: offerWrite ? onWrite : null,
        writeLabel: writeLabel,
      ),
    );

    if (options.dayContentStyle == CalendarDayContentStyle.cards &&
        day.diaries.isNotEmpty) {
      final errorMessage = day.errorMessage;
      return <Widget>[
        if (errorMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                0,
                AppSpacing.m,
                AppSpacing.s,
              ),
              child: Text(
                l10n.autoT0210(errorMessage),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
        if (hasTodos)
          SliverToBoxAdapter(
            child: timeline(
              diaries: const <DiaryWithTags>[],
              offerWrite: false,
            ),
          ),
        CalendarDayCardsSliver(
          day: day.day,
          diaries: day.diaries,
          maxVisibleTags:
              ref.watch(diaryCardTagLimitProvider).asData?.value ??
              SettingsService.defaultDiaryCardTagLimit,
          cardStyle: ref.watch(diaryCardStyleProvider),
          moodPalette: ref.watch(diaryMoodPaletteProvider),
          commentCounts:
              ref.watch(diaryCommentCountsProvider).value ??
              const <String, int>{},
          onOpenDiary: openDiary,
        ),
      ];
    }

    return <Widget>[SliverToBoxAdapter(child: timeline(diaries: day.diaries))];
  }

  /// [day] 这一天时间线要用的待办与操作：待办功能开启且显示选项打开时
  /// 才给（[index] 为 null 时返回 null，时间线只有日记）。
  ///
  /// 取的是时间线正在显示的那一天（加载新日期期间沿用上一天的日记，待办
  /// 跟着它走，不会先换待办再换日记）。选中今天时另给今天之前未完成的
  /// 待办（“已逾期”）。勾选即写库（日历里不先收起这一行），新建以这一天为
  /// 截止日、落在默认清单。
  CalendarTimelineTodos? _buildTimelineTodos(
    TodoCalendarIndex? index, {
    required DateTime day,
    required DateTime now,
  }) {
    if (index == null) {
      return null;
    }
    final today = DateUtils.dateOnly(now);
    final dayOnly = DateUtils.dateOnly(day);
    final database = ref.read(appDatabaseProvider);
    return CalendarTimelineTodos(
      entries: index.entriesOn(dayOnly),
      overdue: dayOnly == today
          ? index.overdueBefore(today)
          : const <TodoCalendarEntry>[],
      today: today,
      onToggle: (TodoRow row) =>
          unawaited(toggleTodoDone(context, database, row)),
      onOpen: (TodoRow row) => unawaited(openTodoDetail(context, row.todoId)),
      onAdd: () => unawaited(
        showTodoQuickAddSheet(
          context,
          preset: TodoQuickAddPreset(
            dueDate: dayOnly,
            listId: ref.read(todoSettingsProvider).defaultListId,
          ),
        ),
      ),
      onMoveOverdueToToday: (List<TodoRow> rows) =>
          unawaited(todoMoveRowsToDay(context, ref, rows, today)),
    );
  }

  Widget _buildDayContentTransition({
    required bool loading,
    required String? errorMessage,
    required Widget child,
  }) {
    return CalendarDayContentSwitcher(
      loading: loading,
      errorMessage: errorMessage == null
          ? null
          : context.l10n.autoT0210(errorMessage),
      child: child,
    );
  }
}
