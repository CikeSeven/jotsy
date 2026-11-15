// 快照里与日记内容有关的三节：`diaries`（日记 id → 标题、摘要、日期、心情与照片），
// `onThisDay`（逐日的那年今日，按匹配口径各一列 id）与 `recent`（最近日记，按来源键
// 各一列 id）。后两节只存 id，同一篇日记在几处出现时内容只写一份。
//
// 隐私：日记都来自已排除私密日记的查询（日历的那年今日查询、首页列表查询）；未到期的
// 胶囊在这里再排除一次（日历查询含胶囊）。应用锁开着时快照构建根本不调用这里
// （见 `HomeWidgetSnapshotBuilder`），标题、正文与照片路径一概不进快照。
//
// 那年今日的选取与探索页同一规则（`ExplorePageController.pickOnThisDayList`：同月同日 /
// 前后 3 天 / 同月，年份早于那一天，最近的年份在前，最多 12 篇），逐日预算
// [kHomeWidgetDayHorizon] 天，原生按本机日期取那一天；标签（“3 年前的今天”或日期）
// 也随那一天算好。

import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/providers/calendar_diary_providers.dart'
    show calendarOnThisDayYearSpan;
import '../../diaries/models/time_capsule.dart';
import '../../explore/controllers/explore_content_extractor.dart';
import '../../explore/controllers/explore_page_controller.dart';
import '../../explore/models/explore_module_options.dart';
import 'home_widget_today_section.dart';

/// 那年今日每天每种口径最多几篇（与探索页的默认条数一致）。
const int kHomeWidgetOnThisDayLimit = 12;

/// 最近日记每个来源取几篇：4×4 也只放得下五六行。
const int kHomeWidgetRecentLimit = 8;

/// 摘要最多多少字（按字素）：小组件最多显示三四行。
const int _excerptLength = 140;

const ExploreContentExtractor _extractor = ExploreContentExtractor();

/// 那年今日要查的发表时间区间：今天起 [kHomeWidgetDayHorizon] 天、各种用到的口径、
/// 往前 [calendarOnThisDayYearSpan] 年，合并成互不重叠的几段（查询只要是超集，
/// 是否匹配由 [buildHomeWidgetOnThisDaySection] 按探索页的规则逐篇判断）。
List<(DateTime, DateTime)> homeWidgetOnThisDayRanges(
  DateTime now,
  Set<OnThisDayMatch> matches,
) {
  if (matches.isEmpty) return const <(DateTime, DateTime)>[];
  final ranges = <(DateTime, DateTime)>[];
  for (var offset = 0; offset < kHomeWidgetDayHorizon; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    for (
      var year = day.year - calendarOnThisDayYearSpan;
      year < day.year;
      year++
    ) {
      for (final match in matches) {
        ranges.add(switch (match) {
          OnThisDayMatch.sameDay => (
            DateTime(year, day.month, day.day),
            DateTime(year, day.month, day.day + 1),
          ),
          OnThisDayMatch.nearby => (
            DateTime(year, day.month, day.day - 3),
            DateTime(year, day.month, day.day + 4),
          ),
          OnThisDayMatch.sameMonth => (
            DateTime(year, day.month),
            DateTime(year, day.month + 1),
          ),
        });
      }
    }
  }
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(DateTime, DateTime)>[];
  for (final range in ranges) {
    if (merged.isNotEmpty && !range.$1.isAfter(merged.last.$2)) {
      final last = merged.removeLast();
      merged.add((last.$1, range.$2.isAfter(last.$2) ? range.$2 : last.$2));
    } else {
      merged.add(range);
    }
  }
  return merged;
}

/// 快照 `diaries` 一节的收集器：各节登记要用的日记，最后一次写出。
class HomeWidgetDiaryCollector {
  HomeWidgetDiaryCollector({
    required this.l10n,
    required this.now,
    required this.localImage,
  });

  final AppLocalizations l10n;
  final DateTime now;

  /// 图片来源 → 本机文件（见 `HomeWidgetDataSource.localImage`）。
  final String? Function(String source) localImage;

  final Map<String, Map<String, Object?>> _entries =
      <String, Map<String, Object?>>{};

