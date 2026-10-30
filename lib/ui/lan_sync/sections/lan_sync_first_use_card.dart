import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_card_surface.dart';

/// 首次使用（没有已配对设备）时英雄卡下方的说明卡（DESIGN.md §5.28）：
/// 标题、一句加密与不经服务器的说明，以及三步编号。
class LanSyncFirstUseCard extends StatelessWidget {
  const LanSyncFirstUseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final steps = <String>[
      l10n.lanSyncFirstUseStep1,
      l10n.lanSyncFirstUseStep2,
      l10n.lanSyncFirstUseStep3,
    ];
    return AppCardSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.lanSyncFirstUseTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.lanSyncFirstUseBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          for (final (index, step) in steps.indexed) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      step,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
