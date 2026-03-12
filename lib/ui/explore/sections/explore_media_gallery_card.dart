import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';

/// 媒体画廊卡片（横向队列）。
class ExploreMediaGalleryCard extends StatelessWidget {
  const ExploreMediaGalleryCard({
    super.key,
    required this.items,
    required this.onOpenMediaGallery,
  });

  final List<ExploreMediaItem> items;
  final VoidCallback onOpenMediaGallery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final previewItems = items.take(5).toList(growable: false);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenMediaGallery,
        child: ExploreCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ExploreSectionTitle(
                    icon: FontAwesomeIcons.images,
                    title: l10n.autoT0054,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onOpenMediaGallery,
                    tooltip: l10n.autoT0061,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (previewItems.isEmpty)
                Text(
                  l10n.autoT0062,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                )
              else
                IgnorePointer(
                  child: SizedBox(
                    height: 108,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: previewItems.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = previewItems[index];
                        return ExploreMediaThumb(
                          source: item.source,
                          width: 140,
                          height: 108,
                          radius: 12,
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
