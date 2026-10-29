import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../models/changelog_entry.dart';
import 'release_notes_view.dart';
import 'settings_reveal.dart';

/// 更新日志里一个版本的卡片：版本号（本机安装的版本带“当前版本”胶囊）、
/// 常显的要点，以及展开后接在要点下面的其余章节。
///
/// 无状态：展开与否由页面按 tag 记录并传入，卡片滑出屏幕被回收后再滑回
/// 仍保持原样。其余章节经 [SettingsReveal] 随高度展开收起；没有其余章节时
/// 不显示“展开全部”。
class ChangelogEntryCard extends StatelessWidget {
  const ChangelogEntryCard({
    super.key,
    required this.entry,
    required this.current,
    required this.expanded,
    required this.onToggle,
    this.onOpenLink,
  });

  final ChangelogEntry entry;

  /// 是否为本机安装的版本。
  final bool current;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String>? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AppCardSurface(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.xl,
        entry.hasDetails ? AppSpacing.xs : AppSpacing.l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    entry.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              if (current) const _CurrentVersionBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          ReleaseNotesView(markdown: entry.highlights, onOpenLink: onOpenLink),
          if (entry.hasDetails) ...<Widget>[
            SettingsReveal(
              visible: expanded,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: ReleaseNotesView(
                  markdown: entry.details,
                  onOpenLink: onOpenLink,
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onToggle,
                iconAlignment: IconAlignment.end,
                icon: FaIcon(
                  expanded
                      ? FontAwesomeIcons.angleUp
                      : FontAwesomeIcons.angleDown,
                  size: 14,
                ),
                label: Text(
                  expanded ? l10n.changelogCollapse : l10n.changelogShowAll,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// “当前版本”小胶囊：与“新版本”胶囊（`AppUpdateBadge`）同一尺寸，改用
/// 次要容器色，避免与“有新版本”的强提示混淆。
class _CurrentVersionBadge extends StatelessWidget {
  const _CurrentVersionBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.l10n.changelogCurrentVersion,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
