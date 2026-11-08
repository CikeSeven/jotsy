import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../explore/widgets/charts/explore_bar.dart';
import '../../explore/widgets/charts/explore_reveal.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../widgets/width_layout_builder.dart';
import '../models/storage_media_filter.dart';
import '../viewmodels/storage_labels.dart';
import '../viewmodels/storage_overview_view.dart';

/// 总览页“媒体文件”：每类媒体一块小卡（类别色图标、大小、数量、占全部
/// 媒体的比例条），外加“大文件”；两列（窄于 [_twoColumnWidth] 时一列），
/// 点按进媒体页对应的筛选。没有内容的类别不出现。
class StorageCategoryTiles extends StatelessWidget {
  const StorageCategoryTiles({
    super.key,
    required this.view,
    required this.onOpen,
  });

  static const double _twoColumnWidth = 260;

  final StorageOverviewView view;
  final ValueChanged<StorageMediaFilter> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final all = view.allMedia;
    if (all.count == 0) return const SizedBox.shrink();
    final tiles = <_TileData>[
      for (final category in StorageMediaFilter.categories)
        if ((view.media[category]?.count ?? 0) > 0)
          _TileData(
            icon: category.icon,
            color: category.color(scheme),
            label: category.label(l10n),
            stat: view.media[category]!,
            filter: StorageMediaFilter(category: category),
          ),
      if (view.large.count > 0)
        _TileData(
          icon: FontAwesomeIcons.weightHanging,
          color: scheme.error.withValues(alpha: 0.72),
          label: l10n.storageMgmtLargeFiles,
          stat: view.large,
          filter: const StorageMediaFilter(largeOnly: true),
        ),
    ];
    return SettingsCardGroup(
      title: l10n.storageMgmtMediaTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: WidthLayoutBuilder(
            builder: (BuildContext context, double width) {
              final columns = width >= _twoColumnWidth ? 2 : 1;
              const spacing = AppSpacing.s;
              final tileWidth = (width - spacing * (columns - 1)) / columns;
              return ExploreReveal(
                builder: (BuildContext context, double reveal) => Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: <Widget>[
                    for (var i = 0; i < tiles.length; i++)
                      SizedBox(
                        width: tileWidth,
                        child: _CategoryTile(
                          data: tiles[i],
                          share: all.bytes <= 0
                              ? 0
                              : tiles[i].stat.bytes /
                                    all.bytes *
                                    ExploreReveal.staggered(
                                      reveal,
                                      i,
                                      tiles.length,
                                    ),
                          onTap: () => onOpen(tiles[i].filter),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TileData {
  const _TileData({
    required this.icon,
    required this.color,
    required this.label,
    required this.stat,
    required this.filter,
  });

  final FaIconData icon;
  final Color color;
  final String label;
  final StorageCategoryStat stat;
  final StorageMediaFilter filter;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.data,
    required this.share,
    required this.onTap,
  });

  final _TileData data;
  final double share;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(AppSpacing.l);
    return Material(
      color: ExploreChartColors.track(scheme),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: data.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SizedBox.square(
                      dimension: 30,
                      child: Center(
                        child: FaIcon(data.icon, size: 13, color: data.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  FaIcon(
                    FontAwesomeIcons.angleRight,
                    size: 12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                l10n.formatByteSize(data.stat.bytes),
                maxLines: 1,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              Text(
                l10n.storageMgmtFileCount(data.stat.count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              ExploreBar(
                fraction: share.clamp(0, 1),
                color: data.color,
                track: scheme.surface.withValues(alpha: 0.6),
                height: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
