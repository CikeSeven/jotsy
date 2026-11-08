import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/storage/storage_usage_models.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../models/storage_media_filter.dart';
import '../viewmodels/storage_labels.dart';
import '../viewmodels/storage_overview_view.dart';

/// 总览页“可释放空间”分组：每条建议写明能省多少，就地清理或跳到要处理的
/// 地方。为 0 的建议不出现；全部为 0 时只留一行“已经很整洁了”。
class StorageSuggestionsGroup extends StatelessWidget {
  const StorageSuggestionsGroup({
    super.key,
    required this.view,
    required this.onClearCache,
    required this.onClearUnused,
    required this.onCompactDatabase,
    required this.onOpenTrash,
    required this.onOpenCompressible,
  });

  final StorageOverviewView view;

  /// 为 null 时按钮停用（正在执行）。
  final VoidCallback? onClearCache;
  final VoidCallback? onClearUnused;
  final VoidCallback? onCompactDatabase;
  final VoidCallback onOpenTrash;

  /// 为 null 时不提供压缩（平台不支持）。
  final VoidCallback? onOpenCompressible;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final report = view.report;
    final size = l10n.formatByteSize;
    final rows = <Widget>[
      if (report.clearableCacheBytes > 0)
        _SuggestionTile(
          icon: FontAwesomeIcons.boxArchive,
          title: l10n.storageMgmtSuggestCache,
          subtitle: l10n.storageMgmtSuggestCacheSubtitle(
            size(report.clearableCacheBytes),
          ),
          actionLabel: l10n.storageMgmtClear,
          onAction: onClearCache,
        ),
      if (report.clearableOrphanBytes > 0)
        _SuggestionTile(
          icon: FontAwesomeIcons.fileCircleXmark,
          title: l10n.storageMgmtSuggestUnused,
          subtitle: l10n.storageMgmtSuggestUnusedSubtitle(
            report.clearableOrphanFiles,
            size(report.clearableOrphanBytes),
          ),
          actionLabel: l10n.storageMgmtClear,
          onAction: onClearUnused,
        ),
      if (view.trash.count > 0)
        _SuggestionTile(
          icon: FontAwesomeIcons.trashCan,
          title: l10n.storageMgmtSuggestTrash,
          subtitle: l10n.storageMgmtSuggestTrashSubtitle(
            view.trash.count,
            size(view.trash.bytes),
          ),
          onTap: onOpenTrash,
        ),
      if (onOpenCompressible != null && view.compressible.count > 0)
        _SuggestionTile(
          icon: FontAwesomeIcons.compress,
          title: l10n.storageMgmtSuggestCompress,
          subtitle: l10n.storageMgmtSuggestCompressSubtitle(
            view.compressible.count,
            size(view.compressibleSaving),
          ),
          onTap: onOpenCompressible,
        ),
      if (report.compactableDatabaseBytes > 0)
        _SuggestionTile(
          icon: FontAwesomeIcons.database,
          title: l10n.storageMgmtSuggestDatabase,
          subtitle: l10n.storageMgmtSuggestDatabaseSubtitle(
            size(report.compactableDatabaseBytes),
          ),
          actionLabel: l10n.storageMgmtCompact,
          onAction: onCompactDatabase,
        ),
    ];
    return SettingsCardGroup(
      title: l10n.storageMgmtSuggestionsTitle,
      children: rows.isEmpty
          ? <Widget>[
              _SuggestionTile(
                icon: FontAwesomeIcons.circleCheck,
                title: l10n.storageMgmtAllClean,
                subtitle: l10n.storageMgmtAllCleanSubtitle,
              ),
            ]
          : rows,
    );
  }
}

/// 总览页“媒体文件”分组：各类媒体与大文件的数量和大小，点按进媒体页。
class StorageMediaGroup extends StatelessWidget {
  const StorageMediaGroup({
    super.key,
    required this.view,
    required this.onOpen,
  });

  final StorageOverviewView view;
  final ValueChanged<StorageMediaFilter> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = view.report.media;
    final allBytes = all.fold<int>(0, (sum, entry) => sum + entry.bytes);
    return SettingsCardGroup(
      title: l10n.storageMgmtMediaTitle,
      children: <Widget>[
        SettingsNavTile(
          icon: FontAwesomeIcons.photoFilm,
          title: l10n.storageMgmtAllMedia,
          subtitle: l10n.storageMgmtFileCount(all.length),
          value: l10n.formatByteSize(allBytes),
          onTap: () => onOpen(const StorageMediaFilter()),
        ),
        for (final category in StorageMediaFilter.categories)
          if ((view.media[category]?.count ?? 0) > 0)
            SettingsNavTile(
              icon: category.icon,
              title: category.label(l10n),
              subtitle: l10n.storageMgmtFileCount(view.media[category]!.count),
              value: l10n.formatByteSize(view.media[category]!.bytes),
              onTap: () => onOpen(StorageMediaFilter(category: category)),
            ),
        if (view.large.count > 0)
          SettingsNavTile(
            icon: FontAwesomeIcons.weightHanging,
            title: l10n.storageMgmtLargeFiles,
            subtitle: l10n.storageMgmtLargeFilesSubtitle(view.large.count),
            value: l10n.formatByteSize(view.large.bytes),
            onTap: () => onOpen(const StorageMediaFilter(largeOnly: true)),
          ),
      ],
    );
  }
}

/// 总览页“其他数据”分组：背景图（点按进背景设置）、字体、日记数据库、
/// 其他。只列有内容的；页尾写明删除与压缩对同步、备份的影响。
class StorageOtherGroup extends StatelessWidget {
  const StorageOtherGroup({
    super.key,
    required this.view,
    required this.onOpenBackgrounds,
  });

  final StorageOverviewView view;
  final VoidCallback onOpenBackgrounds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final report = view.report;
    Widget info(StorageCategory category, {VoidCallback? onTap}) {
      final bytes = l10n.formatByteSize(report.bytesOf(category));
      if (onTap != null) {
        return SettingsNavTile(
          icon: category.icon,
          title: category.label(l10n),
          value: bytes,
          onTap: onTap,
        );
      }
      return _SuggestionTile(
        icon: category.icon,
        title: category.label(l10n),
        trailingText: bytes,
      );
    }

    return SettingsCardGroup(
      title: l10n.storageMgmtOtherTitle,
      footer: l10n.storageMgmtFooter,
      children: <Widget>[
        if (report.bytesOf(StorageCategory.backgrounds) > 0)
          info(StorageCategory.backgrounds, onTap: onOpenBackgrounds),
        for (final category in const [
          StorageCategory.fonts,
          StorageCategory.database,
          StorageCategory.other,
        ])
          if (report.bytesOf(category) > 0) info(category),
      ],
    );
  }
}

/// 分组里的一行：与 [SettingsNavTile] 同样的图标块与排版；行尾为就地执行
/// 的文字按钮、跳转箭头或一段只读的大小。
class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.trailingText,
  });

  final FaIconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitle = this.subtitle;
    final actionLabel = this.actionLabel;
    final trailingText = this.trailingText;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      titleAlignment: ListTileTitleAlignment.center,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: FaIcon(icon, size: 16, color: colors.onPrimaryContainer),
      ),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: actionLabel != null
          ? TextButton(onPressed: onAction, child: Text(actionLabel))
          : trailingText != null
          ? Text(
              trailingText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          : onTap != null
          ? FaIcon(
              FontAwesomeIcons.angleRight,
              size: 14,
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
            )
          : null,
      onTap: onTap,
    );
  }
}
