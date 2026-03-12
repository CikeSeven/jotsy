import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';

/// 选中日期无日记时的空态引导区。
class CalendarDayEmptyState extends StatelessWidget {
  const CalendarDayEmptyState({
    super.key,
    required this.onAction,
    this.message,
    this.actionLabel,
  });

  final VoidCallback onAction;
  final String? message;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final displayMessage =
        message ?? l10n.autoT0182;
    final displayActionLabel =
        actionLabel ?? l10n.autoT0181;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.xxl,
          AppSpacing.l,
          AppSpacing.xxl,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(displayActionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
