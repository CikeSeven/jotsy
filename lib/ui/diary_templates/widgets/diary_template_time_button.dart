import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../app_surface/widgets/app_glass_field.dart';

/// 开始 / 结束时间按钮：上方小标题，下方大号时间。两个按钮等宽；12 小时制
/// 的“上午 10:00”在窄屏大字号下可能放不下，时间只缩小不折行。
class DiaryTemplateTimeButton extends StatelessWidget {
  const DiaryTemplateTimeButton({
    super.key,
    required this.label,
    required this.time,
    required this.onPressed,
  });

  final String label;
  final String time;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.m,
      ),
    );
    return FilledButton.tonal(
      style: AppGlassField.tonalButtonStyle(context)?.merge(style) ?? style,
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            // 与 tonal 按钮的前景色一致（titleLarge 自带 onSurface）。
            child: Text(
              time,
              maxLines: 1,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
