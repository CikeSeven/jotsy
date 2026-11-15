// 桌面小组件的快照：原生绘制所需的一切，一份 JSON（docs/rules/home_widgets.md
// 「快照」有逐字段说明）。
//
// 输入：当前时刻、界面语言、主题色、功能开关、应用锁、小组件设置与桌面上的
// 实例，加上经 [HomeWidgetDataSource] 读到的数据。输出：可直接 jsonEncode 的
// Map。无副作用。
//
// 各数据节只为用得到的种类计算（[HomeWidgetSnapshotInput.kinds]）：桌面上
// 有的，加上小组件页打开期间要预览的全部种类。快照不含构建时刻以外的
// 易变字段，同样的输入得到同样的 JSON，调用方据此跳过没有变化的写入
// （`HomeWidgetSyncController`）。
//
// 应用锁开着时（[HomeWidgetSnapshotInput.appLocked]）涉及日记内容的三节
// （`diaries`、`onThisDay`、`recent`）一概不算、不写，原生按 `redacted` 显示锁定占位。

import 'package:flutter/painting.dart' show Color;
import 'package:intl/date_symbol_data_local.dart';

import '../../../core/database/app_database.dart' show DayMood;
import '../../../core/services/app_features.dart';
import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../core/services/home_widgets/home_widget_gateway.dart';
import '../../../core/services/home_widgets/home_widget_kind.dart';
import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/models/calendar_display_options.dart';
import 'home_widget_anniversary_section.dart';
import 'home_widget_data_source.dart';
import 'home_widget_diary_sections.dart';
import 'home_widget_month_section.dart';
import 'home_widget_native_config.dart';
import 'home_widget_palette.dart';
import 'home_widget_plurals.dart';
import 'home_widget_snapshot_strings.dart';
import 'home_widget_today_section.dart';
import 'home_widget_todos_section.dart';

/// 快照格式版本；原生遇到更高的版本时仍按认得的字段尽量绘制。
const int kHomeWidgetSnapshotVersion = 1;

/// 应用自带的展示字体（大数字与日期用），原生经 `FontManifest.json` 取用。
const String kHomeWidgetDisplayFont = 'HarmonyOSSansSC';

class HomeWidgetSnapshotInput {
  const HomeWidgetSnapshotInput({
    required this.now,
    required this.l10n,
    required this.appSeed,
    required this.features,
    required this.appLocked,
    required this.settings,
    required this.installed,
    required this.kinds,
    this.moodOptions = const <String>[],
    this.weekStart = CalendarWeekStart.locale,
    this.previewContents = const <HomeWidgetContent>[],
  });

  final DateTime now;
  final AppLocalizations l10n;
  final Color appSeed;
  final AppFeatures features;

  /// 开启了应用锁：涉及日记标题、正文与照片的内容不进快照，原生显示锁定
  /// 占位（docs/rules/home_widgets.md「隐私」）。
  final bool appLocked;

  final HomeWidgetSettings settings;
  final List<InstalledHomeWidget> installed;

  /// 要计算数据节的种类。
  final Set<HomeWidgetKind> kinds;

  /// 日记心情的十档符号（心情月历把当天日记的平均心情折成五段）。
  final List<String> moodOptions;

  /// 日历设置里一周从哪天开始（心情月历与日历页一致）。
  final CalendarWeekStart weekStart;

  /// 工作室里正在编辑、还没放到桌面上的内容：预览要画出它选的来源与口径
  /// （最近日记的某个日记本、那年今日的同月等），数据节一并算上。
  final List<HomeWidgetContent> previewContents;

  /// 桌面上的实例、待领取的设计与工作室草稿的全部内容。
  Iterable<HomeWidgetContent> get usedContents sync* {
    for (final widget in installed) {
      yield settings.instanceFor(widget.widgetId, widget.kind).content;
    }
    for (final pin in settings.pending) {
      yield pin.instance.content;
    }
    yield* previewContents;
  }
}

class HomeWidgetSnapshotBuilder {
  const HomeWidgetSnapshotBuilder(this.data);

  final HomeWidgetDataSource data;

