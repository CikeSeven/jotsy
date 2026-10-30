// 同步完成摘要面板的三种内容（DESIGN.md §5.28“同步完成摘要”）：成功且有
// 变化、已经是最新、失败。只负责画与转发点按；选哪一种、关闭后做什么见
// lan_sync_summary_sheet.dart。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/lan_sync_session_summary.dart';
import '../models/lan_sync_session_view.dart';
import 'lan_sync_labels.dart';
import 'lan_sync_success_badge.dart';
import 'lan_sync_summary_parts.dart';

TextStyle? _titleStyle(ThemeData theme) => theme.textTheme.headlineSmall
    ?.copyWith(fontSize: 24, fontWeight: FontWeight.w800);

TextStyle? _captionStyle(ThemeData theme, double size) => theme
    .textTheme
    .bodyMedium
    ?.copyWith(fontSize: size, color: theme.colorScheme.onSurfaceVariant);

Widget _doneButton(BuildContext context, VoidCallback onDone) {
  return FilledButton(
    style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
    onPressed: onDone,
    child: Text(context.l10n.lanSyncSummaryDone),
  );
}

/// 成功且有变化：徽章、标题、用时、两列统计卡、冲突副本、脚注与“完成”。
/// 有日记以外的变化时，两列都多一行“其他”，脚注换成按种类的明细（两个
/// 方向相加）。
class LanSyncSummarySuccessBody extends StatelessWidget {
  const LanSyncSummarySuccessBody({
    super.key,
    required this.summary,
    required this.onOpenCopy,
    required this.onDone,
  });

  final LanSyncSessionSummary summary;
  final ValueChanged<String> onOpenCopy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final others = summary.received.others + summary.sent.others;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8),
        const Center(child: LanSyncSuccessBadge()),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.lanSyncSummaryTitle,
            textAlign: TextAlign.center,
            style: _titleStyle(theme),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.lanSyncSummarySubtitle(
            summary.peerName,
            lanSyncDurationSeconds(summary.duration),
          ),
          textAlign: TextAlign.center,
          style: _captionStyle(theme, 13),
        ),
        const SizedBox(height: 24),
        // 两列等高：一列媒体行折成两行时另一列跟着撑高，底边对齐。
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: LanSyncSummaryStatCard(
                  label: l10n.lanSyncSummaryReceived,
                  accent: colors.tertiary,
                  counts: summary.received,
                  showOthers: !others.isEmpty,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LanSyncSummaryStatCard(
                  label: l10n.lanSyncSummarySent,
                  accent: colors.primary,
                  counts: summary.sent,
                  showOthers: !others.isEmpty,
                ),
              ),
            ],
          ),
        ),
        if (summary.conflictCopies.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          LanSyncConflictCopies(
            copies: summary.conflictCopies,
            onOpen: onOpenCopy,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          others.isEmpty
              ? l10n.lanSyncSummaryFootnote
              : l10n.lanSyncSummaryOtherDetail(
                  lanSyncItemCountsText(l10n, others),
                ),
          textAlign: TextAlign.center,
          style: _captionStyle(theme, 13),
        ),
        const SizedBox(height: 24),
        _doneButton(context, onDone),
      ],
    );
  }
}

/// 两边都没变化：只有徽章、“已经是最新的了”与“完成”。
class LanSyncSummaryUpToDateBody extends StatelessWidget {
  const LanSyncSummaryUpToDateBody({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8),
        const Center(child: LanSyncSuccessBadge()),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Text(
            context.l10n.lanSyncSummaryUpToDate,
            textAlign: TextAlign.center,
            style: _titleStyle(theme),
          ),
        ),
        const SizedBox(height: 28),
        _doneButton(context, onDone),
      ],
    );
  }
}

/// 失败：`error` 色 `circleExclamation`、“同步没有完成”、原因与下一步、
/// “重试”与“关闭”。
class LanSyncSummaryFailureBody extends StatelessWidget {
  const LanSyncSummaryFailureBody({
    super.key,
    required this.reason,
    required this.onRetry,
    required this.onClose,
  });

  final LanSyncFailureReason reason;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8),
        Center(
          child: FaIcon(
            FontAwesomeIcons.circleExclamation,
            size: 40,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.lanSyncSummaryFailedTitle,
          textAlign: TextAlign.center,
          style: _titleStyle(theme),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            lanSyncSyncFailureText(l10n, reason),
            textAlign: TextAlign.center,
            style: _captionStyle(theme, 14),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: onRetry,
          child: Text(l10n.commonRetry),
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: onClose,
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
