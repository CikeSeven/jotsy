import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    this.onCreateActionChanged,
  });

  final ValueChanged<Future<void> Function()?>? onCreateActionChanged;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  static const double _calendarCardHorizontalPadding = AppSpacing.m;
  static const double _calendarCardTopPadding = AppSpacing.m;
  static const double _calendarBottomGap = AppSpacing.m;
  static const double _listBottomExtraSpace = 34;
  static const Duration _calendarMorphDuration = Duration(milliseconds: 260);

  late final CalendarPageController _controller;
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _controller = CalendarPageController(this);
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = DateUtils.dateOnly(now);
    widget.onCreateActionChanged?.call(_openCreateFromHomeFab);
  }

  @override
  void didUpdateWidget(covariant CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onCreateActionChanged != widget.onCreateActionChanged) {
      oldWidget.onCreateActionChanged?.call(null);
      widget.onCreateActionChanged?.call(_openCreateFromHomeFab);
    }
  }

  @override
  void dispose() {
    widget.onCreateActionChanged?.call(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: <Widget>[
          SafeArea(
            top: false,
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
                      DateFormat('M月d日').format(_selectedDay),
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
          CalendarGlassHeader(
            title: _controller.focusedMonthTitle,
            onJumpToToday: _controller.jumpToToday,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarPanel(
    Map<DateTime, List<DiaryCalendarMarker>> markerBuckets,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: _calendarMorphDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s,
        AppSpacing.s,
        AppSpacing.s,
        AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TableCalendar<DiaryCalendarMarker>(
        locale: 'zh_CN',
        firstDay: DateTime(2010, 1, 1),
        lastDay: DateTime(2100, 12, 31),
        focusedDay: _focusedMonth,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
        headerVisible: false,
        availableGestures: AvailableGestures.all,
        availableCalendarFormats: const <CalendarFormat, String>{
          CalendarFormat.month: '月视图',
          CalendarFormat.week: '周视图',
        },
        eventLoader: (day) {
          final bucketDay = DateUtils.dateOnly(day);
          return markerBuckets[bucketDay] ?? const <DiaryCalendarMarker>[];
        },
        onFormatChanged: _controller.onCalendarFormatChanged,
        onDaySelected: _controller.onDaySelected,
        onPageChanged: _controller.onPageChanged,
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
              child: Text('日历日记加载失败: $error'),
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
                    ? '别着急，属于这一天的精彩还没发生。'
                    : '这一天很安静，没有任何记录。',
                actionLabel: isFutureDay ? '回到今天' : '补写日记',
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
}

enum _CalendarCreateDraftDecision { newEmpty, continueEditing }
