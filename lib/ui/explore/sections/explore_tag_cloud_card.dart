import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';

/// 标签云卡片。
class ExploreTagCloudCard extends StatelessWidget {
  const ExploreTagCloudCard({
    super.key,
    required this.tags,
    required this.onOpenDiary,
  });

  final List<ExploreTagUsage> tags;
  final ValueChanged<String> onOpenDiary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ExploreSectionTitle(
            icon: FontAwesomeIcons.tags,
            title: '标签云',
          ),
          const SizedBox(height: 10),
          if (tags.isEmpty)
            Text(
              '还没有标签数据，写几篇带标签的日记试试。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  tags.map((tag) {
                    final ratio =
                        tag.maxCount <= 0
                            ? 0.2
                            : (tag.count / tag.maxCount).clamp(0.2, 1.0);
                    return ActionChip(
                      onPressed: () => onOpenDiary(tag.latestDiaryId),
                      label: Text(
                        '# ${tag.name}',
                        style: TextStyle(fontSize: 12 + 4 * ratio),
                      ),
                      backgroundColor: Color(tag.color).withValues(
                        alpha: 0.08 + ratio * 0.25,
                      ),
                    );
                  }).toList(growable: false),
            ),
        ],
      ),
    );
  }
}
