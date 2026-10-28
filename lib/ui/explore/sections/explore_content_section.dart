import 'package:flutter/material.dart';

import '../controllers/explore_page_controller.dart';
import '../models/explore_view_data.dart';
import 'explore_insight_card.dart';
import 'explore_media_gallery_card.dart';
import 'explore_memory_card.dart';
import 'explore_stats_card.dart';
import 'explore_tag_cloud_card.dart';

/// 探索页模块组合区。
///
/// 页面只需传入聚合后的 `ExploreViewData` 与交互回调，组件负责组合模块顺序。
///
/// 可用宽度不小于 [twoUpMinWidth]（宽窗口里居中到 960 的内容列）时，“那年
/// 今日”与“心情洞察”两张高度相近的卡片并排，其余卡片仍整行：统计是一行
/// 三格、标签云是自动换行的标签、媒体画廊是横向缩略图队列，铺开整行正好
/// 多露出内容。手机宽度下与原来一样单列。
class ExploreContentSection extends StatelessWidget {
  const ExploreContentSection({
    super.key,
    required this.viewData,
    required this.controller,
    required this.onOpenDiary,
    required this.onOpenMediaGallery,
    required this.onOpenTagSearch,
    required this.onCreateToday,
  });

  final ExploreViewData viewData;
  final ExplorePageController controller;
  final ValueChanged<String> onOpenDiary;
  final VoidCallback onOpenMediaGallery;
  final ValueChanged<ExploreTagUsage> onOpenTagSearch;
  final VoidCallback onCreateToday;

  /// 两张卡片并排的最小内容宽度：每张约 354 起，与手机上的单列卡片相当。
  static const double twoUpMinWidth = 720;

  /// 卡片之间的间距（横竖一致）。
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          _buildColumn(twoUp: constraints.maxWidth >= twoUpMinWidth),
    );
  }

  Widget _buildColumn({required bool twoUp}) {
    final memory = ExploreMemoryCard(
      items: viewData.onThisDayDiaries,
      fallbackPrompt: viewData.fallbackPrompt,
      onOpenDiary: onOpenDiary,
      onCreateToday: onCreateToday,
    );
    final insight = ExploreInsightCard(
      moodWeights30: viewData.moodWeights30,
      energyValues7: viewData.energyValues7,
    );
    return Column(
      children: <Widget>[
        ExploreStatsCard(stats: viewData.stats),
        const SizedBox(height: _gap),
        if (twoUp)
          // 两张卡片内容高度不同，顶端对齐；不用 IntrinsicHeight 拉齐：
          // “那年今日”里的 PageView 不支持固有尺寸测量。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: memory),
              const SizedBox(width: _gap),
              Expanded(child: insight),
            ],
          )
        else ...<Widget>[memory, const SizedBox(height: _gap), insight],
        const SizedBox(height: _gap),
        ExploreTagCloudCard(
          tags: viewData.tagUsages,
          onOpenTagSearch: onOpenTagSearch,
        ),
        const SizedBox(height: 12),
        ExploreMediaGalleryCard(
          items: viewData.mediaItems,
          onOpenMediaGallery: onOpenMediaGallery,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
