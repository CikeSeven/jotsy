import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import 'explore_content_extractor.dart';
import '../models/explore_module_options.dart';
import '../models/explore_view_data.dart';

/// 探索页与日记本统计页共用的两条规则：“那年今日”的选取与标签频次。
///
/// 其余探索页聚合见 `ExploreDataBuilder`；这里不负责 Widget 构建与导航。
class ExplorePageController {
  const ExplorePageController();

  final ExploreContentExtractor contentExtractor =
      const ExploreContentExtractor();
  static const int _onThisDayMaxEntries = 12;

  /// 选择“那年今日”候选列表（日记本统计页对本子里的日记复用同一规则）：
  /// - [match] 为同月同日（默认）、前后 3 天内，或同月；
  /// - 年份早于当前年；
  /// - 按创建时间倒序，最近年份优先；
  /// - 最多 [limit] 条（默认 12），避免轮播过长影响浏览体验。
  List<ExploreOnThisDayItem> pickOnThisDayList(
    List<ExploreDiaryOverview> diaries, {
    required DateTime now,
    required AppLocalizations l10n,
    ExploreOnThisDayMatch match = ExploreOnThisDayMatch.sameDay,
    int limit = _onThisDayMaxEntries,
  }) {
    final today = DateTime.utc(now.year, now.month, now.day);
    bool matches(DateTime created) {
      if (created.year >= now.year) return false;
      return switch (match) {
        ExploreOnThisDayMatch.sameDay =>
          created.month == now.month && created.day == now.day,
        ExploreOnThisDayMatch.sameMonth => created.month == now.month,
        // 把那天挪到今年再比：跨年（12/30 与 1/2）按相邻处理，2 月 29 日在
        // 平年落到 3 月 1 日。
        ExploreOnThisDayMatch.nearby => () {
          var shifted = DateTime.utc(now.year, created.month, created.day);
          var diff = shifted.difference(today).inDays;
          if (diff > 182) {
            shifted = DateTime.utc(now.year - 1, created.month, created.day);
            diff = shifted.difference(today).inDays;
          } else if (diff < -182) {
            shifted = DateTime.utc(now.year + 1, created.month, created.day);
            diff = shifted.difference(today).inDays;
          }
          return diff.abs() <= 3;
        }(),
      };
    }

    final candidates =
        diaries.where((item) => matches(item.createdAt.toLocal())).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return candidates
        .take(limit)
        .map(
          (item) => ExploreOnThisDayItem(
            diaryId: item.diaryId,
            title: item.title,
            summaryText: contentExtractor.summaryFromText(
              item.contentText,
              emptyFallback: l10n.autoT0186,
            ),
            mediaSource: contentExtractor.resolveOverviewMediaSource(item),
            timeLabel: _buildOnThisDayLabel(
              item.createdAt,
              now: now,
              l10n: l10n,
            ),
          ),
        )
        .toList(growable: false);
  }

  /// 生成“那年今日”卡片时间标签。
  ///
  /// 同月同日写“X年前的今天”；其余（前后几天、同月）写具体日期。
  String _buildOnThisDayLabel(
    DateTime createdAt, {
    required DateTime now,
    required AppLocalizations l10n,
  }) {
    final localCreated = createdAt.toLocal();
    final yearDiff = now.year - localCreated.year;
    if (yearDiff > 0 &&
        localCreated.month == now.month &&
        localCreated.day == now.day) {
      return l10n.exploreOnThisDayYearsAgo(yearDiff);
    }
    return l10n.formatFullDate(localCreated);
  }

  /// 标签频次统计 + 最近关联日记定位（日记本统计页复用后再按次数取前几个）。
  ///
  /// 排序策略：
  /// - 优先遵循用户在“标签管理”中配置的顺序；
  /// - 若存在未命中顺序表的标签，则放在后面并按名称升序兜底。
  List<ExploreTagUsage> buildTagUsages(
    List<ExploreDiaryOverview> diaries, {
    required List<int> orderedTagIds,
  }) {
    // 每个标签只保留一个可变计数器，最终才生成展示模型。全库统计可能有
    // 数万条关系，逐条 copyWith 会制造同等数量的短命对象并触发 GC。
    final tagMap = <int, _TagUsageAccumulator>{};
    for (final item in diaries) {
      for (final tag in item.tags) {
        final previous = tagMap[tag.id];
        if (previous == null) {
          tagMap[tag.id] = _TagUsageAccumulator(tag, item);
          continue;
        }
        previous.add(item);
      }
    }

    final orderRank = <int, int>{
      for (int i = 0; i < orderedTagIds.length; i++) orderedTagIds[i]: i,
    };
    final usages = tagMap.values.toList(growable: false)
      ..sort((a, b) {
        final rankA = orderRank[a.tag.id] ?? 1 << 20;
        final rankB = orderRank[b.tag.id] ?? 1 << 20;
        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }
        return a.tag.name.compareTo(b.tag.name);
      });
    final maxCount = usages.isEmpty
        ? 1
        : usages.fold<int>(
            1,
            (currentMax, item) =>
                item.count > currentMax ? item.count : currentMax,
          );
    return usages
        .map(
          (item) => ExploreTagUsage(
            id: item.tag.id,
            name: item.tag.name,
            color: item.tag.color,
            count: item.count,
            latestDiaryId: item.latestDiaryId,
            latestAt: item.latestAt,
            maxCount: maxCount,
          ),
        )
        .toList(growable: false);
  }
}

class _TagUsageAccumulator {
  _TagUsageAccumulator(this.tag, ExploreDiaryOverview diary)
    : latestDiaryId = diary.diaryId,
      latestAt = diary.updatedAt;

  final Tag tag;
  int count = 1;
  String latestDiaryId;
  DateTime latestAt;

  void add(ExploreDiaryOverview diary) {
    count += 1;
    if (diary.updatedAt.isAfter(latestAt)) {
      latestDiaryId = diary.diaryId;
      latestAt = diary.updatedAt;
    }
  }
}
