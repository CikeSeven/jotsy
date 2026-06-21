/// 探索页聚合后的只读视图模型。
///
/// 作用：
/// - 将“统计/趋势/回顾”数据统一收敛为页面可直接消费的数据结构；
/// - 避免页面层重复进行 JSON 解析与集合聚合；
/// - 让 UI 组件只关心渲染，不关心计算过程。
class ExploreViewData {
  const ExploreViewData({
    required this.stats,
    required this.onThisDayDiaries,
    required this.fallbackPrompt,
    required this.moodWeights30,
    required this.energyValues7,
    required this.tagUsages,
    required this.mediaItems,
  });

  final ExploreStats stats;
  final List<ExploreOnThisDayItem> onThisDayDiaries;
  final String fallbackPrompt;
  final List<double?> moodWeights30;
  final List<double?> energyValues7;
  final List<ExploreTagUsage> tagUsages;
  final List<ExploreMediaItem> mediaItems;
}

/// “那年今日”轮播项。
///
/// 回忆卡只需要轻量字段，不再持有完整 `DiaryWithTags`，避免探索页为了
/// 卡片摘要和图片预览加载富文本 Delta 正文。
class ExploreOnThisDayItem {
  const ExploreOnThisDayItem({
    required this.diaryId,
    required this.title,
    required this.summaryText,
    required this.timeLabel,
    this.mediaSource,
  });

  final String diaryId;
  final String title;
  final String summaryText;
  final String timeLabel;
  final String? mediaSource;
}

/// 顶部轻量看板数据。
class ExploreStats {
  const ExploreStats({
    required this.totalRecords,
    required this.streakDays,
    required this.currentMonthChars,
  });

  final int totalRecords;
  final int streakDays;
  final int currentMonthChars;
}

/// 标签云展示项。
class ExploreTagUsage {
  const ExploreTagUsage({
    required this.id,
    required this.name,
    required this.color,
    required this.count,
    required this.latestDiaryId,
    required this.latestAt,
    required this.maxCount,
  });

  final int id;
  final String name;
  final int color;
  final int count;
  final String latestDiaryId;
  final DateTime latestAt;
  final int maxCount;

  ExploreTagUsage copyWith({
    int? count,
    String? latestDiaryId,
    DateTime? latestAt,
    int? maxCount,
  }) {
    return ExploreTagUsage(
      id: id,
      name: name,
      color: color,
      count: count ?? this.count,
      latestDiaryId: latestDiaryId ?? this.latestDiaryId,
      latestAt: latestAt ?? this.latestAt,
      maxCount: maxCount ?? this.maxCount,
    );
  }
}

/// 媒体画廊项。
class ExploreMediaItem {
  const ExploreMediaItem({
    required this.source,
    required this.diaryId,
    required this.updatedAt,
  });

  final String source;
  final String diaryId;
  final DateTime updatedAt;
}
