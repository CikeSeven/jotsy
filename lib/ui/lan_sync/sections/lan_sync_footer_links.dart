import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_page_backdrop.dart';

/// 页面底部的两个文本按钮：“找不到设备？ · 手动输入地址”（`primary` w600，
/// 中间 `outlineVariant` 圆点分隔）。窄屏放不下时折成两行。
class LanSyncFooterLinks extends StatelessWidget {
  const LanSyncFooterLinks({
    super.key,
    required this.onTroubleshoot,
    required this.onManualAddress,
  });

  final VoidCallback onTroubleshoot;
  final VoidCallback onManualAddress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    // 按钮直接落在页面背景上：文字经 onBackgroundTextStyle 保证可读。
    final style = TextButton.styleFrom(
      foregroundColor: colors.primary,
      textStyle: AppPageBackdrop.onBackgroundTextStyle(
        context,
        theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        TextButton(
          style: style,
          onPressed: onTroubleshoot,
          child: Text(l10n.lanSyncTroubleshoot),
        ),
        ExcludeSemantics(
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              shape: BoxShape.circle,
            ),
          ),
        ),
        TextButton(
          style: style,
          onPressed: onManualAddress,
          child: Text(l10n.lanSyncManualAddress),
        ),
      ],
    );
  }
}
