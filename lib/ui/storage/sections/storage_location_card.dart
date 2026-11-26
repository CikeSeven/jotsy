import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_data_location.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';

/// 桌面端存储管理页的“数据存储位置”卡片：展示当前根目录、打开文件夹、
/// 更改路径并迁移，以及恢复默认位置。
class StorageLocationCard extends StatelessWidget {
  const StorageLocationCard({
    super.key,
    required this.resolution,
    required this.busy,
    required this.onOpenFolder,
    required this.onChangeLocation,
    this.onResetDefault,
  });

  final AppDataLocationResolution resolution;
  final bool busy;
  final VoidCallback onOpenFolder;
  final VoidCallback onChangeLocation;
  final VoidCallback? onResetDefault;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badgeText = resolution.isPortableConfig
        ? l10n.storageLocationPortableBadge
        : resolution.isCustomLocation
        ? l10n.storageLocationCustomBadge
        : l10n.storageLocationDefaultBadge;
    final badgeBg = resolution.isPortableConfig
        ? scheme.tertiaryContainer
        : resolution.isCustomLocation
        ? scheme.primaryContainer
        : scheme.secondaryContainer;
    final badgeFg = resolution.isPortableConfig
        ? scheme.onTertiaryContainer
        : resolution.isCustomLocation
        ? scheme.onPrimaryContainer
        : scheme.onSecondaryContainer;

    return AppCardSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              FaIcon(
                FontAwesomeIcons.folderOpen,
                size: 15,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  l10n.storageLocationTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s + 2,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    badgeText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: badgeFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          DecoratedBox(
            decoration: BoxDecoration(
              color:
                  AppGlassField.of(context)?.fill ??
                  scheme.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(AppRadii.input),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.m,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SelectableText(
                  resolution.activeRoot.path,
                  contextMenuBuilder: appTextContextMenuBuilder,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            l10n.storageLocationDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: busy ? null : onOpenFolder,
                icon: const FaIcon(
                  FontAwesomeIcons.arrowUpRightFromSquare,
                  size: 13,
                ),
                label: Text(l10n.storageLocationOpenFolder),
              ),
              FilledButton.tonalIcon(
                style: AppGlassField.tonalButtonStyle(context),
                onPressed: busy ? null : onChangeLocation,
                icon: const FaIcon(FontAwesomeIcons.folderTree, size: 13),
                label: Text(l10n.storageLocationChangeButton),
              ),
              if (onResetDefault != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  onPressed: busy ? null : onResetDefault,
                  icon: const FaIcon(FontAwesomeIcons.rotateLeft, size: 13),
                  label: Text(l10n.storageLocationResetDefault),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
