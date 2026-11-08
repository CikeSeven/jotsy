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
import '../widgets/storage_ring_chart.dart';
import '../widgets/storage_usage_bar.dart';
import 'storage_device_card.dart';
import 'storage_legend_item.dart';

/// 总览页的“应用占用”卡：环形图（中间为总数，计数上升）与三项要点（媒体
/// 文件、可释放、占手机），下面两列图例（大小与占比），以及“一键清理”。
///
/// 图例点按交给 [onCategoryTap]（媒体类别进媒体页、背景图进背景设置），
/// [canOpenCategory] 为 false 的不可点。“一键清理”只清缓存、未使用的文件与
/// 数据库空闲页（[StorageUsageReport.reclaimableBytes]），为 0 时不出现。
class StorageAppCard extends StatelessWidget {
  const StorageAppCard({
    super.key,
    required this.view,
    required this.onCleanUp,
    required this.canOpenCategory,
    required this.onCategoryTap,
  });

  /// 环形图与要点并排所需的最小宽度，更窄时上下排。
  static const double _sideBySideWidth = 300;

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
    final reclaimable = report.reclaimableBytes;
    final media = view.allMedia;
    final share = view.deviceShare;
    final ring = ExploreReveal(
      builder: (BuildContext context, double reveal) => StorageRingChart(
        reveal: reveal,
        track: ExploreChartColors.track(scheme),
        segments: [
          for (final (category, bytes) in view.segments)
            StorageBarSegment(color: category.color(scheme), bytes: bytes),
        ],
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _CountUpBytes(bytes: view.total),
            Text(
              l10n.storageMgmtTotalLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
    final facts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Fact(
          icon: FontAwesomeIcons.photoFilm,
          label: l10n.storageMgmtMediaTitle,
          value: l10n.formatByteSize(media.bytes),
          detail: l10n.storageMgmtFileCount(media.count),
        ),
        const SizedBox(height: AppSpacing.m),
        _Fact(
          icon: FontAwesomeIcons.broom,
          label: l10n.storageMgmtReclaimable,
          value: l10n.formatByteSize(reclaimable),
        ),
        if (share != null) ...<Widget>[
          const SizedBox(height: AppSpacing.m),
          _Fact(
            icon: FontAwesomeIcons.mobileScreenButton,
            label: l10n.storageMgmtDeviceShareLabel,
            value: storagePercentLabel(l10n, share),
          ),
        ],
      ],
    );
    return AppCardSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: WidthLayoutBuilder(
        builder: (BuildContext context, double width) {
          final columns = width >= 280 ? 2 : 1;
          const spacing = AppSpacing.s;
          final legendWidth = (width - spacing * (columns - 1)) / columns;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.storageMgmtAppTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              if (width >= _sideBySideWidth)
                Row(
                  children: <Widget>[
                    ring,
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: facts),
                  ],
                )
              else ...<Widget>[
                Center(child: ring),
                const SizedBox(height: AppSpacing.l),
                facts,
              ],
              const SizedBox(height: AppSpacing.l),
              Wrap(
                spacing: spacing,
                children: <Widget>[
                  for (final (category, bytes) in view.segments)
                    SizedBox(
                      width: legendWidth,
                      child: StorageLegendItem(
                        color: category.color(scheme),
                        label: category.label(l10n),
                        detail: view.total <= 0
                            ? null
                            : storagePercentLabel(l10n, bytes / view.total),
                        value: l10n.formatByteSize(bytes),
                        onTap: canOpenCategory(category)
                            ? () => onCategoryTap(category)
                            : null,
                      ),
                    ),
                ],
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
                      l10n.storageMgmtCleanUpAll(
                        l10n.formatByteSize(reclaimable),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 环形图旁的一项要点：小图标与名称，下面是大号数值（可带一段小字）。
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final FaIconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detail = this.detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            FaIcon(icon, size: 11, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs + 2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              if (detail != null)
                TextSpan(
                  text: '  $detail',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
      builder: (BuildContext context, double value, Widget? _) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          l10n.formatByteSize(value.round()),
          maxLines: 1,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
