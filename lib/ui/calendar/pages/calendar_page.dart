import 'dart:async';
import 'dart:math' as math;
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

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/desktop_save_service.dart';
import '../../../core/services/settings_service.dart';
import '../../anniversaries/controllers/anniversary_navigation.dart';
import '../../anniversaries/models/anniversary_draft.dart';
import '../../anniversaries/providers/anniversary_providers.dart';
import '../../anniversaries/widgets/anniversary_linked_diary_button.dart';
import '../../anniversaries/viewmodels/anniversary_calendar_index.dart';
import '../../diaries/providers/diary_card_style_provider.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/controllers/diary_create_entry_flow.dart';
import '../../../utils/text_stats.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../notebooks/controllers/notebook_quick_create_flows.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../settings/providers/app_features_provider.dart';
import '../models/calendar_display_options.dart';
import '../models/calendar_marker_filter.dart';
import '../models/calendar_range_selection.dart';
import '../providers/calendar_diary_providers.dart';
import '../providers/calendar_display_options_provider.dart';
import '../providers/day_mood_providers.dart';
import '../viewmodels/calendar_day_summary.dart';
import '../viewmodels/calendar_holiday_day.dart';
import '../viewmodels/calendar_lunar_day.dart';
import '../viewmodels/calendar_month_stats.dart';
import '../widgets/calendar_anniversary_section.dart';
import '../widgets/calendar_day_actions_sheet.dart';
import '../widgets/calendar_day_cards_sliver.dart';
import '../widgets/calendar_day_content_switcher.dart';
import '../widgets/calendar_day_empty_state.dart';
import '../widgets/calendar_day_heading.dart';
import '../widgets/calendar_display_options_sheet.dart';
import '../widgets/calendar_filter_bar.dart';
import '../widgets/calendar_filter_sheet.dart';
import '../widgets/calendar_header.dart';
import '../widgets/calendar_header_sliver.dart';
import '../widgets/calendar_month_grid.dart';
import '../widgets/calendar_month_summary.dart';
import '../widgets/calendar_on_this_day_strip.dart';
import '../widgets/calendar_range_header.dart';
import '../widgets/calendar_refresh_capsule.dart';
import '../widgets/calendar_year_view.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/image_viewer_hero.dart';
import '../widgets/calendar_timeline_section.dart';
import '../../../app/theme/app_effects.dart';

part 'calendar_page_sections.dart';
part 'calendar_page_range.dart';
part 'calendar_page_anniversaries.dart';
part 'calendar_page_layout.dart';
part '../controllers/calendar_anniversary_actions.dart';
part '../controllers/calendar_page_controller.dart';
part '../controllers/calendar_create_actions.dart';
part '../controllers/calendar_display_options_actions.dart';
part '../controllers/calendar_year_actions.dart';
part '../controllers/calendar_range_actions.dart';
part '../controllers/calendar_filter_actions.dart';
part '../controllers/calendar_day_mood_actions.dart';

