import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// “新版本”小胶囊：设置页“关于”入口与关于页“检查更新”行共用。
class AppUpdateBadge extends StatelessWidget {
  const AppUpdateBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.l10n.appUpdateAvailableBadge,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
