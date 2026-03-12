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
class ExploreContentSection extends StatelessWidget {
  const ExploreContentSection({
    super.key,
    required this.viewData,
    required this.controller,
    required this.onOpenDiary,
    required this.onOpenTagSearch,
    required this.onCreateToday,
  });

  final ExploreViewData viewData;
  final ExplorePageController controller;
  final ValueChanged<String> onOpenDiary;
  final ValueChanged<ExploreTagUsage> onOpenTagSearch;
  final VoidCallback onCreateToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ExploreStatsCard(stats: viewData.stats),
        const SizedBox(height: 12),
        ExploreMemoryCard(
          viewData: viewData,
          controller: controller,
          onOpenDiary: onOpenDiary,
          onCreateToday: onCreateToday,
        ),
        const SizedBox(height: 12),
        ExploreInsightCard(
          moodWeights30: viewData.moodWeights30,
          energyValues7: viewData.energyValues7,
        ),
        const SizedBox(height: 12),
        ExploreTagCloudCard(
          tags: viewData.tagUsages,
          onOpenTagSearch: onOpenTagSearch,
        ),
        const SizedBox(height: 12),
        ExploreMediaGalleryCard(
          items: viewData.mediaItems,
          onOpenDiary: onOpenDiary,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
