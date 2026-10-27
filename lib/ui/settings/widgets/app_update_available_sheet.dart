import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_update_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import 'app_update_badge.dart';
import 'app_update_labels.dart';
import 'external_link.dart';
import 'release_notes_view.dart';

/// 启动时发现新版本的选择。
enum AppUpdatePromptAction { update, later, skip }

/// 自动检查发现新版本时的提示面板：版本号、当前版本、发布日期与
/// 大小，以及按界面语言选取的更新说明（面板内滚动）。底部“立即更新”
/// 为主操作（[desktop] 为 true 时是“前往下载”，在浏览器里下载桌面安装包），
/// “跳过此版本”“以后再说”为次要文本按钮。点遮罩关闭视为“以后再说”。
Future<AppUpdatePromptAction> showAppUpdateAvailableSheet(
  BuildContext context, {
  required AppUpdateRelease release,
  required AppVersion installed,
  AppUpdateAsset? asset,
  bool desktop = false,
}) async {
  final action = await showAppModalBottomSheet<AppUpdatePromptAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * 0.82,
    ),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => _AppUpdateAvailableSheet(
      release: release,
      installed: installed,
      asset: asset,
      desktop: desktop,
    ),
  );
  return action ?? AppUpdatePromptAction.later;
}

class _AppUpdateAvailableSheet extends StatelessWidget {
  const _AppUpdateAvailableSheet({
    required this.release,
    required this.installed,
    required this.asset,
    required this.desktop,
  });

  final AppUpdateRelease release;
  final AppVersion installed;
  final AppUpdateAsset? asset;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notes = release.notesFor(l10n.isZh ? 'zh' : 'en');
    final published = release.publishedAt;
    final size = asset?.size;
    final meta = <String>[
      l10n.appUpdateCurrentVersion(appVersionLabel(installed)),
      if (published != null)
        l10n.appUpdatePublishedOn(l10n.formatFullDate(published)),
      if (size != null) l10n.formatByteSize(size),
    ];
    void close(AppUpdatePromptAction action) =>
        Navigator.of(context).pop(action);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.m,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppUpdateBadge(),
              const SizedBox(height: AppSpacing.s),
              Text(
                l10n.appUpdateAvailableTitle('v${release.version.name}'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                meta.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: notes == null
                ? Text(
                    l10n.appUpdateNoReleaseNotes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : ReleaseNotesView(
                    markdown: notes,
                    onOpenLink: (url) => openExternalLink(context, url),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.l,
            AppSpacing.xl,
            AppSpacing.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FilledButton(
                onPressed: () => close(AppUpdatePromptAction.update),
                child: Text(
                  desktop
                      ? l10n.appUpdateActionDesktopDownload
                      : l10n.appUpdatePromptUpdate,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: () => close(AppUpdatePromptAction.skip),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                      child: Text(l10n.appUpdateActionSkip),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => close(AppUpdatePromptAction.later),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                      child: Text(l10n.appUpdatePromptLater),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
