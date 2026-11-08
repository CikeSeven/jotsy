import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../explore/widgets/charts/explore_reveal.dart';
import '../../widgets/width_layout_builder.dart';
import '../viewmodels/storage_labels.dart';
import '../viewmodels/storage_overview_view.dart';
import '../widgets/storage_usage_bar.dart';

/// 总览页顶部的占用卡：总数（计数上升）、设备剩余空间、分段占用条、两列
/// 图例，以及“一键清理”。
///
/// 图例点按交给 [onCategoryTap]（媒体类别进媒体页、背景图进背景设置），
/// 返回 false 的类别不可点。“一键清理”只清缓存、未使用的文件与数据库
/// 空闲页（[StorageUsageReport.reclaimableBytes]），为 0 时不出现。
class StorageOverviewCard extends StatelessWidget {
  const StorageOverviewCard({
    super.key,
    required this.view,
    required this.onCleanUp,
    required this.canOpenCategory,
    required this.onCategoryTap,
  });

  final StorageOverviewView view;
  final VoidCallback? onCleanUp;
  final bool Function(StorageCategory category) canOpenCategory;
  final ValueChanged<StorageCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final report = view.report;
    final space = report.deviceSpace;
    final reclaimable = report.reclaimableBytes;
    return AppCardSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.storageMgmtTotalLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _CountUpBytes(bytes: view.total),
          if (space != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.storageMgmtDeviceSpace(
                l10n.formatByteSize(space.freeBytes),
                l10n.formatByteSize(space.totalBytes),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          ExploreReveal(
            builder: (BuildContext context, double reveal) => StorageUsageBar(
              reveal: reveal,
              track: ExploreChartColors.track(scheme),
              segments: [
                for (final (category, bytes) in view.segments)
                  StorageBarSegment(
                    color: category.color(scheme),
                    bytes: bytes,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          _Legend(
            segments: view.segments,
            canOpen: canOpenCategory,
            onTap: onCategoryTap,
          ),
          if (reclaimable > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                style: AppGlassField.tonalButtonStyle(context),
                onPressed: onCleanUp,
                icon: const FaIcon(FontAwesomeIcons.broom, size: 14),
                label: Text(
                  l10n.storageMgmtCleanUpAll(l10n.formatByteSize(reclaimable)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 总数从上一次的值补间到新值（首次从 0 起），等宽数字不抖动。
class _CountUpBytes extends StatelessWidget {
  const _CountUpBytes({required this.bytes});

  final int bytes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: bytes.toDouble()),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.long),
      curve: ExpressiveMotion.effects,
      builder: (BuildContext context, double value, Widget? _) => Text(
        l10n.formatByteSize(value.round()),
        maxLines: 1,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.primary,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.segments,
    required this.canOpen,
    required this.onTap,
  });

  final List<(StorageCategory, int)> segments;
  final bool Function(StorageCategory category) canOpen;
  final ValueChanged<StorageCategory> onTap;

  @override
  Widget build(BuildContext context) {
    return WidthLayoutBuilder(
      builder: (BuildContext context, double width) {
        // 两列；太窄（320dp 加大字号）时退成一列，名称与大小都不被截断。
        final columns = width >= 280 ? 2 : 1;
        const spacing = AppSpacing.s;
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          children: <Widget>[
            for (final (category, bytes) in segments)
              SizedBox(
                width: itemWidth,
                child: _LegendItem(
                  category: category,
                  bytes: bytes,
                  onTap: canOpen(category) ? () => onTap(category) : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.category,
    required this.bytes,
    required this.onTap,
  });

  final StorageCategory category;
  final int bytes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.s,
        ),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: category.color(scheme),
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 10),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                category.label(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              l10n.formatByteSize(bytes),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
