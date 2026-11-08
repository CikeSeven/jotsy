import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../explore/widgets/charts/explore_bar.dart';
import '../../explore/widgets/charts/explore_reveal.dart';
import '../../widgets/selectable_row_surface.dart';
import '../viewmodels/storage_labels.dart';
import '../viewmodels/storage_media_view.dart';
import 'storage_media_thumb.dart';

/// 媒体页列表里的一行：缩略图、来自哪篇日记、规格，右侧大小与相对列表
/// 里最大文件的比例细条，下方小标签（回收站、可压缩、用在几处、不能删除）。
///
/// 表面与选中态经 [SelectableRowSurface]；[selectionMode] 时左侧勾选框横向
/// 展开（与草稿箱、回收站的行一致）。
class StorageMediaTile extends StatelessWidget {
  const StorageMediaTile({
    super.key,
    required this.item,
    required this.largestBytes,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  static const double thumbnailSize = 56;

  final StorageMediaItemView item;
  final int largestBytes;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = item.entry;
    final secondary = scheme.onSurfaceVariant;
    final estimate = item.estimatedBytes;
    final badges = <(String, Color, Color)>[
      if (entry.onlyInTrash)
        (
          l10n.storageMgmtBadgeTrash,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      if (estimate != null)
        (
          l10n.storageMgmtBadgeCompressible(
            l10n.formatByteSize(entry.bytes - estimate),
          ),
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      if (entry.refs.length > 1)
        (
          l10n.storageMgmtBadgeUsedIn(entry.refs.length),
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      if (!entry.isEditable)
        (
          l10n.storageMgmtBadgeLocked,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    ];
    return SelectableRowSurface(
      selected: selected,
      selectionMode: selectionMode,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: <Widget>[
            AnimatedSize(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              alignment: AlignmentDirectional.centerStart,
              child: selectionMode
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.xs,
                      ),
                      child: ExcludeSemantics(
                        child: IgnorePointer(
                          child: Checkbox(value: selected, onChanged: (_) {}),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.m),
              child: SizedBox.square(
                dimension: thumbnailSize,
                child: StorageMediaThumb(
                  entry: entry,
                  masked: item.masked,
                  extent: thumbnailSize,
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
                      if (item.masked) ...<Widget>[
                        FaIcon(
                          FontAwesomeIcons.lock,
                          size: 12,
                          color: secondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: Text(
                          storageMediaTitle(l10n, entry, masked: item.masked),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: item.masked ? secondary : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    storageMediaDetails(l10n, item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: secondary,
                    ),
                  ),
                  if (badges.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final (label, background, foreground) in badges)
                          StorageBadge(
                            label: label,
                            background: background,
                            foreground: foreground,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  l10n.formatByteSize(entry.bytes),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                SizedBox(
                  width: 48,
                  child: ExploreBar(
                    fraction: largestBytes <= 0
                        ? 0
                        : entry.bytes / largestBytes,
                    color: entry.category.color(scheme),
                    track: ExploreChartColors.track(scheme),
                    height: 4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表行与详情面板里的小标签。
class StorageBadge extends StatelessWidget {
  const StorageBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.s),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: foreground),
        ),
      ),
    );
  }
}
