import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';

/// 选中日期无日记时的空态引导区。
class CalendarDayEmptyState extends StatelessWidget {
  const CalendarDayEmptyState({
    super.key,
    required this.onCreate,
  });

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              '这一天很安静，没有任何记录。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton.tonal(
              onPressed: onCreate,
              child: const Text('补写日记'),
            ),
          ],
        ),
      ),
    );
  }
}
