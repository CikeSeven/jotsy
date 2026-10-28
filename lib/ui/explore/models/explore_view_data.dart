// 探索页与日记本统计页共用的展示项（各卡片的聚合数据见
// `explore_module_data.dart`）。

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
  const ExploreMediaItem({required this.source, required this.diaryId});

  final String source;
  final String diaryId;
}
