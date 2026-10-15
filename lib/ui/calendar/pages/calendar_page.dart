import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../diaries/models/new_diary_draft.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/pages/edit_diary_page.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../models/calendar_display_options.dart';
import '../providers/calendar_diary_providers.dart';
import '../providers/calendar_display_options_provider.dart';
import '../viewmodels/calendar_day_summary.dart';
import '../viewmodels/calendar_month_stats.dart';
import '../widgets/calendar_day_actions_sheet.dart';
import '../widgets/calendar_day_cards_sliver.dart';
import '../widgets/calendar_day_content_switcher.dart';
import '../widgets/calendar_day_empty_state.dart';
import '../widgets/calendar_day_heading.dart';
import '../widgets/calendar_display_options_sheet.dart';
import '../widgets/calendar_header.dart';
import '../widgets/calendar_month_grid.dart';
import '../widgets/calendar_month_summary.dart';
import '../widgets/calendar_on_this_day_strip.dart';
import '../widgets/calendar_refresh_capsule.dart';
import '../widgets/calendar_year_view.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/image_viewer_hero.dart';
import '../widgets/calendar_timeline_section.dart';
import '../../../app/theme/app_effects.dart';

part 'calendar_page_sections.dart';
part '../controllers/calendar_page_controller.dart';
part '../controllers/calendar_create_actions.dart';
part '../controllers/calendar_display_options_actions.dart';
part '../controllers/calendar_year_actions.dart';

/// 日历页（上历下表）。
///
/// 页面职责（只做装配）：
/// - 组合页头、日历卡片（月/周网格或年视图 + 概览）、选中日标题、当天日记
///   （时间线或卡片）与那年今日；区块构建见 calendar_page_sections.dart；
/// - 监听打点/当日日记/心情配置/显示选项，翻月期间保留上一份数据；
/// - 注册 Home 层全局 FAB 的“按选中日期新建”动作。
///
/// 日期格样式、月度统计等计算在 viewmodels/，网格与日期格绘制在 widgets/，
/// 选日/翻月/新建/显示选项保存/年视图导出等流程在 controllers/。
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

class _CalendarPageState extends ConsumerState<CalendarPage> {
  static const double _fabToggleScrollThreshold = 26;
  static const double _calendarCardHorizontalPadding = AppSpacing.m;
  static const double _calendarCardTopPadding = AppSpacing.m;
  static const double _calendarBottomGap = AppSpacing.m;
  static const double _listBottomExtraSpace = 12;
  Map<DateTime, CalendarDaySummary> _cachedDaySummaries =
      const <DateTime, CalendarDaySummary>{};
  List<DiaryCalendarMarker>? _summarizedMarkersSource;
  List<String>? _summarizedMoodOptions;
  Map<String, String> _cachedInlineImages = const <String, String>{};
  List<DiaryWithTags> _cachedDayDiaries = const <DiaryWithTags>[];
  DateTime? _cachedDayDiariesSelectedDay;
  List<DiaryWithTags> _cachedOnThisDay = const <DiaryWithTags>[];

  /// 年视图“年份 + 网格 + 图例”截图区，导出图片只截这一块。
  final GlobalKey _yearCaptureKey = GlobalKey();

  late final _CalendarPageController _controller;
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  /// 显示选项 provider 首次推送前使用的选项：设置服务通常在启动时已就绪，
  /// 这里同步解码一次，首帧就按用户的样式与默认格式绘制，不先画默认样式
  /// 再跳变。
  late CalendarDisplayOptions _fallbackOptions;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  /// 年视图（点月份标题进入）；与月/周格式相互独立，退出后回到月视图。
  bool _yearMode = false;
  bool _exportingYear = false;
  bool _fabVisibleByScroll = true;
  double _fabScrollDeltaAccumulator = 0;