  Future<Map<String, Object?>> build(HomeWidgetSnapshotInput input) async {
    final l10n = input.l10n;
    // 星期、月份按界面语言格式化（intl）。应用里 MaterialApp 的本地化已加载过
    // 这份数据，后台 isolate 里没有：自己加载一次（已加载时立即返回）。
    await initializeDateFormatting(l10n.localeName);
    final needsWritable =
        input.kinds.contains(HomeWidgetKind.quickCapture) ||
        input.kinds.contains(HomeWidgetKind.recentDiaries);
    final needsRecent = input.kinds.contains(HomeWidgetKind.recentDiaries);
    final nativeContext = HomeWidgetNativeContext(
      features: input.features,
      languageCode: l10n.localeName,
      writableNotebooks: needsWritable
          ? await data.writableNotebooks()
          : const <String, String>{},
      readableNotebooks: needsRecent
          ? await data.readableNotebooks()
          : const <String, String>{},
      tagNames: needsRecent ? await data.tagNames() : const <String>{},
    );
    final instances = <String, Object?>{};
    final styles = [
      for (final widget in input.installed)
        input.settings.instanceFor(widget.widgetId, widget.kind).style,
      for (final pin in input.settings.pending) pin.instance.style,
    ];
    for (final widget in input.installed) {
      instances['${widget.widgetId}'] = homeWidgetNativeConfig(
        input.settings.instanceFor(widget.widgetId, widget.kind),
        nativeContext,
      );
    }
    final kinds = input.kinds;
    final needsMoods =
        kinds.contains(HomeWidgetKind.today) ||
        kinds.contains(HomeWidgetKind.moodCalendar);
    final dayMoods = needsMoods
        ? await data.dayMoods()
        : const <String, DayMood>{};
    final diarySections = input.appLocked
        ? const <String, Object?>{}
        : await _diarySections(input, nativeContext);
    return <String, Object?>{
      'v': kHomeWidgetSnapshotVersion,
      'locale': l10n.localeName,
      'redacted': input.appLocked,
      'displayFont': kHomeWidgetDisplayFont,
      'palettes': homeWidgetPalettesFor(input.appSeed, styles),
      'strings': homeWidgetStringsOf(l10n),
      'plurals': homeWidgetPluralsOf(l10n),
      'icons': homeWidgetIcons(),
      'instances': instances,
      'defaults': <String, Object?>{
        for (final kind in HomeWidgetKind.values)
          kind.id: homeWidgetNativeConfig(
            HomeWidgetInstance.defaultsFor(kind),
            nativeContext,
          ),
      },
      // 快速记录的眉标日期也取这一节（逐日预算的日期文字）。
      if (kinds.contains(HomeWidgetKind.today) ||
          kinds.contains(HomeWidgetKind.quickCapture))
        'today': buildHomeWidgetTodaySection(
          now: input.now,
          l10n: l10n,
          todoDueDates: input.features.todos
              ? await data.openTodoDueDates()
              : const <String?>[],
          todayWords: await data.wordsOn(input.now),
          dayMoods: dayMoods,
        ),
      if (kinds.contains(HomeWidgetKind.anniversary) &&
          input.features.anniversariesEnabled)
        'anniversaries': buildHomeWidgetAnniversaries(
          now: input.now,
          l10n: l10n,
          rows: await data.anniversaries(),
        ),
      if (kinds.contains(HomeWidgetKind.todos) && input.features.todos)
        'todos': buildHomeWidgetTodosSection(
          now: input.now,
          l10n: l10n,
          open: await data.openTodos(),
          completed: await data.completedTodos(),
          lists: await data.todoLists(),
        ),
      if (kinds.contains(HomeWidgetKind.moodCalendar) &&
          input.features.calendar)
        'calendar': buildHomeWidgetMonthSection(
          now: input.now,
          l10n: l10n,
          markers: await data.markersBetween(
            homeWidgetMonthRange(input.now).$1,
            homeWidgetMonthRange(input.now).$2,
          ),
          dayMoods: dayMoods,
          moodOptions: input.moodOptions,
          weekStart: input.weekStart,
        ),
      ...diarySections,
    };
  }

  /// `diaries`、`onThisDay` 与 `recent` 三节（见 home_widget_diary_sections.dart）：
  /// 那年今日算桌面上与草稿里用到的口径（加上默认的同月同日，组件库与刚放下的实例
  /// 用它），最近日记算用到的来源（加上默认的全部日记）。
  Future<Map<String, Object?>> _diarySections(
    HomeWidgetSnapshotInput input,
    HomeWidgetNativeContext nativeContext,
  ) async {
    final onThisDay = input.kinds.contains(HomeWidgetKind.onThisDay);
    final recent = input.kinds.contains(HomeWidgetKind.recentDiaries);
    if (!onThisDay && !recent) return const <String, Object?>{};
    final diaries = HomeWidgetDiaryCollector(
      l10n: input.l10n,
      now: input.now,
      localImage: data.localImage,
    );
    final result = <String, Object?>{};
    if (onThisDay) {
      final matches = <OnThisDayMatch>{
        OnThisDayContent.defaults.match,
        for (final content in input.usedContents)
          if (content is OnThisDayContent) content.match,
      };
      result['onThisDay'] = buildHomeWidgetOnThisDaySection(
        now: input.now,
        l10n: input.l10n,
        rows: await data.diariesCreatedInRanges(
          homeWidgetOnThisDayRanges(input.now, matches),
        ),
        matches: matches,
        diaries: diaries,
      );
    }
    if (recent) {
      final sources = <String, RecentDiariesContent>{
        'all': RecentDiariesContent.defaults,
        for (final content in input.usedContents)
          if (content is RecentDiariesContent)
            homeWidgetRecentSourceKey(content, nativeContext): content,
      };
      final lists = <String, Object?>{};
      for (final MapEntry(:key, value: content) in sources.entries) {
        final source = switch (key) {
          'all' => RecentDiariesSource.all,
          'pinned' => RecentDiariesSource.pinned,
          _ => content.source,
        };
        lists[key] = buildHomeWidgetRecentList(
          await data.recentDiaries(
            source,
            notebookId: content.notebookId,
            tagName: content.tagName,
            now: input.now,
            limit: kHomeWidgetRecentLimit,
          ),
          diaries,
        );
      }
      result['recent'] = lists;
    }
    result['diaries'] = diaries.toJson();
    return result;
  }
}
