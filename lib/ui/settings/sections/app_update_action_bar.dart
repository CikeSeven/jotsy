import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../models/app_update_state.dart';
import '../widgets/app_update_download_progress_view.dart';
import '../widgets/app_update_labels.dart';
import '../widgets/app_update_notice_box.dart';

/// 更新页底部固定的操作区，内容随阶段切换（`fast` 交叉淡入、高度平滑变化）：
///
/// - 检查中（含刚进入页面）：不显示操作；已是最新 / 检查失败：“检查更新”或“重试”；
/// - 有新版本：“下载并安装（大小）”，取消过则为“继续下载（已完成 N%）”，
///   下方“跳过此版本”；桌面（Windows / Linux）为“前往下载”（在浏览器里下载
///   本平台安装包）+ “在 GitHub 查看”发布页面 + “跳过此版本”；其余不能应用内
///   安装的情况（含新版本里没有本平台安装包）为“前往下载页面”；
/// - 下载中：已下载 / 总大小、速度、所用线路与进度条，“取消下载”；
/// - 校验中：等待指示；
/// - 待安装：“安装”；未允许安装未知应用时说明原因并提供“去设置”；
/// - 下载 / 安装失败：错误说明块，可重试时“重试”，并始终提供下载页面。
class AppUpdateActionBar extends StatelessWidget {
  const AppUpdateActionBar({
    super.key,
    required this.state,
    required this.onCheck,
    required this.onDownload,
    required this.onCancelDownload,
    required this.onInstall,
    required this.onGrantInstallPermission,
    required this.onOpenReleasePage,
    required this.onOpenDesktopDownload,
    required this.onSkip,
  });

  final AppUpdateState state;
  final VoidCallback onCheck;
  final VoidCallback onDownload;
  final VoidCallback onCancelDownload;
  final VoidCallback onInstall;
  final VoidCallback onGrantInstallPermission;
  final VoidCallback onOpenReleasePage;

