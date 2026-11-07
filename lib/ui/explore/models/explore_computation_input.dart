import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/explore_data_builder.dart';
import '../viewmodels/explore_entry.dart';
import 'explore_layout.dart';
import 'explore_module_data.dart';
import 'explore_module_id.dart';
import 'explore_period.dart';

/// 一次探索计算的不可变输入；只有概览流换实例才认为正文变化。
/// 不持有 BuildContext、provider 或数据库连接，可以交给 worker。
class ExploreComputationInput {
  const ExploreComputationInput({
    required this.diaries,
    required this.layout,
    required this.modules,
    required this.period,
    required this.now,
    required this.firstWeekday,
    required this.moodOptions,
    required this.l10n,
    this.orderedTagIds = const [],
    this.dayMoods,
    this.photoCounts,
  });

  final List<ExploreDiaryOverview> diaries;
  final ExploreLayout layout;
  final Set<ExploreModuleId> modules;
  final ExplorePeriod period;
  final DateTime now;
  final int firstWeekday;
  final List<String> moodOptions;
  final AppLocalizations l10n;
  final List<int> orderedTagIds;
  final Map<DateTime, DayMood>? dayMoods;
  final Map<String, int>? photoCounts;

  bool sameAs(ExploreComputationInput other) =>
      identical(diaries, other.diaries) &&
      layout == other.layout &&
      setEquals(modules, other.modules) &&
      period == other.period &&
      exploreDayKey(now) == exploreDayKey(other.now) &&
      firstWeekday == other.firstWeekday &&
      listEquals(moodOptions, other.moodOptions) &&
      l10n.localeName == other.l10n.localeName &&
      listEquals(orderedTagIds, other.orderedTagIds) &&
      identical(dayMoods, other.dayMoods) &&
      identical(photoCounts, other.photoCounts);

  /// 小库和设置预览同步完成，避免 isolate 启动开销；大库或单篇长文的解析、
  /// 字数和全卡聚合一起放到后台，不能只把 JSON 解析移走。
  bool get needsWorker {
    if (diaries.length >= 256) return true;
    var units = 0;
    for (final diary in diaries) {
      units += diary.contentText.length + diary.metadata.length;
      if (units >= 64 * 1024) return true;
    }
    return false;
  }

  ExploreData build(ExploreEntryCache cache) => ExploreDataBuilder.build(
    ExploreDataRequest(
      index: cache.index(diaries),
      layout: layout,
      modules: modules,
      period: period,
      now: now,
      firstWeekday: firstWeekday,
      moodOptions: moodOptions,
      l10n: l10n,
      orderedTagIds: orderedTagIds,
      dayMoods: dayMoods,
      photoCounts: photoCounts,
    ),
  );
}