/// 日历页（上历下表）。
///
/// 页面职责（只做装配）：
/// - 组合页头（固定在顶部，下滑时月份行收起、只留标题栏）、日历卡片（月/周
///   网格或年视图 + 概览）、选中日标题、当天日记（时间线或卡片）与那年
///   今日；区块构建见 calendar_page_sections.dart；
/// - 监听打点/当日日记/心情配置/这天的心情/显示选项，翻月期间保留上一份
///   数据；
/// - 不注册 Home 的“新建”FAB：在某天写日记走长按日期菜单或当天的空状态。
///
/// 日期格样式、月度统计等计算在 viewmodels/，网格与日期格绘制在 widgets/，
/// 选日/翻月/新建/显示选项保存/年视图导出等流程在 controllers/。
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key, this.pageBackgroundColor});

  final Color? pageBackgroundColor;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  static const double _calendarCardHorizontalPadding = AppSpacing.m;
  static const double _calendarCardTopPadding = AppSpacing.m;
  static const double _calendarBottomGap = AppSpacing.m;
  static const double _listBottomExtraSpace = 12;
  Map<DateTime, CalendarDaySummary> _cachedDaySummaries =
      const <DateTime, CalendarDaySummary>{};
  List<DiaryCalendarMarker>? _summarizedMarkersSource;
  List<String>? _summarizedMoodOptions;
  CalendarMarkerFilter? _summarizedFilter;
  Map<String, String> _cachedInlineImages = const <String, String>{};
  List<DiaryWithTags> _cachedDayDiaries = const <DiaryWithTags>[];
  DateTime? _cachedDayDiariesSelectedDay;
  List<DiaryWithTags> _cachedOnThisDay = const <DiaryWithTags>[];
  List<DiaryCalendarMarker> _cachedRangeMarkers = const <DiaryCalendarMarker>[];

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

  /// 正在选择的日期范围（选一段日期做统计）；null 为普通选日，见
  /// calendar_range_actions.dart。
  CalendarRangeSelection? _range;

  /// 按标签或心情筛选打点（临时状态，不写入设置），见
  /// calendar_filter_actions.dart。
  CalendarMarkerFilter _filter = const CalendarMarkerFilter();

  /// 年视图（点月份标题进入）；与月/周格式相互独立，退出后回到月视图。
  bool _yearMode = false;
  bool _exportingYear = false;

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
    // 玻璃底栏悬浮在内容之上（首页 Scaffold extendBody）时，这里的底部
    // padding 是底栏槽位高度：列表照常滚到胶囊下方，末尾多留这一段，最后
    // 一项才能完整滚到胶囊上方。实色底栏时 Scaffold 已扣掉，为 0。
    final floatingBarInset = MediaQuery.paddingOf(context).bottom;
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
    // 筛选里的标签可能已被删除：只按仍存在的标签过滤，筛选条也只列出
    // 它们，不残留看不见的条件。
    final filterTags = _filter.tagIds.isEmpty
        ? null
        : ref.watch(tagListProvider).asData?.value;
    // 日记本同理：删除、改成智能或设为私密后不再参与筛选。
    //
    // 日记本功能关闭时隐藏入口，数据保留：不订阅书架、不按日记本筛选，并把
    // 已选的日记本从页面筛选里去掉（筛选条、筛选面板与“有筛选”标记一致）。
    final notebooksEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.notebooks),
    );
    ref.listen<bool>(
      appFeaturesProvider.select((features) => features.notebooks),
      (_, bool enabled) {
        if (enabled) {
          return;
        }
        // 监听回调里不直接 setState，放到微任务里执行。
        scheduleMicrotask(() {
          if (_filter.notebookIds.isNotEmpty) {
            applyState(
              () => _filter = _filter.retainNotebooks(const <String>[]),
            );
          }
        });
      },
    );
    final allNotebooks = !notebooksEnabled
        ? const <NotebookView>[]
        : _filter.notebookIds.isEmpty
        ? null
        : ref.watch(notebooksProvider).asData?.value;
    final filterNotebooks = allNotebooks == null
        ? null
        : calendarFilterNotebooks(allNotebooks);
    var filter = filterTags == null
        ? _filter
        : _filter.retainTags(filterTags.map((Tag tag) => tag.id));
    if (filterNotebooks != null) {
      filter = filter.retainNotebooks(
        filterNotebooks.map((NotebookView notebook) => notebook.id),
      );
    }
    final summaries = _resolveDaySummaries(
      markersAsync.asData?.value,
      moodOptions: moodOptions,
      filter: filter,
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
    // 纪念日索引随列表整体重建；关闭显示时不订阅，网格与卡片都不画。
    // 纪念日功能关闭时隐藏入口，数据保留：同样不订阅，顶栏也不放纪念日按钮。
    final anniversariesEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.anniversariesEnabled),
    );
    final anniversaryIndex = options.showAnniversaries && anniversariesEnabled
        ? ref.watch(anniversaryCalendarIndexProvider)
        : AnniversaryCalendarIndex.empty;
    // 这天的心情与纪念日一样是日期本身的属性：整表订阅，不受筛选与范围选择
    // 影响；显示选项关掉时不订阅，网格与年视图都按没有心情绘制。
    final dayMoods = options.showDayMoods
        ? ref.watch(dayMoodsProvider).value ?? const <DateTime, DayMood>{}
        : const <DateTime, DayMood>{};
    final day = _resolveDayContent(
      ref.watch(calendarDayDiariesProvider(_selectedDay)),
      fallbackSummary: summaries[_selectedDay],
      now: now,
    );
    final pageBgColor =
        widget.pageBackgroundColor ?? Theme.of(context).colorScheme.surface;

    // 页头、日历卡片与选中日各区块在这里一次装配好，窄屏单列、宽屏居中
    // 单列与双栏只是摆放方式不同（见 calendar_page_layout.dart）。
    CalendarHeader buildHeader(
      double collapsedExtent,
      double horizontalInset, {
      bool showMonthBar = true,
    }) => CalendarHeader(
      title: _controller.focusedMonthTitle,
      month: _focusedMonth,
      onJumpToToday: _controller.jumpToToday,
      onPreviousMonth: _controller.goToPreviousMonth,
      onNextMonth: _controller.goToNextMonth,
      onPickDate: _controller.onTitlePressed,
      onOpenDisplayOptions: () => unawaited(_controller.openDisplayOptions()),
      onOpenFilter: () => unawaited(_controller.openFilter()),
      onOpenAnniversaries: anniversariesEnabled
          ? () => unawaited(openAnniversaryList(context))
          : null,
      filterActive: _filter.isActive,
      titleTooltip: _yearMode ? l10n.autoT0177 : l10n.calendarYearViewTooltip,
      previousTooltip: _yearMode ? l10n.calendarPreviousYear : null,
      nextTooltip: _yearMode ? l10n.calendarNextYear : null,
      collapsedExtent: collapsedExtent,
      horizontalInset: horizontalInset,
      showMonthBar: showMonthBar,
    );
    Widget buildPanel({required bool wide}) => _buildCalendarPanel(
      options: options,
      filter: filter,
      filterTags: filterTags ?? const <Tag>[],
      filterNotebooks: filterNotebooks ?? const <NotebookView>[],
      summaries: summaries,
      markersAsync: markersAsync,
      moodOptions: moodOptions,
      anniversaryIndex: anniversaryIndex,
      dayMoods: dayMoods,
      now: now,
      wide: wide,
    );
    final daySlivers = <Widget>[
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
            lunar:
                CalendarMonthGrid.showsLunar(options.lunarMode, l10n.localeName)
                ? CalendarLunarDay.of(_selectedDay)
                : null,
            holiday:
                CalendarMonthGrid.showsHolidays(
                  options.holidayMode,
                  l10n.localeName,
                )
                ? CalendarHolidayDay.of(_selectedDay)
                : null,
            entryCount: day.entryCount,
            wordCount: day.wordCount,
          ),
        ),
      ),
      _buildAnniversarySliver(anniversaryIndex, now),
      ..._buildDayDiaryContentSlivers(day, options),
      if (options.showOnThisDay) _buildOnThisDaySliver(now),
    ];

    return Scaffold(
      backgroundColor: pageBgColor,
      body: Stack(
        children: <Widget>[
          SafeArea(
            top: false,
            bottom: false,
            // 按页面实际可用宽度（宽窗口时已扣掉首页侧边导航栏）选布局。
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  _buildCalendarLayout(
                    width: constraints.maxWidth,
                    buildHeader: buildHeader,
                    buildPanel: buildPanel,
                    daySlivers: daySlivers,
                    bottomSpace: _listBottomExtraSpace + floatingBarInset,
                  ),
            ),
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

  /// 打点按日聚合。选日、切换月/周格式等 setState 都会重建页面；打点列表、
  /// 心情配置与筛选都未变时复用上次结果，只在 provider 推送新值或改筛选时
  /// 重新聚合。筛选在聚合前作用于打点，日期格与各类统计口径一致。
  ///
  /// Riverpod emits loading/error while switching month streams. Keep the last
  /// successful summaries visible so month navigation does not read as data
  /// loss.
  Map<DateTime, CalendarDaySummary> _resolveDaySummaries(
    List<DiaryCalendarMarker>? markers, {
    required List<String> moodOptions,
    required CalendarMarkerFilter filter,
    required DateTime now,
  }) {
    if (markers == null) {
      return _cachedDaySummaries;
    }
    if (identical(markers, _summarizedMarkersSource) &&
        identical(moodOptions, _summarizedMoodOptions) &&
        filter == _summarizedFilter) {
      return _cachedDaySummaries;
    }
    _summarizedMarkersSource = markers;
    _summarizedMoodOptions = moodOptions;
    _summarizedFilter = filter;
    _cachedDaySummaries = CalendarDaySummary.groupByDay(
      filter.apply(markers, now: now),
      now: now,
      moodOptions: moodOptions,
    );
    return _cachedDaySummaries;
  }

  /// 在选中日写日记（空状态与时间线里的“写日记”入口）。
  Future<void> _openCreateForSelectedDay() async {
    await _controller.openCreateEditorWithDraftPrompt();
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
