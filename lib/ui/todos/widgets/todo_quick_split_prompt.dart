import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../app_surface/widgets/app_glass_field.dart';

/// 输入里有多行时的提示：“拆成 N 条待办？”+“合成一条”/“拆分”。
class TodoQuickSplitPrompt extends StatelessWidget {
  const TodoQuickSplitPrompt({
    super.key,
    required this.count,
    required this.onSplit,
    required this.onKeepOne,
  });

  final int count;
  final VoidCallback onSplit;
  final VoidCallback onKeepOne;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.xs,
        AppSpacing.s,
        0,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.todoQuickSplitPrompt(count),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: onKeepOne,
            child: Text(l10n.todoQuickKeepOne),
          ),
          FilledButton.tonal(
            style: AppGlassField.tonalButtonStyle(context),
            onPressed: onSplit,
            child: Text(l10n.todoQuickSplit),
          ),
        ],
      ),
    );
  }
}
