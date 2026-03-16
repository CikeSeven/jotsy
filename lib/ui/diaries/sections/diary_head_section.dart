import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';

/// 顶部排序模式。
enum DiarySortMode { updatedDesc, updatedAsc, titleAsc }

/// 日记列表布局模式。
enum DiaryLayoutMode { list, waterfall }

/// 顶部菜单动作枚举（排序 + 布局）。
enum DiaryMenuAction {
  sortUpdatedDesc,
  sortUpdatedAsc,
  sortTitleAsc,
  layoutList,
  layoutWaterfall,
}

/// 日记页顶部头部区块。
///
/// 布局职责：
/// - 左侧展示页面标题或多选计数；
/// - 右侧展示操作按钮（取消选择、归档、删除、归档列表入口）。
class DiaryHeadSection extends StatelessWidget {
  // ==================== 头部过渡动画常量 ====================
  static const double _headerContentHeight = 48;
  static const double _searchPreviewHeight = 36;

  const DiaryHeadSection({
    super.key,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.onCancelSelection,
    required this.isPinActionUnpin,
    required this.onPinSelected,
    required this.onArchiveSelected,
    required this.onDeleteSelected,
    required this.onOpenArchived,
    required this.sortMode,
    required this.layoutMode,
    required this.onMenuSelected,
    required this.onOpenSearchPage,
  });

  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback onCancelSelection;
  final bool isPinActionUnpin;
  final VoidCallback onPinSelected;
  final VoidCallback onArchiveSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onOpenArchived;
  final DiarySortMode sortMode;
  final DiaryLayoutMode layoutMode;
  final ValueChanged<DiaryMenuAction> onMenuSelected;
  final VoidCallback onOpenSearchPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.xs,
        AppSpacing.l,
        0,
      ),
      child: SizedBox(
        height: _headerContentHeight,
        child: Row(
          children: [
            // 多选模式：显示批量操作按钮组。
            if (isSelectionMode) ...[
              Expanded(
                child: Text(
                  'Jotsy',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonCancel,
                onPressed: onCancelSelection,
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
              ),
              IconButton(
                onPressed: onPinSelected,
                icon: FaIcon(
                  isPinActionUnpin
                      ? FontAwesomeIcons.thumbtackSlash
                      : FontAwesomeIcons.thumbtack,
                  size: 18,
                ),
              ),
              IconButton(
                tooltip: context.l10n.autoT0140,
                onPressed: onArchiveSelected,
                icon: const FaIcon(FontAwesomeIcons.boxArchive, size: 18),
              ),
              IconButton(
                tooltip: context.l10n.commonDelete,
                onPressed: onDeleteSelected,
                icon: FaIcon(
                  FontAwesomeIcons.trashCan,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ] else ...[
              // 普通模式：标题、搜索预览、右侧操作区三段布局。
              Text(
                'Jotsy',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: _SearchPreview(
                  key: const ValueKey<String>('search_preview'),
                  height: _searchPreviewHeight,
                  onTap: onOpenSearchPage,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              _AnimatedTrailingActions(
                onOpenArchived: onOpenArchived,
                onOpenSettings: () => _showSettingsSheet(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 打开排序与布局设置底部面板。
  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.l,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.arrowDownWideShort,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      context.l10n.autoT0141,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _ActionTile(
                  label: context.l10n.autoT0142,
                  selected: sortMode == DiarySortMode.updatedDesc,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.sortUpdatedDesc);
                  },
                ),
                _ActionTile(
                  label: context.l10n.autoT0143,
                  selected: sortMode == DiarySortMode.updatedAsc,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.sortUpdatedAsc);
                  },
                ),
                _ActionTile(
                  label: context.l10n.autoT0144,
                  selected: sortMode == DiarySortMode.titleAsc,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.sortTitleAsc);
                  },
                ),
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.tableCellsLarge,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      context.l10n.autoT0145,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _ActionTile(
                  label: context.l10n.autoT0146,
                  selected: layoutMode == DiaryLayoutMode.list,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.layoutList);
                  },
                ),
                _ActionTile(
                  label: context.l10n.autoT0147,
                  selected: layoutMode == DiaryLayoutMode.waterfall,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.layoutWaterfall);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchPreview extends StatelessWidget {
  const _SearchPreview({super.key, required this.height, required this.onTap});

  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 未进入搜索页时展示的“可点击搜索预览条”。
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.nav),
        boxShadow: AppEffects.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.nav),
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.nav),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.nav),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 17,
                      sigmaY: 17,
                      tileMode: TileMode.mirror,
                    ),
                    child: Container(
                      color: colorScheme.primary.withAlpha(20),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.magnifyingGlass,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.autoT0129,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedTrailingActions extends StatelessWidget {
  const _AnimatedTrailingActions({
    required this.onOpenArchived,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenArchived;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.l10n.autoT0148,
          onPressed: onOpenArchived,
          icon: const FaIcon(FontAwesomeIcons.boxArchive, size: 18),
        ),
        IconButton(
          tooltip: context.l10n.autoT0125,
          onPressed: onOpenSettings,
          icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      minLeadingWidth: 28,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      onTap: onTap,
      leading: FaIcon(
        selected ? FontAwesomeIcons.circleDot : FontAwesomeIcons.circle,
        size: 16,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(label),
    );
  }
}
