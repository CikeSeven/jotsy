import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../controllers/explore_page_controller.dart' show ExplorePageController;
import '../models/explore_module_options.dart';
import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';
import '../../../app/theme/expressive_motion.dart';

/// “那年今日”情感回顾卡片（探索页与日记本统计页共用）。
///
/// 设计目标：
/// - 无历史记录：显示 [emptyMessage] 与“写日记”；
/// - 轮播样式（默认）：1 条时展示单卡，多条时左右滑动并展示页码点；
/// - 列表样式（[ExploreMemoryStyle.list]）：每条一行，缩略图在左。
class ExploreMemoryCard extends StatefulWidget {
  const ExploreMemoryCard({
    super.key,
    required this.items,
    required this.onOpenDiary,
    required this.onCreateToday,
    this.emptyMessage = '',
    this.style = ExploreMemoryStyle.carousel,
  });

  /// 回忆条目（经 [ExplorePageController.pickOnThisDayList] 选出）。
  final List<ExploreOnThisDayItem> items;

  /// 没有回忆时的说明。
  final String emptyMessage;
  final ExploreMemoryStyle style;
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
          ExploreCardHeader(
            icon: FontAwesomeIcons.clockRotateLeft,
            title: l10n.exploreModuleOnThisDay,
            trailing: memories.isEmpty
                ? null
                : ExploreHeaderNote(l10n.exploreUnitEntries(memories.length)),
          ),
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
                    widget.emptyMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: widget.onCreateToday,
                    child: Text(l10n.exploreGreetingWrite),
                  ),
                ],
              ),
            )
          else if (widget.style == ExploreMemoryStyle.list)
            Column(
              children: <Widget>[
                for (var i = 0; i < memories.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 8),
                  _buildListRow(context, memories[i]),
                ],
              ],
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

  /// 列表样式的一行：缩略图（有时）+ 时间标签、标题与一行摘要。
  Widget _buildListRow(BuildContext context, ExploreOnThisDayItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = item.title.trim();
    final mediaSource = item.mediaSource;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => widget.onOpenDiary(item.diaryId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            if (mediaSource != null) ...<Widget>[
              ExploreMediaThumb(
                source: mediaSource,
                width: 56,
                height: 56,
                radius: 12,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title.isEmpty ? context.l10n.autoT0065 : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    item.summaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
