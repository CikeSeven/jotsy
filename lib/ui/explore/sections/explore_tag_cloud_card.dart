import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';

/// 标签云卡片。
class ExploreTagCloudCard extends StatelessWidget {
  const ExploreTagCloudCard({
    super.key,
    required this.tags,
    required this.onOpenTagSearch,
  });

  final List<ExploreTagUsage> tags;
  final ValueChanged<ExploreTagUsage> onOpenTagSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreSectionTitle(
            icon: FontAwesomeIcons.tags,
            title: l10n.autoT0069,
          ),
          const SizedBox(height: 10),
          if (tags.isEmpty)
            Text(
              l10n.autoT0199,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            )
          else
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children:
                  tags.map((tag) {
                    final ratio =
                        tag.maxCount <= 0
                            ? 0.2
                            : (tag.count / tag.maxCount).clamp(0.2, 1.0);
                    return ActionChip(
                      onPressed: () => onOpenTagSearch(tag),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                      labelPadding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 0,
                      ),
                      label: Text(
                        '# ${tag.name}',
                        style: TextStyle(fontSize: 9.8 + 1.8 * ratio),
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
