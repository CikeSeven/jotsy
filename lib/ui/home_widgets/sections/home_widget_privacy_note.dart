import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// 日记类小组件（那年今日、最近日记）内容选项末尾的隐私说明：私密日记本里的
/// 日记不上桌面，开了应用锁时只显示锁定。
class HomeWidgetPrivacyNote extends StatelessWidget {
  const HomeWidgetPrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
      child: Text(
        context.l10n.homeWidgetPrivacyHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
