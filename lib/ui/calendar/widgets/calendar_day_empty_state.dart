import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../app_surface/widgets/app_glass_scope.dart';

/// 选中日期无日记时的空态引导区。[onAction] 为 null 时只显示文案，不留
/// 按钮与它上方的间距。
class CalendarDayEmptyState extends StatelessWidget {
  const CalendarDayEmptyState({
    super.key,
    this.onAction,
    this.message,
    this.actionLabel,
  });

  final VoidCallback? onAction;
  final String? message;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final glass = AppGlass.of(context);
    final glassCard = glass.isGlass(AppGlassComponent.cards);
    final displayMessage = message ?? l10n.autoT0182;
    final displayActionLabel = actionLabel ?? l10n.autoT0181;
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
        // “卡片”为玻璃时与旁边的日记卡片同一底色与描边。只换颜色、不做成
        // 模糊的玻璃表面：这块占位在日期切换的交叉淡入（AnimatedSwitcher 的
        // FadeTransition）里，模糊放进透明度层会先闪一块没有模糊的底。
        decoration: glassCard
            ? BoxDecoration(
                color: glass.fill,
                borderRadius: BorderRadius.circular(16),
                border: glass.border == null
                    ? null
                    : Border.fromBorderSide(glass.border!),
              )
            : BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
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
            if (onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.l),
              FilledButton.tonal(
                style: AppGlassField.tonalButtonStyle(context),
                onPressed: onAction,
                child: Text(displayActionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
