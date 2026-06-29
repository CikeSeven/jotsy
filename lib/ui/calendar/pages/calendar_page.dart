import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../diaries/models/new_diary_draft.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/pages/edit_diary_page.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../providers/calendar_diary_providers.dart';
import '../widgets/calendar_day_empty_state.dart';
import '../widgets/calendar_header.dart';
import '../widgets/calendar_timeline_section.dart';

part '../controllers/calendar_page_controller.dart';

/// 日历页（上历下表）。
///
/// 页面职责：
/// - 展示可切换月/周的日历网格；
/// - 展示选中日期的日记列表；
/// - 注册 Home 层全局 FAB 的“按选中日期新建”动作。
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({
    super.key,
    required this.pageBackgroundColor,
    this.onCreateActionChanged,
    this.onFabVisibilityChanged,
  });

  final Color pageBackgroundColor;
  final ValueChanged<Future<void> Function()?>? onCreateActionChanged;
  final ValueChanged<bool>? onFabVisibilityChanged;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  static const double _fabToggleScrollThreshold = 26;
  static const double _calendarCardHorizontalPadding = AppSpacing.m;
  static const double _calendarCardTopPadding = AppSpacing.m;
  static const double _calendarBottomGap = AppSpacing.m;
  static const double _listBottomExtraSpace = 12;
  static const Duration _calendarMorphDuration = Duration(milliseconds: 260);
  static const Duration _dayContentSwitchDuration = Duration(milliseconds: 220);
  static const Duration _refreshOverlaySwitchDuration = Duration(
    milliseconds: 160,
  );
  static const double _refreshIndicatorSize = 18;
  Map<DateTime, List<DiaryCalendarMarker>> _cachedMarkerBuckets =
      const <DateTime, List<DiaryCalendarMarker>>{};
  List<DiaryWithTags> _cachedDayDiaries = const <DiaryWithTags>[];
  DateTime? _cachedDayDiariesSelectedDay;

  late final _CalendarPageController _controller;
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  PageController? _calendarPageController;
  bool _fabVisibleByScroll = true;
  double _fabScrollDeltaAccumulator = 0;

  @override
  void initState() {
    super.initState();
    _controller = _CalendarPageController(this);
    final now = DateTime.now();
    _selectedDay = DateUtils.dateOnly(now);
    _focusedMonth = _selectedDay;
    widget.onCreateActionChanged?.call(_openCreateFromHomeFab);
    widget.onFabVisibilityChanged?.call(_fabVisibleByScroll);
  }

  @override
  void didUpdateWidget(covariant CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onCreateActionChanged != widget.onCreateActionChanged) {
      oldWidget.onCreateActionChanged?.call(null);
      widget.onCreateActionChanged?.call(_openCreateFromHomeFab);
    }
    if (oldWidget.onFabVisibilityChanged != widget.onFabVisibilityChanged) {
      widget.onFabVisibilityChanged?.call(_fabVisibleByScroll);
    }
  }

  @override
  void dispose() {
    widget.onCreateActionChanged?.call(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final headerHeight =
        MediaQuery.paddingOf(context).top + CalendarHeader.contentHeight;
    final listBottomOffset = _listBottomExtraSpace;
    final focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month);
    final markersAsync = ref.watch(calendarMonthMarkersProvider(focusedMonth));
    final dayDiariesAsync = ref.watch(calendarDayDiariesProvider(_selectedDay));
    final moodOptionsAsync = ref.watch(moodOptionsProvider);
    final moodOptions = moodOptionsAsync.maybeWhen(
      data: (options) => options,
      orElse: () => SettingsService.defaultMoodOptions,
    );
    final latestMarkers = markersAsync.asData?.value;
    final latestMarkerBuckets =
        latestMarkers == null
            ? null
            : _controller.groupMarkersByDay(latestMarkers);
    if (latestMarkerBuckets != null) {
      _cachedMarkerBuckets = latestMarkerBuckets;
    }
    // Riverpod emits loading/error while switching month streams. Keep the last
    // successful buckets visible so month navigation does not read as data loss.
    final markerBuckets = latestMarkerBuckets ?? _cachedMarkerBuckets;
    final markerStatus = _CalendarStaleStatus.from(markersAsync);

    return Scaffold(
      backgroundColor: widget.pageBackgroundColor,
      body: Stack(
        children: <Widget>[
          SafeArea(
            top: false,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handlePrimaryScrollNotification,
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(child: SizedBox(height: headerHeight)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _calendarCardHorizontalPadding,
                        _calendarCardTopPadding,
                        _calendarCardHorizontalPadding,
                        _calendarBottomGap,
                      ),
                      child: _buildCalendarPanel(
                        markerBuckets,
                        markerStatus,
                        moodOptions,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.m,
                        0,
                        AppSpacing.m,
                        AppSpacing.s,
                      ),
                      child: Text(
                        l10n.isZh
                            ? DateFormat('M月d日', 'zh').format(_selectedDay)
                            : DateFormat('MMM d', 'en').format(_selectedDay),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  ..._buildDayDiaryContentSlivers(dayDiariesAsync),
                  SliverToBoxAdapter(child: SizedBox(height: listBottomOffset)),
                ],
              ),
            ),
          ),
          CalendarHeader(
            title: _controller.focusedMonthTitle,
            onJumpToToday: _controller.jumpToToday,
            onPreviousMonth: _controller.goToPreviousMonth,
            onNextMonth: _controller.goToNextMonth,
            onPickDate: () => unawaited(_controller.pickDateAndJump()),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarPanel(
    Map<DateTime, List<DiaryCalendarMarker>> markerBuckets,
    _CalendarStaleStatus markerStatus,
    List<String> moodOptions,
  ) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: _calendarMorphDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s,
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: <Widget>[
          TableCalendar<DiaryCalendarMarker>(
            locale: l10n.isZh ? 'zh_CN' : 'en_US',
            firstDay: DateTime(2010, 1, 1),
            lastDay: DateTime(2100, 12, 31),
            focusedDay: _focusedMonth,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            headerVisible: false,
            availableGestures: AvailableGestures.all,
            availableCalendarFormats: <CalendarFormat, String>{
              CalendarFormat.month: l10n.autoT0178,
              CalendarFormat.week: l10n.autoT0179,
            },
            eventLoader: (day) {
              final bucketDay = DateUtils.dateOnly(day);
              return markerBuckets[bucketDay] ?? const <DiaryCalendarMarker>[];
            },
            onFormatChanged: _controller.onCalendarFormatChanged,
            onDaySelected: _controller.onDaySelected,
            onPageChanged: _controller.onPageChanged,
            onCalendarCreated: _controller.onCalendarCreated,
            calendarStyle: CalendarStyle(
              isTodayHighlighted: true,
              todayDecoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              outsideTextStyle: textTheme.bodyMedium!.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: textTheme.labelMedium!.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              weekendStyle: textTheme.labelMedium!.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            calendarBuilders: CalendarBuilders<DiaryCalendarMarker>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) {
                  return null;
                }
                final mood = _controller.resolveMoodEmoji(events, moodOptions);
                if (mood != null) {
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        mood,
                        style: textTheme.labelSmall?.copyWith(
                          fontSize:
                              (textTheme.labelSmall?.fontSize ?? 11) * 0.9,
                          height: 1,
                        ),
                      ),
                    ),
                  );
                }
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
              dowBuilder: (context, day) {
                final weekday = day.weekday;
                final labelsZh = <int, String>{
                  DateTime.monday: '一',
                  DateTime.tuesday: '二',
                  DateTime.wednesday: '三',
                  DateTime.thursday: '四',
                  DateTime.friday: '五',
                  DateTime.saturday: '六',
                  DateTime.sunday: '日',
                };
                final labelsEn = <int, String>{
                  DateTime.monday: 'M',
                  DateTime.tuesday: 'T',
                  DateTime.wednesday: 'W',
                  DateTime.thursday: 'T',
                  DateTime.friday: 'F',
                  DateTime.saturday: 'S',
                  DateTime.sunday: 'S',
                };
                final label =
                    l10n.isZh
                        ? (labelsZh[weekday] ?? '')
                        : (labelsEn[weekday] ?? '');
                return Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          _buildCalendarRefreshOverlay(markerStatus),
        ],
      ),
    );
  }

  List<Widget> _buildDayDiaryContentSlivers(
    AsyncValue<List<DiaryWithTags>> dayDiariesAsync,
  ) {
    final latestDayDiaries = dayDiariesAsync.asData?.value;
    if (latestDayDiaries != null) {
      _cachedDayDiaries = latestDayDiaries;
      _cachedDayDiariesSelectedDay = _selectedDay;
    }

    // Date changes briefly put the stream back into loading. Reuse the last
    // successful list until the next value arrives to avoid a blank spinner flash.
    final displayedDayDiaries = latestDayDiaries ?? _cachedDayDiaries;
    final displayedSelectedDay =
        latestDayDiaries == null
            ? _cachedDayDiariesSelectedDay ?? _selectedDay
            : _selectedDay;
    final status = _CalendarStaleStatus.from(dayDiariesAsync);
    final errorMessage = dayDiariesAsync.asError?.error.toString();

    if (displayedDayDiaries.isEmpty) {
      final today = DateUtils.dateOnly(DateTime.now());
      final isFutureDay = _selectedDay.isAfter(today);
      return <Widget>[
        SliverToBoxAdapter(
          child: _buildDayContentTransition(
            status: status,
            errorMessage: errorMessage,
            child: CalendarDayEmptyState(
              key: ValueKey<String>(
                'empty_${_selectedDay.millisecondsSinceEpoch}_$isFutureDay',
              ),
              onAction:
                  isFutureDay
                      ? _controller.jumpToToday
                      : _openCreateFromHomeFab,
              message:
                  isFutureDay ? context.l10n.autoT0211 : context.l10n.autoT0182,
              actionLabel:
                  isFutureDay ? context.l10n.autoT0180 : context.l10n.autoT0181,
            ),
          ),
        ),
      ];
    }

    return <Widget>[
      SliverToBoxAdapter(
        child: _buildDayContentTransition(
          status: status,
          errorMessage: errorMessage,
          child: CalendarTimelineSection(
            key: ValueKey<String>(
              'timeline_${displayedSelectedDay.millisecondsSinceEpoch}',
            ),
            selectedDay: displayedSelectedDay,
            diaries: displayedDayDiaries,
            onOpenDiary: _controller.openPreview,
          ),
        ),
      ),
    ];
  }

  Widget _buildCalendarRefreshOverlay(_CalendarStaleStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final error = status.error;
    final showOverlay = status.isLoading || error != null;
    return Positioned(
      top: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: _refreshOverlaySwitchDuration,
        child:
            showOverlay
                ? DecoratedBox(
                  key: ValueKey<Object>(error ?? 'loading'),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (status.isLoading)
                          const LoadingIndicatorM3E(
                            variant: LoadingIndicatorM3EVariant.contained,
                            constraints: BoxConstraints.tightFor(
                              width: _refreshIndicatorSize,
                              height: _refreshIndicatorSize,
                            ),
                          ),
                        if (error != null)
                          Icon(
                            Icons.info_outline_rounded,
                            size: _refreshIndicatorSize,
                            color: colorScheme.error,
                          ),
                        if (error != null) ...<Widget>[
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 190),
                            child: Text(
                              context.l10n.autoT0210(error.toString()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                : const SizedBox.shrink(key: ValueKey<String>('idle')),
      ),
    );
  }

  Widget _buildDayContentTransition({
    required _CalendarStaleStatus status,
    required String? errorMessage,
    required Widget child,
  }) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: _dayContentSwitchDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: child,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: _refreshOverlaySwitchDuration,
              child:
                  status.isLoading
                      ? const _CalendarInlineRefreshScrim(
                        key: ValueKey<String>('day_loading'),
                      )
                      : const SizedBox.shrink(
                        key: ValueKey<String>('day_idle'),
                      ),
            ),
          ),
        ),
        if (errorMessage != null)
          Positioned(
            left: AppSpacing.m,
            right: AppSpacing.m,
            top: 0,
            child: _CalendarErrorBanner(
              message: context.l10n.autoT0210(errorMessage),
            ),
          ),
      ],
    );
  }

  Future<void> _openCreateFromHomeFab() async {
    await _controller.openCreateEditorWithDraftPrompt();
  }

  bool _handlePrimaryScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollEndNotification) {
      _fabScrollDeltaAccumulator = 0;
      return false;
    }

    if (notification is! ScrollUpdateNotification) {
      return false;
    }
    final delta = notification.scrollDelta;
    if (delta == null || delta.abs() < 0.5) {
      return false;
    }

    if (notification.metrics.pixels <= 0) {
      _fabScrollDeltaAccumulator = 0;
      _updateFabVisibilityByScroll(true);
      return false;
    }

    _fabScrollDeltaAccumulator += delta;
    if (_fabScrollDeltaAccumulator >= _fabToggleScrollThreshold) {
      _fabScrollDeltaAccumulator = 0;
      _updateFabVisibilityByScroll(false);
      return false;
    }
    if (_fabScrollDeltaAccumulator <= -_fabToggleScrollThreshold) {
      _fabScrollDeltaAccumulator = 0;
      _updateFabVisibilityByScroll(true);
      return false;
    }
    return false;
  }

  void _updateFabVisibilityByScroll(bool visible) {
    if (_fabVisibleByScroll == visible) {
      return;
    }
    _fabVisibleByScroll = visible;
    widget.onFabVisibilityChanged?.call(visible);
  }

  void applyState(VoidCallback mutate) {
    if (!mounted) {
      return;
    }
    setState(mutate);
  }
}

class _CalendarStaleStatus {
  const _CalendarStaleStatus({required this.isLoading, required this.error});

  static _CalendarStaleStatus from<T>(AsyncValue<T> value) {
    return _CalendarStaleStatus(
      isLoading: value.isLoading,
      error: value.asError?.error,
    );
  }

  final bool isLoading;
  final Object? error;
}

class _CalendarInlineRefreshScrim extends StatelessWidget {
  const _CalendarInlineRefreshScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.32),
      ),
      child: const Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.only(top: AppSpacing.xs, right: AppSpacing.m),
          child: LoadingIndicatorM3E(
            variant: LoadingIndicatorM3EVariant.contained,
            constraints: BoxConstraints.tightFor(
              width: _CalendarPageState._refreshIndicatorSize,
              height: _CalendarPageState._refreshIndicatorSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarErrorBanner extends StatelessWidget {
  const _CalendarErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

enum _CalendarCreateDraftDecision { newEmpty, continueEditing }
