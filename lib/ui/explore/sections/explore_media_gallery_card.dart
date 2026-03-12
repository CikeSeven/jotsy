import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';

/// 媒体画廊卡片（横向队列）。
class ExploreMediaGalleryCard extends StatelessWidget {
  const ExploreMediaGalleryCard({
    super.key,
    required this.items,
    required this.onOpenDiary,
  });

  final List<ExploreMediaItem> items;
  final ValueChanged<String> onOpenDiary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ExploreSectionTitle(
            icon: FontAwesomeIcons.images,
            title: '媒体画廊',
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              '还没有可展示的图片。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            )
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onOpenDiary(item.diaryId),
                    child: ExploreMediaThumb(
                      source: item.source,
                      width: 140,
                      height: 108,
                      radius: 12,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
