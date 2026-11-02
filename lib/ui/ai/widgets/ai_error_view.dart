import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../pages/settings/ai_settings_page.dart';
import '../viewmodels/ai_labels.dart';
import 'ai_dialogs.dart';

/// AI 请求失败时的说明：error 色的一句话 + “查看详情”（原文）+ 配置类问题
/// 时的“去设置”+ 可选的“重试”。各模块（写作面板、回应、回顾、对话）共用。
class AiErrorView extends StatelessWidget {
  const AiErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.showSettings = true,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// 在设置页里显示时不再放“去设置”。
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final detail = aiErrorDetail(error);
    final buttonStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: theme.textTheme.labelMedium,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FaIcon(
                FontAwesomeIcons.circleExclamation,
                size: 14,
                color: colors.error,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                aiErrorMessage(l10n, error),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.error,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 4,
          children: <Widget>[
            if (onRetry != null)
              TextButton(
                style: buttonStyle,
                onPressed: onRetry,
                child: Text(l10n.commonRetry),
              ),
            if (showSettings && aiErrorNeedsSettings(error))
              TextButton(
                style: buttonStyle,
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const AiSettingsPage(),
                  ),
                ),
                child: Text(l10n.aiErrorOpenSettings),
              ),
            if (detail != null)
              TextButton(
                style: buttonStyle,
                onPressed: () => showAiDetailDialog(
                  context,
                  title: l10n.aiErrorDetails,
                  text: detail,
                ),
                child: Text(l10n.aiErrorDetails),
              ),
          ],
        ),
      ],
    );
  }
}
