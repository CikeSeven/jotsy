import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../models/app_update_state.dart';
import 'app_update_labels.dart';
import 'app_update_progress_bar.dart';

/// 下载中：一行“已下载 / 总大小 · 速度”，进度条（总长未知时为等待指示），
/// 所用线路，以及“取消下载”。
class AppUpdateDownloadProgressView extends StatelessWidget {
  const AppUpdateDownloadProgressView({
    super.key,
    required this.state,
    required this.onCancel,
  });

  final AppUpdateState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final progress = state.progress;
    final total = progress?.total ?? state.asset?.size;
    final received = progress?.received ?? 0;
    final fraction = total == null || total <= 0
        ? null
        : (received / total).clamp(0.0, 1.0);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                total == null
                    ? l10n.formatByteSize(received)
                    : l10n.appUpdateDownloadProgress(
                        l10n.formatByteSize(received),
                        l10n.formatByteSize(total),
                      ),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
            if (progress != null && progress.bytesPerSecond > 0)
              Text(
                l10n.appUpdateDownloadSpeed(
                  l10n.formatByteSize(progress.bytesPerSecond),
                ),
                style: caption,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        if (fraction == null)
          const Align(
            alignment: Alignment.centerLeft,
            child: ExpressiveLoadingIndicator(size: 24),
          )
        else
          Semantics(
            value: '${(fraction * 100).floor()}%',
            child: AppUpdateProgressBar(value: fraction),
          ),
        if (progress != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.appUpdateDownloadVia(
              appUpdateSourceName(l10n, progress.source),
            ),
            style: caption,
          ),
        ],
        const SizedBox(height: AppSpacing.m),
        OutlinedButton(
          onPressed: onCancel,
          child: Text(l10n.appUpdateActionCancel),
        ),
      ],
    );
  }
}
