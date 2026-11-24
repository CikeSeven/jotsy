import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../viewmodels/storage_duplicates_view.dart';
import '../viewmodels/storage_labels.dart';
import '../viewmodels/storage_media_view.dart';
import '../widgets/storage_media_thumb.dart';
import '../widgets/storage_media_tile.dart';

/// 重复文件页的一组：组头是这份内容的缩略图、来自哪里、“N 份相同 · 每份 X
/// · 可释放 Y”与“合并”；下面逐行列出每份副本用在哪里，保留的那份标
/// “保留”，不能并过去的标“不能合并”。点按一行打开与媒体页同一个详情面板。
class StorageDuplicateGroupCard extends StatelessWidget {
  const StorageDuplicateGroupCard({
    super.key,
    required this.view,
    required this.onMerge,
    required this.onOpen,
  });

  static const double _thumbnailSize = 56;

  final StorageDuplicateGroupView view;

  /// 为 null 时按钮停用（正在执行）。
  final VoidCallback? onMerge;
  final ValueChanged<StorageMediaItemView> onOpen;

  @override
  Widget build(BuildContext context) {
    return SettingsCardGroup(
      children: <Widget>[
        _header(context),
        for (final item in view.members) _member(context, item),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final group = view.group;
    final preview = view.preview;
    // 标题取第一份没打码的副本的来处：保留的那份可能只在私密日记里。
    final titled = view.members.where((item) => !item.masked).firstOrNull;
    final title = titled == null
        ? storageMediaTitle(l10n, preview.entry, masked: true)
        : storageMediaTitle(l10n, titled.entry, masked: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.m),
            child: SizedBox.square(
              dimension: _thumbnailSize,
              child: StorageMediaThumb(
                entry: preview.entry,
                masked: preview.masked,
                extent: _thumbnailSize,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: titled == null ? scheme.onSurfaceVariant : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.storageMgmtDuplicateGroupSubtitle(
                    group.members.length,
                    l10n.formatByteSize(group.keeper.bytes),
                    l10n.formatByteSize(group.savedBytes),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          TextButton(onPressed: onMerge, child: Text(l10n.storageMgmtMerge)),
        ],
      ),
    );
  }

  Widget _member(BuildContext context, StorageMediaItemView item) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = item.entry;
    final firstRef = entry.refs.firstOrNull;
    final badge = view.isKept(item)
        ? (
            l10n.storageMgmtDuplicateKept,
            scheme.primaryContainer,
            scheme.onPrimaryContainer,
          )
        : view.isRetained(item)
        ? (
            l10n.storageMgmtDuplicateRetained,
            scheme.surfaceContainerHighest,
            scheme.onSurfaceVariant,
          )
        : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      minLeadingWidth: 24,
      leading: SizedBox(
        width: 24,
        child: Center(
          child: FaIcon(
            item.masked || firstRef == null
                ? FontAwesomeIcons.lock
                : storageRefIcon(firstRef),
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        storageMediaTitle(l10n, entry, masked: item.masked),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: item.masked ? scheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Text(
        <String>[
          storageMediaDetails(l10n, item),
          if (entry.refs.length > 1)
            l10n.storageMgmtBadgeUsedIn(entry.refs.length),
        ].where((part) => part.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: badge == null
          ? FaIcon(
              FontAwesomeIcons.angleRight,
              size: 14,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            )
          : StorageBadge(
              label: badge.$1,
              background: badge.$2,
              foreground: badge.$3,
            ),
      onTap: () => onOpen(item),
    );
  }
}
