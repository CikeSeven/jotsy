import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/models/new_diary_draft.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/pages/edit_diary_page.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/glass_bottom_nav.dart';
import '../providers/calendar_diary_providers.dart';
import '../widgets/calendar_day_empty_state.dart';
import '../widgets/calendar_glass_header.dart';
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
  static const double _listBottomExtraSpace = 34;
  static const Duration _calendarMorphDuration = Duration(milliseconds: 260);

  late final CalendarPageController _controller;
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  PageController? _calendarPageController;
  bool _fabVisibleByScroll = true;
  double _fabScrollDeltaAccumulator = 0;

  @override
  void initState() {
    super.initState();
    _controller = CalendarPageController(this);
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
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final headerHeight =
        MediaQuery.paddingOf(context).top + CalendarGlassHeader.contentHeight;
    final listBottomOffset =
        bottomSafeInset +
        GlassBottomNav.navBottomInset +
        GlassBottomNav.navHeight +
        _listBottomExtraSpace;
    final focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month);
    final markersAsync = ref.watch(calendarMonthMarkersProvider(focusedMonth));
    final dayDiariesAsync = ref.watch(calendarDayDiariesProvider(_selectedDay));
    final markerBuckets = markersAsync.maybeWhen(
      data: _controller.groupMarkersByDay,
      orElse: () => const <DateTime, List<DiaryCalendarMarker>>{},
    );

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
                      child: _buildCalendarPanel(markerBuckets),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  ..._buildDayDiaryContentSlivers(dayDiariesAsync),
                  SliverToBoxAdapter(child: SizedBox(height: listBottomOffset)),
                ],
              ),
            ),
          ),
          CalendarGlassHeader(
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
  ) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
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
      child: TableCalendar<DiaryCalendarMarker>(
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
          outsideTextStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        calendarBuilders: CalendarBuilders<DiaryCalendarMarker>(
          markerBuilder: (context, day, events) {
            if (events.isEmpty) {
              return null;
            }
            final mood = _controller.resolveMoodEmoji(events);
            if (mood != null) {
              return Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    mood,
                    style: const TextStyle(fontSize: 10),
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
            final label = l10n.isZh
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
    );
  }

  List<Widget> _buildDayDiaryContentSlivers(
    AsyncValue<List<DiaryWithTags>> dayDiariesAsync,
  ) {
    return dayDiariesAsync.when(
      loading: () {
        return <Widget>[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        ];
      },
      error: (error, stackTrace) {
        return <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                AppSpacing.m,
                AppSpacing.m,
                AppSpacing.m,
              ),
              child: Text(
                context.l10n.autoT0210(error.toString()),
              ),
            ),
          ),
        ];
      },
      data: (dayDiaries) {
        if (dayDiaries.isEmpty) {
          final today = DateUtils.dateOnly(DateTime.now());
          final isFutureDay = _selectedDay.isAfter(today);
          return <Widget>[
            SliverToBoxAdapter(
              child: CalendarDayEmptyState(
                onAction: isFutureDay ? _controller.jumpToToday : _openCreateFromHomeFab,
                message: isFutureDay
                    ? context.l10n.autoT0211
                    : context.l10n.autoT0182,
                actionLabel: isFutureDay
                    ? context.l10n.autoT0180
                    : context.l10n.autoT0181,
              ),
            ),
          ];
        }
        return <Widget>[
          SliverToBoxAdapter(
            child: CalendarTimelineSection(
              selectedDay: _selectedDay,
              diaries: dayDiaries,
              onOpenDiary: _controller.openPreview,
            ),
          ),
        ];
      },
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
}

enum _CalendarCreateDraftDecision { newEmpty, continueEditing }
