// 会话面板底部的进度区（DESIGN.md §5.27“同步中”）。
//
// 两种形态：
// - 传输阶段且有媒体要传：左“正在传输图片与录音”、右“23 / 48 个文件”，
//   下面 `AppUpdateProgressBar`，再下一行“已传 / 总量 · 速度”；
// - 其余情况（连接、比对、合并，或没有媒体）：阶段文字（“正在比对…”
//   等）+ 24dp 不定进度 `ExpressiveLoadingIndicator`。
// 合并阶段即使这次传过媒体也换回不定进度：媒体已经传完，进度条停在满格
// 只会让人以为卡住了。读屏文字由会话面板统一给出，这里不另读。

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../settings/widgets/app_update_progress_bar.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../models/lan_sync_session_view.dart';
import 'lan_sync_labels.dart';

/// 是否显示媒体进度（见文件头注释）。会话面板的读屏百分比用同一判断。
bool lanSyncShowsMediaProgress(LanSyncSessionView session) =>
    session.stage == LanSyncSessionStage.transferring && session.hasMedia;

class LanSyncSessionProgress extends StatelessWidget {
  const LanSyncSessionProgress({super.key, required this.session});

  final LanSyncSessionView session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    const tabular = <FontFeature>[FontFeature.tabularFigures()];
    final caption = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: colors.onSurfaceVariant,
    );
    if (!lanSyncShowsMediaProgress(session)) {
      return Row(
        children: <Widget>[
          const ExpressiveLoadingIndicator(size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(lanSyncStageLabel(l10n, session.stage), style: caption),
          ),
        ],
      );
    }
    final bytes = session.bytesTotal > 0
        ? (session.bytesPerSecond > 0
              ? l10n.lanSyncMediaBytesSpeed(
                  l10n.formatByteSize(session.bytesDone),
                  l10n.formatByteSize(session.bytesTotal),
                  l10n.formatByteSize(session.bytesPerSecond),
                )
              : l10n.lanSyncMediaBytes(
                  l10n.formatByteSize(session.bytesDone),
                  l10n.formatByteSize(session.bytesTotal),
                ))
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.lanSyncMediaTransferring,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: caption,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.lanSyncMediaFiles(session.filesDone, session.filesTotal),
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                fontFeatures: tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppUpdateProgressBar(value: session.mediaProgress ?? 0),
        if (bytes != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(bytes, style: caption?.copyWith(fontFeatures: tabular)),
        ],
      ],
    );
  }
}
