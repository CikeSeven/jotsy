import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

import '../models/explore_view_data.dart';

/// 探索页图片查看器。
///
/// 保留探索模块原有入口类型，将实际浏览/保存/分享能力委托给通用图片浏览页，
/// 避免日记浏览与探索画廊维护两套相同的图片查看交互。
class ExploreImageViewerPage extends StatelessWidget {
  const ExploreImageViewerPage({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
  });

  final List<ExploreMediaItem> mediaItems;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return ImageViewerPage(
      items: mediaItems
          .map((item) => ImageViewerItem(source: item.source))
          .toList(growable: false),
      initialIndex: initialIndex,
    );
  }
}
