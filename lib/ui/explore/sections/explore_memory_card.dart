import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../controllers/explore_page_controller.dart';
import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';

/// “那年今日”情感回顾卡片。
class ExploreMemoryCard extends StatelessWidget {
  const ExploreMemoryCard({
    super.key,
    required this.viewData,
    required this.controller,
    required this.onOpenDiary,
    required this.onCreateToday,
  });

  final ExploreViewData viewData;
  final ExplorePageController controller;
  final ValueChanged<String> onOpenDiary;
  final VoidCallback onCreateToday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final memory = viewData.onThisDayDiary;
    final mediaSource =
        memory == null ? null : controller.contentExtractor.resolveMediaSource(memory.diary);

    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ExploreSectionTitle(
            icon: FontAwesomeIcons.clockRotateLeft,
            title: '那年今日',
          ),
          const SizedBox(height: 10),
          if (memory == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    viewData.fallbackPrompt,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: onCreateToday,
                    child: const Text('补写今天'),
                  ),
                ],
              ),
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onOpenDiary(memory.diary.diaryId),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            viewData.onThisDayLabel,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            memory.diary.title.trim().isEmpty
                                ? '无标题日记'
                                : memory.diary.title.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            controller.contentExtractor.summaryText(memory.diary),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (mediaSource != null) ...<Widget>[
                      const SizedBox(width: 10),
                      ExploreMediaThumb(
                        source: mediaSource,
                        width: 90,
                        height: 90,
                        radius: 10,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
