import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../models/app_update_state.dart';
import '../widgets/external_link.dart';
import '../widgets/release_notes_view.dart';
import '../widgets/settings_card_group.dart';

/// 更新说明卡片：有新版本时显示“更新内容”，已是最新时显示本版本的说明；
/// 标题右侧可在浏览器打开 Release 页面。说明按界面语言选取（见
/// `AppUpdateRelease.notesFor`）。没有可显示的版本时不占位。
class AppUpdateNotesSection extends StatelessWidget {
  const AppUpdateNotesSection({super.key, required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final release = state.release;
    final installed = state.installed;
    if (release == null || installed == null) {
      return const SizedBox.shrink();
    }
    final sameVersion = release.version.compareTo(installed.version) == 0;
    if (!state.hasUpdate && !sameVersion) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final notes = release.notesFor(l10n.isZh ? 'zh' : 'en');
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.l),
      child: SettingsCardGroup(
        title: state.hasUpdate
            ? l10n.appUpdateReleaseNotesTitle
            : l10n.appUpdateCurrentNotesTitle,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: notes == null
                ? Text(
                    l10n.appUpdateNoReleaseNotes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : ReleaseNotesView(
                    markdown: notes,
                    onOpenLink: (url) => openExternalLink(context, url),
                  ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                0,
                0,
                AppSpacing.s,
                AppSpacing.s,
              ),
              child: TextButton.icon(
                onPressed: () =>
                    openExternalLink(context, release.pageUrl.toString()),
                icon: const FaIcon(FontAwesomeIcons.github, size: 14),
                label: Text(l10n.appUpdateViewOnGitHub),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
