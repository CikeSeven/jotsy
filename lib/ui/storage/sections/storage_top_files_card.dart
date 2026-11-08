import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../explore/widgets/charts/explore_bar.dart';
import '../../explore/widgets/charts/explore_reveal.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../viewmodels/storage_labels.dart';
import '../viewmodels/storage_media_view.dart';
import '../widgets/storage_media_thumb.dart';

/// 总览页“占用最多”：最大的几个媒体，每行缩略图、来自哪里、相对最大那个
/// 的比例条（类别色，依次生长）与大小；点按看详情，末行“查看全部”进媒体
/// 页（按从大到小）。没有媒体时不出现。
class StorageTopFilesCard extends StatelessWidget {
  const StorageTopFilesCard({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onSeeAll,
  });

  final List<StorageMediaItemView> items;
  final ValueChanged<StorageMediaItemView> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final largest = items.first.entry.bytes;
    return SettingsCardGroup(
      title: l10n.storageMgmtTopTitle,
      children: <Widget>[
        ExploreReveal(
          builder: (BuildContext context, double reveal) => Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.m,
              AppSpacing.l,
              0,
            ),
            child: Column(
              children: <Widget>[
                for (var i = 0; i < items.length; i++)
                  _TopRow(
                    item: items[i],
                    fraction: largest <= 0
                        ? 0
                        : items[i].entry.bytes /
                              largest *
                              ExploreReveal.staggered(reveal, i, items.length),
                    onTap: () => onOpen(items[i]),
                  ),
              ],
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              0,
              0,
              AppSpacing.s,
              AppSpacing.xs,
            ),
            child: TextButton.icon(
              onPressed: onSeeAll,
              iconAlignment: IconAlignment.end,
              icon: const FaIcon(FontAwesomeIcons.angleRight, size: 12),
              label: Text(l10n.storageMgmtSeeAll),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.item,
    required this.fraction,
    required this.onTap,
  });

  static const double _thumb = 44;

  final StorageMediaItemView item;
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = item.entry;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.square(
                dimension: _thumb,
                child: StorageMediaThumb(
                  entry: entry,
                  masked: item.masked,
                  extent: _thumb,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          storageMediaTitle(l10n, entry, masked: item.masked),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: item.masked ? scheme.onSurfaceVariant : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Text(
                        l10n.formatByteSize(entry.bytes),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  ExploreBar(
                    fraction: fraction,
                    color: entry.category.color(scheme),
                    track: ExploreChartColors.track(scheme),
                    height: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
