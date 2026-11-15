// 快照的「写作统计」一节：连续记录、本月与今年写了多少、最近 [kHomeWidgetHeatWeeks]
// 周每天的热力档位。
//
// 统计不是日记内容：应用锁开着也照常显示（docs/rules/home_widgets.md「隐私」）。日记
// 来自日历的打点查询（已排除私密日记；字数按 `TextStats` 口径），未到期的胶囊不算。
//
// 原生按本机日期取用，应用不在运行时日子照样过：
// - 连续天数给出到哪天为止（`streakEnd`），原生发现中间断了一天以上就显示 0；
// - 本月 / 今年的数字带着它们所属的月份与年份，换了月 / 年原生显示 0；
// - 热力档位从 `start` 起逐日一个字符（0–4），到构建当天为止，之后的日子原生画成空格。
//
// 档位与探索页热力图同一口径（`ExploreHeatmapCard.levelOf`）：篇数 1–4 篇封顶，字数按
// 200 / 600 / 1500 分档。

import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../explore/models/explore_module_data.dart';
import '../../explore/models/explore_module_options.dart';
import '../../explore/sections/explore_heatmap_card.dart';
import 'home_widget_today_section.dart';

/// 热力图最多几周（含本周）：4×4 横着放得下的上限，窄的版式由原生只画最近几周。
const int kHomeWidgetHeatWeeks = 53;

/// 热力图从哪天起：本周第一天往前推 [kHomeWidgetHeatWeeks] - 1 周。
DateTime homeWidgetHeatStart(DateTime now, int firstWeekday) {
  final offset = (now.weekday - firstWeekday + 7) % 7;
  return DateTime(
    now.year,
    now.month,
    now.day - offset - 7 * (kHomeWidgetHeatWeeks - 1),
  );
}

/// 统计要查的起点：热力图的起点与今年 1 月 1 日里较早的那个。
DateTime homeWidgetStatsStart(DateTime now, int firstWeekday) {
  final heat = homeWidgetHeatStart(now, firstWeekday);
  final year = DateTime(now.year);
  return heat.isBefore(year) ? heat : year;
}

/// 连续记录：从今天（今天还没写时从昨天）往前数连着写了几天，以及数到的最后一天
/// （连续的终点，今天或昨天）。没有连续时为 (0, null)。
(int, DateTime?) homeWidgetStreak(Set<String> writtenDays, DateTime now) {
  var probe = DateTime(now.year, now.month, now.day);
  if (!writtenDays.contains(homeWidgetDayKey(probe))) {
    probe = DateTime(probe.year, probe.month, probe.day - 1);
  }
  final end = probe;
  var streak = 0;
  while (writtenDays.contains(homeWidgetDayKey(probe))) {
    streak += 1;
    probe = DateTime(probe.year, probe.month, probe.day - 1);
  }
  return streak == 0 ? (0, null) : (streak, end);
}

Map<String, Object?> buildHomeWidgetStatsSection({
  required DateTime now,
  required AppLocalizations l10n,
  required List<DiaryCalendarMarker> markers,
  required int firstWeekday,
  required (int, DateTime?) streak,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final heatStart = homeWidgetHeatStart(now, firstWeekday);
  final days = <String, ({int entries, int words})>{};
  var monthEntries = 0;
  var monthWords = 0;
  var yearEntries = 0;
  for (final marker in markers) {
    if (_sealed(marker, now)) continue;
    final created = marker.createdAt.toLocal();
    final key = homeWidgetDayKey(created);
    final day = days[key];
    days[key] = (
      entries: (day?.entries ?? 0) + 1,
      words: (day?.words ?? 0) + marker.wordCount,
    );
    if (created.year == now.year) {
      yearEntries += 1;
      if (created.month == now.month) {
        monthEntries += 1;
        monthWords += marker.wordCount;
      }
    }
  }
  final entryLevels = StringBuffer();
  final wordLevels = StringBuffer();
  for (
    var day = heatStart;
    !day.isAfter(today);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    final counts = days[homeWidgetDayKey(day)];
    final heatDay = ExploreHeatDay(
      day: day,
      entries: counts?.entries ?? 0,
      words: counts?.words ?? 0,
      diaryIds: const <String>[],
    );
    entryLevels.write(
      ExploreHeatmapCard.levelOf(heatDay, ExploreHeatBasis.entries),
    );
    wordLevels.write(
      ExploreHeatmapCard.levelOf(heatDay, ExploreHeatBasis.words),
    );
  }
  final decimal = NumberFormat.decimalPattern(l10n.localeName);
  final (streakDays, streakEnd) = streak;
  return <String, Object?>{
    'streak': streakDays,
    if (streakEnd != null) 'streakEnd': homeWidgetDayKey(streakEnd),
    'month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
    'monthEntries': decimal.format(monthEntries),
    'monthWords': _words(monthWords, l10n.localeName),
    'year': now.year,
    'yearEntries': decimal.format(yearEntries),
    'heat': <String, Object?>{
      'start': homeWidgetDayKey(heatStart),
      'entries': entryLevels.toString(),
      'words': wordLevels.toString(),
    },
  };
}

/// 写下这些日记的日子（连续记录的输入），未到期的胶囊不算。
Set<String> homeWidgetWrittenDays(
  Iterable<DiaryCalendarMarker> markers,
  DateTime now,
) => <String>{
  for (final marker in markers)
    if (!_sealed(marker, now)) homeWidgetDayKey(marker.createdAt.toLocal()),
};

bool _sealed(DiaryCalendarMarker marker, DateTime now) {
  final unlockAt = marker.capsuleUnlockAt;
  return unlockAt != null && now.isBefore(unlockAt);
}

/// 字数：十万以内写全（带千分位），更多时用紧凑写法（“12万”“120K”），小组件的
/// 数字格放得下。
String _words(int words, String locale) => words < 100000
    ? NumberFormat.decimalPattern(locale).format(words)
    : NumberFormat.compact(locale: locale).format(words);
