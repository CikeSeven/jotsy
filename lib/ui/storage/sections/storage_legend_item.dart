import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';

/// 图例的一行：色点、名称（下面可带一行小字，如占比）、行尾大小。
///
/// [outlined] 的色点只画描边（手机存储里的“可用”：条上是轨道底色，实心点
/// 看不出来）。给了 [onTap] 时整行可点（媒体类别跳到媒体页）。
class StorageLegendItem extends StatelessWidget {
  const StorageLegendItem({
    super.key,
    required this.color,
    required this.label,
    required this.value,
    this.detail,
    this.outlined = false,
    this.onTap,
  });

  final Color color;
  final String label;
  final String value;
  final String? detail;
  final bool outlined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detail = this.detail;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs + 2,
        ),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: outlined ? null : color,
                shape: BoxShape.circle,
                border: outlined
                    ? Border.all(color: scheme.outline, width: 1.5)
                    : null,
              ),
              child: const SizedBox.square(dimension: 10),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (detail != null)
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              value,
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
