import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../controllers/explore_page_controller.dart' show ExplorePageController;
import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';
import '../../../app/theme/expressive_motion.dart';

/// “那年今日”情感回顾卡片。
///
/// 设计目标：
/// - 无历史记录：显示引导文案与“补写今天”；
/// - 有 1 条记录：展示单卡，无轮播指示器；
/// - 有多条记录：启用左右滑动 Carousel，并展示页码 dots。
class ExploreMemoryCard extends StatefulWidget {
  const ExploreMemoryCard({
    super.key,
    required this.items,
    required this.onOpenDiary,
    required this.onCreateToday,
    this.fallbackPrompt = '',
  });

  /// 回忆条目（经 [ExplorePageController.pickOnThisDayList] 选出）。
  final List<ExploreOnThisDayItem> items;

  /// 没有回忆时的引导文案。
  final String fallbackPrompt;
  final ValueChanged<String> onOpenDiary;
  final VoidCallback onCreateToday;

  @override
  State<ExploreMemoryCard> createState() => _ExploreMemoryCardState();
}

class _ExploreMemoryCardState extends State<ExploreMemoryCard> {
  late final PageController _pageController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant ExploreMemoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxIndex = widget.items.length - 1;
    if (maxIndex < 0) {
      if (_activeIndex != 0) {
        setState(() {
          _activeIndex = 0;
        });
      }
      return;
    }
    if (_activeIndex > maxIndex) {
      setState(() {
        _activeIndex = maxIndex;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(maxIndex);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final memories = widget.items;

    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreSectionTitle(
            icon: FontAwesomeIcons.clockRotateLeft,
            title: l10n.autoT0063,
          ),
          const SizedBox(height: 10),
          if (memories.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.brightness == Brightness.light
                    ? colorScheme.surfaceContainerLow
                    : colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(
                    alpha:
                        Theme.of(context).colorScheme.brightness ==
                            Brightness.light
                        ? 0.3
                        : 0.15,
                  ),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.fallbackPrompt,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: widget.onCreateToday,
                    child: Text(l10n.autoT0064),
                  ),
                ],
              ),
            )
          else ...<Widget>[
            SizedBox(
              height: 140,
              child: memories.length == 1
                  ? _buildMemoryItemCard(context, memories.first)
                  : PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _activeIndex = index;
                        });
                      },
                      itemCount: memories.length,
                      itemBuilder: (context, index) {
                        return _buildMemoryItemCard(context, memories[index]);
                      },
                    ),
            ),
            if (memories.length > 1) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(memories.length, (index) {
                  final selected = index == _activeIndex;
                  return AnimatedContainer(
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.fast,
                    ),
                    curve: ExpressiveMotion.effects,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: selected ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMemoryItemCard(BuildContext context, ExploreOnThisDayItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = item.title.trim();
    final mediaSource = item.mediaSource;
    final isLight = colorScheme.brightness == Brightness.light;
    // 底色与描边由 Material 承载，InkWell 的水波纹画在同一 Material 上；
    // 若用带底色的 Container 包在 InkWell 里，水波纹会被底色完全盖住。
    return Material(
      color: isLight
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: isLight ? 0.3 : 0.15,
          ),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onOpenDiary(item.diaryId),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.timeLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title.isEmpty ? context.l10n.autoT0065 : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.summaryText,
                      maxLines: 2,
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
                const SizedBox(width: 12),
                ExploreMediaThumb(
                  source: mediaSource,
                  width: 96,
                  height: 96,
                  radius: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
