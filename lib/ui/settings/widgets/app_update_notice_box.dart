import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';

/// 说明块：图标 + 标题 + 正文。错误用 errorContainer，其余用
/// secondaryContainer，明暗主题下都由配套的 on 色保证可读。
class AppUpdateNoticeBox extends StatelessWidget {
  const AppUpdateNoticeBox({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.error = false,
  });

  final FaIconData icon;
  final String title;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = error
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final foreground = error
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: FaIcon(icon, size: 16, color: foreground),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
