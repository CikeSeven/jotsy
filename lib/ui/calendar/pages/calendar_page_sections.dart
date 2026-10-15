part of 'calendar_page.dart';

/// 选中日内容的展示数据：实际显示的日记（加载新日期期间沿用上一份）、它们
/// 所属的日期、标题行统计与加载/错误状态。
class _CalendarDayContent {
  const _CalendarDayContent({
    required this.diaries,
    required this.day,
    required this.entryCount,
    required this.charCount,
    required this.loading,
    required this.errorMessage,
  });

  final List<DiaryWithTags> diaries;
  final DateTime day;
  final int entryCount;
  final int charCount;
  final bool loading;
  final String? errorMessage;
}

/// 日历页各区块的构建（页面装配的一部分，拆出以控制单文件长度）。
///
/// 只读取页面状态与 provider，不改动交互状态；“沿用上一份数据”的缓存字段
/// 在构建时更新，与拆分前的写法一致。
extension _CalendarPageSections on _CalendarPageState {
  /// 当天日记的展示数据。
  ///
  /// Date changes briefly put the stream back into loading. Reuse the last
  /// successful list until the next value arrives to avoid a blank spinner
  /// flash. 标题行统计取已就绪的当天日记（未解封胶囊不计）；新日期尚未就绪
  /// 时退回打点汇总，避免统计先消失再出现。
  _CalendarDayContent _resolveDayContent(
    AsyncValue<List<DiaryWithTags>> dayDiariesAsync, {
    required CalendarDaySummary? fallbackSummary,
    required DateTime now,
  }) {
    final latest = dayDiariesAsync.asData?.value;
    if (latest != null) {
      _cachedDayDiaries = latest;
      _cachedDayDiariesSelectedDay = _selectedDay;
    }
    var entryCount = fallbackSummary?.entryCount ?? 0;
    var charCount = fallbackSummary?.charCount ?? 0;
    if (latest != null) {
      entryCount = 0;
      charCount = 0;
      for (final item in latest) {
        final locked = TimeCapsuleState.fromFields(
          lockedAt: item.diary.capsuleLockedAt,
          unlockAt: item.diary.capsuleUnlockAt,
          now: now,
        ).isLocked;
        if (!locked) {
          entryCount += 1;
          charCount += item.diary.contentText.trim().length;
        }
      }
    }
    return _CalendarDayContent(
      diaries: latest ?? _cachedDayDiaries,
      day: latest == null
          ? _cachedDayDiariesSelectedDay ?? _selectedDay
          : _selectedDay,
      entryCount: entryCount,
      charCount: charCount,
      loading: dayDiariesAsync.isLoading,
      errorMessage: dayDiariesAsync.asError?.error.toString(),
    );
  }

