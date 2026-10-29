// 配对面板各阶段的内容（DESIGN.md §5.27“配对面板”）：连接中、核对码、
// 成功、失败。只负责画与转发点按；阶段切换、交叉淡入与确认流程在
// lan_sync_pairing_sheet.dart。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../models/lan_sync_platform.dart';
import '../models/lan_sync_session_view.dart';
import 'lan_sync_labels.dart';
import 'lan_sync_pairing_code.dart';
import 'lan_sync_pairing_parts.dart';
import 'lan_sync_success_badge.dart';

TextStyle? _titleStyle(ThemeData theme) => theme.textTheme.headlineSmall
    ?.copyWith(fontSize: 22, fontWeight: FontWeight.w800);

TextStyle? _captionStyle(ThemeData theme, double size) => theme
    .textTheme
    .bodyMedium
    ?.copyWith(fontSize: size, color: theme.colorScheme.onSurfaceVariant);

/// 连接中：加载指示 +“正在连接 X…”。
class LanSyncPairingConnectingBody extends StatelessWidget {
  const LanSyncPairingConnectingBody({super.key, required this.peerName});

  final String peerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = context.l10n.lanSyncPairConnecting(peerName);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExpressiveLoadingIndicator(size: 48, semanticLabel: text),
          const SizedBox(height: 16),
          ExcludeSemantics(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: _captionStyle(theme, 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// 核对码阶段：插图、标题、核对码、安全说明与按钮区。
///
/// [waitingPeer] 为 true（本机已确认）时按钮区交叉淡入为“等待对方确认…”。
/// [busy] 为 true（正在验证身份 / 提交确认）时两枚按钮不可点，避免连点。
class LanSyncPairingCodeBody extends StatelessWidget {
  const LanSyncPairingCodeBody({
    super.key,
    required this.title,
    required this.code,
    required this.localPlatform,
    required this.peerPlatform,
    required this.waitingPeer,
    required this.busy,
    required this.hint,
    required this.onMismatch,
    required this.onConfirm,
    required this.onExportBackup,
  });

  final String title;
  final String code;
  final LanSyncPlatform localPlatform;
  final LanSyncPlatform peerPlatform;
  final bool waitingPeer;
  final bool busy;

  /// 按钮上方的一行 `error` 色提示（身份验证没有通过等）；null 不显示。
  final String? hint;
  final VoidCallback onMismatch;
  final VoidCallback onConfirm;
  final VoidCallback onExportBackup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final hint = this.hint;
    final Widget actions = waitingPeer
        ? SizedBox(
            key: const ValueKey<String>('waiting'),
            height: 52,
            child: Center(
              child: Text(
                l10n.lanSyncPairWaitingPeer,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          )
        : Row(
            key: const ValueKey<String>('buttons'),
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: busy ? null : onMismatch,
                  child: Text(l10n.lanSyncPairMismatch),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: busy ? null : onConfirm,
                  child: Text(l10n.lanSyncPairConfirm),
                ),
              ),
            ],
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: LanSyncPairingIllustration(
            localPlatform: localPlatform,
            peerPlatform: peerPlatform,
          ),
        ),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: _titleStyle(theme)),
        const SizedBox(height: 6),
        Text(
          l10n.lanSyncPairSubtitle,
          textAlign: TextAlign.center,
          style: _captionStyle(theme, 14),
        ),
        const SizedBox(height: 24),
        Center(child: LanSyncPairingCode(code: code)),
        const SizedBox(height: 24),
        LanSyncPairingSafetyNote(
          onExportBackup: waitingPeer ? null : onExportBackup,
        ),
        const SizedBox(height: 20),
        if (hint != null) ...<Widget>[
          Text(
            hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
        ],
        AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          child: actions,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.lanSyncPairTimeoutNote,
          textAlign: TextAlign.center,
          style: _captionStyle(theme, 12),
        ),
      ],
    );
  }
}

/// 成功：十二瓣饼干形对勾、“已与 X 配对”、填充“立即同步”与文本“稍后”。
class LanSyncPairingSuccessBody extends StatelessWidget {
  const LanSyncPairingSuccessBody({
    super.key,
    required this.peerName,
    required this.onSyncNow,
    required this.onLater,
  });

  final String peerName;
  final VoidCallback onSyncNow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
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
            l10n.lanSyncPairSucceeded(peerName),
            textAlign: TextAlign.center,
            style: _titleStyle(theme),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: onSyncNow,
          child: Text(l10n.lanSyncPairSyncNow),
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: onLater,
          child: Text(l10n.lanSyncPairLater),
        ),
      ],
    );
  }
}

/// 失败：`error` 色 `circleExclamation`、标题、原因与“关闭”。
class LanSyncPairingFailureBody extends StatelessWidget {
  const LanSyncPairingFailureBody({
    super.key,
    required this.reason,
    required this.onClose,
  });

  final LanSyncFailureReason reason;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final base = FilledButton.styleFrom(minimumSize: const Size(0, 52));
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
          l10n.lanSyncPairFailedTitle,
          textAlign: TextAlign.center,
          style: _titleStyle(theme),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            lanSyncPairingFailureText(l10n, reason),
            textAlign: TextAlign.center,
            style: _captionStyle(theme, 14),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.tonal(
          style: AppGlassField.tonalButtonStyle(context)?.merge(base) ?? base,
          onPressed: onClose,
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