  /// 未到期的胶囊：内容还不能看，整篇不进快照。
  bool isHidden(Diary diary) => TimeCapsuleState.fromFields(
    lockedAt: diary.capsuleLockedAt,
    unlockAt: diary.capsuleUnlockAt,
    now: now,
  ).isLocked;

  /// 登记一篇日记，返回它的 id。
  String add(Diary diary) {
    _entries.putIfAbsent(diary.diaryId, () => _entry(diary));
    return diary.diaryId;
  }

  Map<String, Object?> _entry(Diary diary) {
    final created = diary.createdAt.toLocal();
    final excerpt = _extractor
        .summaryFromText(diary.contentText, emptyFallback: '')
        .characters
        .take(_excerptLength)
        .toString();
    final mood = _extractor.parseContext(diary.metadata)?['moodEmoji'];
    String? photo;
    for (final source in _extractor.resolveMediaSources(diary)) {
      photo = localImage(source);
      if (photo != null) break;
    }
    return <String, Object?>{
      'title': diary.title.trim(),
      if (excerpt.isNotEmpty) 'excerpt': excerpt,
      'created': homeWidgetDayKey(created),
      // 行首日期块：日与月（“15” / “11月”），以及完整日期（往年的那年今日）。
      'day': created.day,
      'month': DateFormat.MMM(l10n.localeName).format(created),
      'monthDay': l10n.formatMonthDay(created),
      'date': l10n.formatFullDate(created),
      if (mood is String && mood.trim().isNotEmpty) 'mood': mood.trim(),
      'photo': ?photo,
    };
  }

  Map<String, Object?> toJson() => Map<String, Object?>.of(_entries);
}

/// 快照的「那年今日」一节：`days` 为日期键 → 口径 → `[{id, label}]`。
Map<String, Object?> buildHomeWidgetOnThisDaySection({
  required DateTime now,
  required AppLocalizations l10n,
  required List<DiaryWithTags> rows,
  required Set<OnThisDayMatch> matches,
  required HomeWidgetDiaryCollector diaries,
}) {
  final visible = <String, Diary>{
    for (final row in rows)
      if (!diaries.isHidden(row.diary)) row.diary.diaryId: row.diary,
  };
  final overviews = <ExploreDiaryOverview>[
    for (final row in rows)
      if (visible.containsKey(row.diary.diaryId))
        ExploreDiaryOverview(
          diaryId: row.diary.diaryId,
          title: row.diary.title,
          contentText: row.diary.contentText,
          metadata: row.diary.metadata,
          createdAt: row.diary.createdAt,
          updatedAt: row.diary.updatedAt,
          tags: row.tags,
          cover: row.diary.cover,
        ),
  ];
  const picker = ExplorePageController();
  final days = <String, Object?>{};
  for (var offset = 0; offset < kHomeWidgetDayHorizon; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    days[homeWidgetDayKey(day)] = <String, Object?>{
      for (final match in matches)
        match.name: <Object?>[
          for (final item in picker.pickOnThisDayList(
            overviews,
            now: day,
            l10n: l10n,
            match: _exploreMatch(match),
            limit: kHomeWidgetOnThisDayLimit,
          ))
            <String, Object?>{
              'id': diaries.add(visible[item.diaryId]!),
              'label': item.timeLabel,
            },
        ],
    };
  }
  return <String, Object?>{'days': days};
}

ExploreOnThisDayMatch _exploreMatch(OnThisDayMatch match) => switch (match) {
  OnThisDayMatch.sameDay => ExploreOnThisDayMatch.sameDay,
  OnThisDayMatch.nearby => ExploreOnThisDayMatch.nearby,
  OnThisDayMatch.sameMonth => ExploreOnThisDayMatch.sameMonth,
};

/// 一个来源的最近日记（id 列表，从新到旧）。
List<Object?> buildHomeWidgetRecentList(
  List<DiaryWithTags> rows,
  HomeWidgetDiaryCollector diaries,
) => <Object?>[
  for (final row in rows)
    if (!diaries.isHidden(row.diary)) diaries.add(row.diary),
];