  @override
  void initState() {
    super.initState();
    _controller = _CalendarPageController(this);
    final now = DateTime.now();
    _selectedDay = DateUtils.dateOnly(now);
    _focusedMonth = _selectedDay;
    final settings = ref.read(settingsServiceProvider).asData?.value;
    _fallbackOptions = CalendarDisplayOptions.decode(
      settings?.calendarDisplayOptionsRaw,
    );
    _calendarFormat = _controller.formatFor(_fallbackOptions.initialFormat);
    if (settings == null) {
      _applyInitialFormatWhenOptionsLoad();
    }
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

  /// 设置服务尚未就绪（冷启动直接落在日历页等极端时序）时，等显示选项
  /// 首次推送再套用一次“打开时显示”的格式，之后网格格式只由用户操作决定。
  void _applyInitialFormatWhenOptionsLoad() {
    late final ProviderSubscription<AsyncValue<CalendarDisplayOptions>>
    subscription;
    subscription = ref.listenManual(calendarDisplayOptionsProvider, (
      AsyncValue<CalendarDisplayOptions>? previous,
      AsyncValue<CalendarDisplayOptions> next,
    ) {
      final options = next.asData?.value;
      if (options == null) {
        return;
      }
      subscription.close();
      final format = _controller.formatFor(options.initialFormat);
      if (format != _calendarFormat) {
        applyState(() => _calendarFormat = format);
      }
    });
  }

  /// 当前生效的显示选项。
  CalendarDisplayOptions get _displayOptions =>
      ref.read(calendarDisplayOptionsProvider).asData?.value ??
      _fallbackOptions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final headerHeight =
        MediaQuery.paddingOf(context).top + CalendarHeader.contentHeight;
    final now = DateTime.now();
    final focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month);
    final options =
        ref.watch(calendarDisplayOptionsProvider).asData?.value ??
        _fallbackOptions;
    // 年视图读整年打点，月/周视图读当月；两者共用逐日汇总缓存。
    final markersAsync = _yearMode
        ? ref.watch(calendarYearMarkersProvider(_focusedMonth.year))
        : ref.watch(calendarMonthMarkersProvider(focusedMonth));
    final moodOptions =
        ref.watch(moodOptionsProvider).asData?.value ??
        SettingsService.defaultMoodOptions;
    final summaries = _resolveDaySummaries(
      markersAsync.asData?.value,
      moodOptions: moodOptions,
      now: now,
    );
    // 照片样式才订阅正文首图；翻月加载期间沿用上一份，照片不会先消失再出现。
    if (!_yearMode && options.cellStyle == CalendarCellStyle.photo) {
      final images = ref
          .watch(calendarMonthInlineImagesProvider(focusedMonth))
          .asData
          ?.value;
      if (images != null) {
        _cachedInlineImages = images;
      }
    }
    final day = _resolveDayContent(
      ref.watch(calendarDayDiariesProvider(_selectedDay)),
      fallbackSummary: summaries[_selectedDay],
      now: now,
    );
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
                        options: options,
                        summaries: summaries,
                        markersAsync: markersAsync,
                        moodOptions: moodOptions,
                        now: now,
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
                      child: CalendarDayHeading(
                        day: _selectedDay,
                        now: now,
                        entryCount: day.entryCount,
                        charCount: day.charCount,
                      ),
                    ),
                  ),
                  ..._buildDayDiaryContentSlivers(day, options),
                  if (options.showOnThisDay) _buildOnThisDaySliver(now),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: _listBottomExtraSpace),
                  ),
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
            onPickDate: _controller.onTitlePressed,
            onOpenDisplayOptions: () =>
                unawaited(_controller.openDisplayOptions()),
            titleTooltip: _yearMode
                ? l10n.autoT0177
                : l10n.calendarYearViewTooltip,
            previousTooltip: _yearMode ? l10n.calendarPreviousYear : null,
            nextTooltip: _yearMode ? l10n.calendarNextYear : null,
          ),
          // 导出只能在年视图发起：遮罩只在年视图挂载，月/周视图不多挂一个
          // 常驻的加载指示器。
          if (_yearMode)
            Positioned.fill(
              child: ActionLoadingOverlay(
                visible: _exportingYear,
                label: l10n.autoT0114,
                revealDelay: const Duration(milliseconds: 300),
              ),
            ),
        ],
      ),
    );
  }

  /// 打点按日聚合。选日、切换月/周格式等 setState 都会重建页面；打点列表与
  /// 心情配置引用未变时复用上次结果，只在 provider 推送新值时重新聚合。
  ///
  /// Riverpod emits loading/error while switching month streams. Keep the last
  /// successful summaries visible so month navigation does not read as data
  /// loss.
  Map<DateTime, CalendarDaySummary> _resolveDaySummaries(
    List<DiaryCalendarMarker>? markers, {
    required List<String> moodOptions,
    required DateTime now,
  }) {
    if (markers == null) {
      return _cachedDaySummaries;
    }
    if (identical(markers, _summarizedMarkersSource) &&
        identical(moodOptions, _summarizedMoodOptions)) {
      return _cachedDaySummaries;
    }
    _summarizedMarkersSource = markers;
    _summarizedMoodOptions = moodOptions;
    _cachedDaySummaries = CalendarDaySummary.groupByDay(
      markers,
      now: now,
      moodOptions: moodOptions,
    );
    return _cachedDaySummaries;
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

  /// 统一的状态提交入口：网格格式在任何路径下（手势、回到今天、翻月、
  /// 选择日期）发生变化时，都交给控制器按“上次的视图”选项记录。
  void applyState(VoidCallback mutate) {
    if (!mounted) {
      return;
    }
    final previousFormat = _calendarFormat;
    setState(mutate);
    if (_calendarFormat != previousFormat) {
      _controller.rememberFormat(_calendarFormat);
    }
  }
}

enum _CalendarCreateDraftDecision { newEmpty, continueEditing }
