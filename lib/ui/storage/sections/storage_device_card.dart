import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../explore/widgets/charts/explore_reveal.dart';
import '../widgets/storage_usage_bar.dart';
import 'storage_legend_item.dart';

/// 总览页顶部的“手机存储”卡（只有读得到设备空间的平台，Android）：
/// 标称总容量、已用百分比，一条“本应用 / 其他应用与系统 / 可用”三段的存储
/// 条（可用部分是轨道底色），以及三项的大小与本应用占手机的比例。
///
/// 数字取系统的存储统计（与系统设置一致）；[appBytes] 为本应用的总占用
/// （`storageAppTotal`），从已用里单独拿出来、用主色标出。
class StorageDeviceCard extends StatelessWidget {
  const StorageDeviceCard({
    super.key,
    required this.space,
    required this.appBytes,
  });

  final StorageDeviceSpace space;
  final int appBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final used = space.usedBytes;
    final app = appBytes.clamp(0, used);
    final others = used - app;
    final total = space.totalBytes;
    String size(int bytes) => l10n.formatByteSize(bytes);
    String percent(double share) => storagePercentLabel(l10n, share);
    final otherColor = scheme.secondary.withValues(alpha: 0.5);
    return AppCardSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              FaIcon(
                FontAwesomeIcons.mobileScreenButton,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  l10n.storageMgmtDeviceTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                l10n.storageMgmtDeviceTotal(size(total)),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: percent(total <= 0 ? 0 : used / total),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                TextSpan(
                  text: '  ${l10n.storageMgmtDeviceUsedLabel}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          ExploreReveal(
            builder: (BuildContext context, double reveal) => StorageUsageBar(
              reveal: reveal,
              height: 16,
              minSegment: 6,
              totalBytes: total,
              track: ExploreChartColors.track(scheme),
              segments: [
                StorageBarSegment(color: scheme.primary, bytes: app),
                StorageBarSegment(color: otherColor, bytes: others),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          StorageLegendItem(
            color: scheme.primary,
            label: l10n.storageMgmtDeviceApp,
            detail: total <= 0
                ? null
                : l10n.storageMgmtShareOfDevice(percent(app / total)),
            value: size(app),
          ),
          StorageLegendItem(
            color: otherColor,
            label: l10n.storageMgmtDeviceOther,
            value: size(others),
          ),
          StorageLegendItem(
            color: ExploreChartColors.track(scheme),
            outlined: true,
            label: l10n.storageMgmtDeviceFree,
            value: size(space.freeBytes),
          ),
        ],
      ),
    );
  }
}

/// 百分比文字（按界面语言的写法）：不到 1% 时保留一位小数，小于 0.1% 写
/// “<0.1%”，否则取整。
String storagePercentLabel(AppLocalizations l10n, double share) {
  NumberFormat format(int digits) => NumberFormat.decimalPercentPattern(
    locale: l10n.localeName,
    decimalDigits: digits,
  );
  if (share <= 0) return format(0).format(0);
  if (share < 0.001) return '<${format(1).format(0.001)}';
  return format(share < 0.01 ? 1 : 0).format(share);
}