  Widget _buildCalendarPanel({
    required CalendarDisplayOptions options,
    required Map<DateTime, CalendarDaySummary> summaries,
    required AsyncValue<List<DiaryCalendarMarker>> markersAsync,
    required List<String> moodOptions,
    required DateTime now,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(now);
    final focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month);
    final year = _focusedMonth.year;
    final stats = !options.showMonthSummary
        ? null
        : _yearMode
        ? CalendarMonthStats.computeRange(
            summaries,
            start: DateTime(year),
            end: DateTime(year + 1),
            now: now,
            moodOptions: moodOptions,
          )
        : CalendarMonthStats.compute(
            summaries,
            month: focusedMonth,
            now: now,
            moodOptions: moodOptions,
          );
    // 面板外观不随交互变化（主题切换已由 MaterialApp 的主题动画插值），
    // 用普通 Container 避免 AnimatedContainer 在主题动画中二次追赶目标值。
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s,
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: ExpressiveSurfaces.cardColor(colorScheme),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: ExpressiveSurfaces.cardBorderColor(colorScheme),
          width: 0.8,
        ),
        boxShadow: AppEffects.restingCardShadow(colorScheme),
      ),
      child: Stack(
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildPanelBody(
                options: options,
                summaries: summaries,
                moodOptions: moodOptions,
              ),
              if (stats != null)
                CalendarMonthSummary(
                  stats: stats,
                  isFutureMonth: _yearMode
                      ? year > today.year
                      : focusedMonth.isAfter(today),
                ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: CalendarRefreshCapsule(
              loading: markersAsync.isLoading,
              error: markersAsync.asError?.error,
            ),
          ),
        ],
      ),
    );
  }

  /// 月/周网格与年视图之间的切换：缩放 + 淡入（进入年视图像“拉远”），
  /// 卡片高度经 AnimatedSize 过渡。网格内部的月/周高度动画是 table_calendar
  /// 自己的 AnimatedSize，外层在子项连续变化时会直接跟随，不会滞后。
  Widget _buildPanelBody({
    required CalendarDisplayOptions options,
    required Map<DateTime, CalendarDaySummary> summaries,
    required List<String> moodOptions,
  }) {
    final Widget body;
    if (_yearMode) {
      body = CalendarYearView(
        key: const ValueKey<String>('year'),
        year: _focusedMonth.year,
        summaries: summaries,
        basis: options.yearBasis,
        moodOptions: moodOptions,
        firstWeekday: CalendarMonthGrid.firstWeekdayOf(
          options.weekStart,
          MaterialLocalizations.of(context),
        ),
        captureKey: _yearCaptureKey,
        exporting: _exportingYear,
        onMonthTap: _controller.openMonthFromYear,
        onBasisChanged: _controller.setYearBasis,
        onExport: () => unawaited(_controller.exportYearImage()),
      );
    } else {
      body = CalendarMonthGrid(
        key: const ValueKey<String>('month'),
        focusedDay: _focusedMonth,
        selectedDay: _selectedDay,
        format: _calendarFormat,
        options: options,
        summaries: summaries,
        inlineImages: options.cellStyle == CalendarCellStyle.photo
            ? _cachedInlineImages
            : const <String, String>{},
        onDaySelected: _controller.onDaySelected,
        onPageChanged: _controller.onPageChanged,
        onFormatChanged: _controller.onCalendarFormatChanged,
        onDayLongPressed: (DateTime day) =>
            unawaited(_controller.onDayLongPressed(day)),
      );
    }
    return AnimatedSize(
      duration: ExpressiveMotion.durationNonZero(
        context,
        ExpressiveMotion.standard,
      ),
      curve: ExpressiveMotion.effects,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        layoutBuilder: CalendarDayContentSwitcher.topAlignedSwitcherLayout,
        transitionBuilder: (Widget child, Animation<double> animation) {
          // 年视图从略大缩回原尺寸、月视图从略小放大：两个方向都像在同一
          // 张日历上拉远/拉近。
          final isYear = child.key == const ValueKey<String>('year');
          final scale = Tween<double>(
            begin: isYear ? 1.06 : 0.94,
            end: 1,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: scale,
              alignment: Alignment.topCenter,
              child: child,
            ),
          );
        },
        child: body,
      ),
    );
  }

  List<Widget> _buildDayDiaryContentSlivers(
    _CalendarDayContent day,
    CalendarDisplayOptions options,
  ) {
    final l10n = context.l10n;
    if (day.diaries.isEmpty) {
      final today = DateUtils.dateOnly(DateTime.now());
      final isFutureDay = _selectedDay.isAfter(today);
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildDayContentTransition(
            loading: day.loading,
            errorMessage: day.errorMessage,
            child: CalendarDayEmptyState(
              key: ValueKey<String>(
                'empty_${_selectedDay.millisecondsSinceEpoch}_$isFutureDay',
              ),
              // 未来日期：写一封在这天解封的时间胶囊；回到今天在页头。
              onAction: isFutureDay
                  ? () => unawaited(
                      _controller.openCreateEditorWithDraftPrompt(
                        capsuleUnlockAt: _selectedDay,
                      ),
                    )
                  : _openCreateFromHomeFab,
              message: isFutureDay ? l10n.autoT0211 : l10n.autoT0182,
              actionLabel: isFutureDay
                  ? l10n.calendarFutureCapsuleAction
                  : l10n.autoT0181,
            ),
          ),
        ),
      ];
    }

    void openDiary(DiaryWithTags diary, ImageViewerHero? coverHero) {
      _controller.openPreview(
        diary.diary.diaryId,
        initialDetail: diary,
        coverHero: coverHero,
      );
    }

    if (options.dayContentStyle == CalendarDayContentStyle.cards) {
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
        CalendarDayCardsSliver(
          day: day.day,
          diaries: day.diaries,
          maxVisibleTags:
              ref.watch(diaryCardTagLimitProvider).asData?.value ??
              SettingsService.defaultDiaryCardTagLimit,
          onOpenDiary: openDiary,
          onCreate: () => unawaited(_openCreateFromHomeFab()),
        ),
      ];
    }

    return <Widget>[
      SliverToBoxAdapter(
        child: _buildDayContentTransition(
          loading: day.loading,
          errorMessage: day.errorMessage,
          child: CalendarTimelineSection(
            key: ValueKey<String>('timeline_${day.day.millisecondsSinceEpoch}'),
            selectedDay: day.day,
            diaries: day.diaries,
            onOpenDiary: openDiary,
          ),
        ),
      ),
    ];
  }

  /// 那年今日：没有其他年份的记录时整块收起；换日时沿用上一份直到新结果
  /// 返回，再交叉淡入，高度经 AnimatedSize 过渡。未解封的胶囊不出现。
  Widget _buildOnThisDaySliver(DateTime now) {
    final latest = ref.watch(calendarOnThisDayProvider(_selectedDay)).asData;
    if (latest != null) {
      _cachedOnThisDay = latest.value;
    }
    final diaries = _cachedOnThisDay
        .where(
          (DiaryWithTags item) => !TimeCapsuleState.fromFields(
            lockedAt: item.diary.capsuleLockedAt,
            unlockAt: item.diary.capsuleUnlockAt,
            now: now,
          ).isLocked,
        )
        .toList(growable: false);
    final signature = diaries
        .map((DiaryWithTags item) => item.diary.diaryId)
        .join('|');
    return SliverToBoxAdapter(
      child: AnimatedSize(
        duration: ExpressiveMotion.durationNonZero(
          context,
          ExpressiveMotion.medium,
        ),
        curve: ExpressiveMotion.effects,
        alignment: Alignment.topCenter,
        // 卡片带外阴影，默认 hardEdge 会在高度过渡时切出硬边。
        clipBehavior: Clip.none,
        child: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          layoutBuilder: CalendarDayContentSwitcher.topAlignedSwitcherLayout,
          child: diaries.isEmpty
              ? const SizedBox(
                  key: ValueKey<String>('on_this_day_empty'),
                  width: double.infinity,
                )
              : CalendarOnThisDayStrip(
                  key: ValueKey<String>(
                    'on_this_day_${_selectedDay.millisecondsSinceEpoch}_'
                    '$signature',
                  ),
                  selectedDay: _selectedDay,
                  diaries: diaries,
                  onOpenDiary: (diary, coverHero) => _controller.openPreview(
                    diary.diary.diaryId,
                    initialDetail: diary,
                    coverHero: coverHero,
                  ),
                ),
        ),
      ),
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