  /// 桌面：在浏览器里打开本平台安装包的下载地址。
  final VoidCallback onOpenDesktopDownload;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = _buildContent(context);
    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
            switchInCurve: ExpressiveMotion.effects,
            switchOutCurve: ExpressiveMotion.exit,
            child: content == null
                ? const SizedBox(
                    key: ValueKey<String>('empty'),
                    width: double.infinity,
                  )
                : Padding(
                    key: ValueKey<Object>(_contentKey),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.l,
                      AppSpacing.m,
                      AppSpacing.l,
                      AppSpacing.l,
                    ),
                    child: content,
                  ),
          ),
        ),
      ),
    );
  }

  /// 同一阶段内（如下载进度刷新）不重新淡入。
  Object get _contentKey =>
      (state.phase, state.awaitingInstallPermission, state.failure?.stage);

  Widget? _buildContent(BuildContext context) {
    final l10n = context.l10n;
    switch (state.phase) {
      // 页面进入时 idle 会立即开始检查，不先闪出“检查更新”按钮。
      case AppUpdatePhase.idle || AppUpdatePhase.checking:
        return null;
      case AppUpdatePhase.upToDate:
        return _wide(
          FilledButton.tonal(
            onPressed: onCheck,
            child: Text(l10n.appUpdateActionCheck),
          ),
        );
      case AppUpdatePhase.available:
        return _buildAvailable(context);
      case AppUpdatePhase.downloading:
        return AppUpdateDownloadProgressView(
          state: state,
          onCancel: onCancelDownload,
        );
      case AppUpdatePhase.verifying:
        return _WaitingRow(label: l10n.appUpdateVerifying);
      case AppUpdatePhase.readyToInstall:
        return _buildReady(context);
      case AppUpdatePhase.failed:
        return _buildFailed(context);
    }
  }

  Widget _buildAvailable(BuildContext context) {
    final l10n = context.l10n;
    if (state.desktopTarget != null && state.desktopAsset != null) {
      return _buildDesktopAvailable(context);
    }
    final asset = state.asset;
    if (!state.supportsInAppInstall || asset == null) {
      return _wide(
        FilledButton.icon(
          onPressed: onOpenReleasePage,
          icon: const FaIcon(FontAwesomeIcons.arrowUpRightFromSquare, size: 14),
          label: Text(l10n.appUpdateActionOpenReleasePage),
        ),
      );
    }
    final resumed = state.progress?.fraction;
    final size = asset.size;
    final label = resumed != null && resumed > 0
        ? l10n.appUpdateActionResume((resumed * 100).floor())
        : size == null
        ? l10n.appUpdateActionDownloadNoSize
        : l10n.appUpdateActionDownload(l10n.formatByteSize(size));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FilledButton.icon(
          onPressed: onDownload,
          icon: const FaIcon(FontAwesomeIcons.download, size: 14),
          label: Text(label),
        ),
        if (!state.isSkipped) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            child: Text(l10n.appUpdateActionSkip),
          ),
        ],
      ],
    );
  }

  /// 桌面：不在应用内下载，“前往下载”交给浏览器；发布页面作为次要入口
  /// （便携版等其他安装包也在那里）。
  Widget _buildDesktopAvailable(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FilledButton.icon(
          onPressed: onOpenDesktopDownload,
          icon: const FaIcon(FontAwesomeIcons.download, size: 14),
          label: Text(l10n.appUpdateActionDesktopDownload),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: onOpenReleasePage,
          child: Text(l10n.appUpdateViewOnGitHub),
        ),
        if (!state.isSkipped)
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            child: Text(l10n.appUpdateActionSkip),
          ),
      ],
    );
  }

  Widget _buildReady(BuildContext context) {
    final l10n = context.l10n;
    if (state.awaitingInstallPermission) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppUpdateNoticeBox(
            icon: FontAwesomeIcons.shieldHalved,
            title: l10n.appUpdateInstallPermissionTitle,
            message: l10n.appUpdateInstallPermissionMessage,
          ),
          const SizedBox(height: AppSpacing.m),
          FilledButton(
            onPressed: onGrantInstallPermission,
            child: Text(l10n.appUpdateInstallPermissionAction),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            FaIcon(
              FontAwesomeIcons.circleCheck,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                l10n.appUpdateReadyToInstall,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        FilledButton.icon(
          onPressed: onInstall,
          icon: const FaIcon(FontAwesomeIcons.boxOpen, size: 14),
          label: Text(l10n.appUpdateActionInstall),
        ),
      ],
    );
  }

  Widget _buildFailed(BuildContext context) {
    final l10n = context.l10n;
    final failure = state.failure;
    if (failure == null || failure.stage == AppUpdateStage.check) {
      // 检查失败的说明已在状态卡片里，这里只给重试。
      return _wide(
        FilledButton.tonal(
          onPressed: onCheck,
          child: Text(l10n.appUpdateActionRetry),
        ),
      );
    }
    final retryable = appUpdateFailureRetryable(failure.kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppUpdateNoticeBox(
          icon: FontAwesomeIcons.triangleExclamation,
          title: appUpdateFailureTitle(l10n, failure),
          message: appUpdateFailureMessage(l10n, failure.kind),
          error: true,
        ),
        const SizedBox(height: AppSpacing.m),
        if (retryable) ...<Widget>[
          FilledButton(
            onPressed: onCheck,
            child: Text(l10n.appUpdateActionRetry),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: onOpenReleasePage,
            child: Text(l10n.appUpdateActionOpenReleasePage),
          ),
        ] else
          FilledButton(
            onPressed: onOpenReleasePage,
            child: Text(l10n.appUpdateActionOpenReleasePage),
          ),
      ],
    );
  }

  static Widget _wide(Widget button) =>
      SizedBox(width: double.infinity, child: button);
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const ExpressiveLoadingIndicator(size: 28),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
