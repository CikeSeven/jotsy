import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../diaries/models/new_diary_draft.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/pages/edit_diary_page.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../providers/calendar_diary_providers.dart';
import '../widgets/calendar_day_content_switcher.dart';
import '../widgets/calendar_day_empty_state.dart';
import '../widgets/calendar_header.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/image_viewer_hero.dart';
import '../widgets/calendar_timeline_section.dart';
import '../../../app/theme/app_effects.dart';

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
    this.pageBackgroundColor,
    this.onCreateActionChanged,
    this.onFabVisibilityChanged,
  });

  final Color? pageBackgroundColor;
  final ValueChanged<Future<void> Function()?>? onCreateActionChanged;
  final ValueChanged<bool>? onFabVisibilityChanged;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

/// 无底色的日期格：与“今天/选中”同形状，见 [CalendarStyle] 处说明。
const BoxDecoration _calendarCellDecoration = BoxDecoration(
  borderRadius: BorderRadius.all(Radius.circular(14)),
);

class _CalendarPageState extends ConsumerState<CalendarPage> {
  static const double _fabToggleScrollThreshold = 26;
  static const double _calendarCardHorizontalPadding = AppSpacing.m;
  static const double _calendarCardTopPadding = AppSpacing.m;
  static const double _calendarBottomGap = AppSpacing.m;
  static const double _listBottomExtraSpace = 12;
  static const double _refreshIndicatorSize = 18;
  Map<DateTime, List<DiaryCalendarMarker>> _cachedMarkerBuckets =
      const <DateTime, List<DiaryCalendarMarker>>{};
  List<DiaryCalendarMarker>? _groupedMarkersSource;
  List<DiaryWithTags> _cachedDayDiaries = const <DiaryWithTags>[];
  DateTime? _cachedDayDiariesSelectedDay;

  late final _CalendarPageController _controller;
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
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
    // 选日、切换月/周格式等 setState 都会重建页面；打点列表引用未变时复用
    // 上次的分桶结果，只在 provider 推送新列表时重新分组。
    final Map<DateTime, List<DiaryCalendarMarker>>? latestMarkerBuckets;
    if (latestMarkers == null) {
      latestMarkerBuckets = null;
    } else if (identical(latestMarkers, _groupedMarkersSource)) {
      latestMarkerBuckets = _cachedMarkerBuckets;
    } else {
      latestMarkerBuckets = _controller.groupMarkersByDay(latestMarkers);
      _groupedMarkersSource = latestMarkers;
    }
    if (latestMarkerBuckets != null) {
      _cachedMarkerBuckets = latestMarkerBuckets;
    }
    // Riverpod emits loading/error while switching month streams. Keep the last
    // successful buckets visible so month navigation does not read as data loss.
    final markerBuckets = latestMarkerBuckets ?? _cachedMarkerBuckets;
    final markerStatus = _CalendarStaleStatus.from(markersAsync);
    final pageBgColor =
        widget.pageBackgroundColor ?? Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: pageBgColor,
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
                      // 日期格式交给 intl 按语言区域决定（中文“10月5日”、
                      // 英文“Oct 5”），不再手写中英分支。选日后与下方内容
                      // 一起交叉淡入，而不是标签先硬切。
                      child: AnimatedSwitcher(
                        duration: ExpressiveMotion.duration(
                          context,
                          ExpressiveMotion.fast,
                        ),
                        switchInCurve: ExpressiveMotion.effects,
                        switchOutCurve: ExpressiveMotion.exit,
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: AlignmentDirectional.centerStart,
                              children: <Widget>[
                                ...previousChildren,
                                ?currentChild,
                              ],
                            ),
                        child: Text(
                          DateFormat.MMMd(l10n.localeName).format(_selectedDay),
                          key: ValueKey<DateTime>(_selectedDay),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
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
          CalendarHeader(
            title: _controller.focusedMonthTitle,
            month: _focusedMonth,
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
          TableCalendar<DiaryCalendarMarker>(
            locale: l10n.localeName,
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
            // 翻页与月/周切换动画统一走 Expressive token；减少动画时直接跳转。
            pageAnimationEnabled: !ExpressiveMotion.reduceMotion(context),
            pageAnimationDuration: ExpressiveMotion.medium,
            pageAnimationCurve: ExpressiveMotion.effects,
            // table_calendar 用 AnimatedSize 过渡月/周高度，减少动画时不能传 0。
            formatAnimationDuration: ExpressiveMotion.durationNonZero(
              context,
              ExpressiveMotion.medium,
            ),
            formatAnimationCurve: ExpressiveMotion.effects,
            calendarStyle: CalendarStyle(
              isTodayHighlighted: true,
              todayDecoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              todayTextStyle: TextStyle(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              selectedTextStyle: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
              // 普通/周末/月外格与“今天/选中”同为 14dp 圆角矩形（透明底）：
              // table_calendar 用 AnimatedContainer 在两种 decoration 间补间，
              // 圆形 ↔ 圆角矩形会在补间中点突变形状，选中高亮半途“啪”地换形；
              // 形状一致后只补间颜色。
              defaultDecoration: _calendarCellDecoration,
              weekendDecoration: _calendarCellDecoration,
              outsideDecoration: _calendarCellDecoration,
              disabledDecoration: _calendarCellDecoration,
              defaultTextStyle: textTheme.bodyMedium!.copyWith(
                color: colorScheme.onSurface,
              ),
              weekendTextStyle: textTheme.bodyMedium!.copyWith(
                color: colorScheme.onSurface,
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
                // 独立窄星期（ccccc）：中文“一…日”、英文“M…S”，
                // 由 intl 语言数据提供，新增语言无需改代码。
                final label = DateFormat('ccccc', l10n.localeName).format(day);
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
    final displayedSelectedDay = latestDayDiaries == null
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
              onAction: isFutureDay
                  ? _controller.jumpToToday
                  : _openCreateFromHomeFab,
              message: isFutureDay
                  ? context.l10n.autoT0211
                  : context.l10n.autoT0182,
              actionLabel: isFutureDay
                  ? context.l10n.autoT0180
                  : context.l10n.autoT0181,
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
            onOpenDiary: (diary, coverHero) => _controller.openPreview(
              diary.diary.diaryId,
              initialDetail: diary,
              coverHero: coverHero,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildCalendarRefreshOverlay(_CalendarStaleStatus status) {
    final error = status.error;
    return Positioned(
      top: 0,
      right: 0,
      // 翻月后 family provider 换 key，首帧必为 loading；本地查询通常几毫秒
      // 即返回，延迟显示加载胶囊避免每次翻月都闪一下。错误态立即显示。
      child: DelayedLoadingGate(
        loading: status.isLoading,
        builder: (context, showLoading) => _buildCalendarRefreshCapsule(
          showLoading: showLoading,
          error: error,
        ),
      ),
    );
  }

  Widget _buildCalendarRefreshCapsule({
    required bool showLoading,
    required Object? error,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showOverlay = showLoading || error != null;
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      child: showOverlay
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
                    if (showLoading)
                      const ExpressiveLoadingIndicator(
                        size: _refreshIndicatorSize,
                      ),
                    if (error != null)
                      FaIcon(
                        FontAwesomeIcons.circleInfo,
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
    );
  }

  Widget _buildDayContentTransition({
    required _CalendarStaleStatus status,
    required String? errorMessage,
    required Widget child,
  }) {
    return CalendarDayContentSwitcher(
      loading: status.isLoading,
      errorMessage: errorMessage == null
          ? null
          : context.l10n.autoT0210(errorMessage),
      child: child,
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

enum _CalendarCreateDraftDecision { newEmpty, continueEditing }
