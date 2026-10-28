import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../controllers/explore_content_extractor.dart';
import '../controllers/explore_life_builder.dart';
import '../controllers/explore_module_actions.dart';
import '../models/explore_module_config.dart';
import '../models/explore_module_options.dart';
import '../viewmodels/explore_entry.dart';
import '../widgets/explore_shared_widgets.dart';

/// 随机回顾：从候选里抽一篇旧日记，“换一篇”再抽。
///
/// 抽取经 [ExploreLifeBuilder.pick] 按种子：开了“每日固定”时种子取当天日期
/// （同一天总是同一篇，跨天自动换），否则取本卡创建的时刻（每次进入探索页
/// 换一篇）；“换一篇”只在本卡内存里改种子，不落盘。
class ExploreRandomCard extends StatefulWidget {
  const ExploreRandomCard({
    super.key,
    required this.config,
    required this.pool,
    required this.now,
  });

  final ExploreModuleConfig config;
  final List<ExploreEntry> pool;
  final DateTime now;

  @override
  State<ExploreRandomCard> createState() => _ExploreRandomCardState();
}

class _ExploreRandomCardState extends State<ExploreRandomCard> {
  final int _sessionSeed = DateTime.now().microsecondsSinceEpoch;
  int _shuffle = 0;

  int get _seed {
    final base = widget.config.toggle(ExploreOptions.randomDaily)
        ? exploreDayKey(widget.now)
        : _sessionSeed;
    return base + _shuffle * 7919;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actions = ExploreActionsScope.of(context);
    final entry = ExploreLifeBuilder.pick(widget.pool, _seed);
    final title = entry?.title.trim() ?? '';
    final cover = entry?.cover;
    return ExploreCard(
      onTap: entry == null ? null : () => actions.openDiary(entry.diaryId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExploreCardHeader(
            icon: FontAwesomeIcons.shuffle,
            title: l10n.exploreModuleRandomMemory,
            trailing: widget.pool.length < 2
                ? null
                : ExploreHeaderArrow(
                    tooltip: l10n.exploreRandomShuffle,
                    icon: FontAwesomeIcons.rotateRight,
                    onPressed: () => setState(() => _shuffle += 1),
                  ),
          ),
          if (entry == null)
            ExploreInlineHint(message: l10n.exploreRandomEmpty)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.formatFullDate(entry.created),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title.isEmpty ? l10n.autoT0065 : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        const ExploreContentExtractor().summaryFromText(
                          entry.source.contentText,
                          emptyFallback: l10n.autoT0186,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (cover != null) ...<Widget>[
                  const SizedBox(width: 12),
                  ExploreMediaThumb(
                    source: cover,
                    width: 84,
                    height: 84,
                    radius: 14,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
