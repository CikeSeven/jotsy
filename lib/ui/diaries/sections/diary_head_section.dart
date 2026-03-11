import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  static const Duration _modeTransitionDuration = Duration(milliseconds: 260);
  static const Duration _searchFieldSwitchDuration = Duration(milliseconds: 220);
  static const double _headerContentHeight = 48;
  static const double _searchPreviewHeight = 36;
  static const double _searchInputHeight = 44;

  const DiaryHeadSection({
    super.key,
    required this.isSelectionMode,
    required this.isSearchMode,
    required this.selectedCount,
    required this.onCancelSelection,
    required this.onArchiveSelected,
    required this.onDeleteSelected,
    required this.onOpenArchived,
    required this.sortMode,
    required this.layoutMode,
    required this.onMenuSelected,
    required this.searchPreviewText,
    required this.searchController,
    required this.searchFocusNode,
    required this.onEnterSearch,
    required this.onExitSearch,
    required this.onClearSearch,
    required this.onSearchChanged,
  });

  final bool isSelectionMode;
  final bool isSearchMode;
  final int selectedCount;
  final VoidCallback onCancelSelection;
  final VoidCallback onArchiveSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onOpenArchived;
  final DiarySortMode sortMode;
  final DiaryLayoutMode layoutMode;
  final ValueChanged<DiaryMenuAction> onMenuSelected;
  final String searchPreviewText;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onEnterSearch;
  final VoidCallback onExitSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final hasSearchText = searchPreviewText.trim().isNotEmpty;
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
                tooltip: '取消',
                onPressed: onCancelSelection,
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
              ),
              IconButton(
                tooltip: '归档',
                onPressed: onArchiveSelected,
                icon: const FaIcon(FontAwesomeIcons.boxArchive, size: 18),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: onDeleteSelected,
                icon: FaIcon(
                  FontAwesomeIcons.trashCan,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ] else ...[
              // 普通/搜索模式：标题、搜索区域、右侧操作区三段布局。
              AnimatedSize(
                duration: _modeTransitionDuration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: AnimatedOpacity(
                  duration: _modeTransitionDuration,
                  curve: Curves.easeOutCubic,
                  opacity: isSearchMode ? 0 : 1,
                  child:
                      isSearchMode
                          ? const SizedBox.shrink()
                          : Text(
                            'Jotsy',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                ),
              ),
              AnimatedContainer(
                duration: _modeTransitionDuration,
                curve: Curves.easeOutCubic,
                width: isSearchMode ? 0 : AppSpacing.xl,
              ),
              Expanded(
                child: AnimatedSwitcher(
                duration: _searchFieldSwitchDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  // 搜索态保持“向上进入”手感，同时避免整体头部被拉缩。
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0.03, 0.12),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offsetAnimation, child: child),
                  );
                },
                child:
                    isSearchMode
                        ? _SearchInput(
                          key: const ValueKey<String>('search_input'),
                          searchController: searchController,
                          searchFocusNode: searchFocusNode,
                          height: _searchInputHeight,
                          hasSearchText: hasSearchText,
                          onExitSearch: onExitSearch,
                          onClearSearch: onClearSearch,
                          onSearchChanged: onSearchChanged,
                        )
                        : _SearchPreview(
                          key: const ValueKey<String>('search_preview'),
                          searchPreviewText: searchPreviewText,
                          height: _searchPreviewHeight,
                          onTap: onEnterSearch,
                        ),
                ),
              ),
              AnimatedContainer(
                duration: _modeTransitionDuration,
                curve: Curves.easeOutCubic,
                width: isSearchMode ? 0 : AppSpacing.m,
              ),
              _AnimatedTrailingActions(
                visible: !isSearchMode,
                duration: _modeTransitionDuration,
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
                      '排序方式',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _ActionTile(
                  label: '最近更新',
                  selected: sortMode == DiarySortMode.updatedDesc,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.sortUpdatedDesc);
                  },
                ),
                _ActionTile(
                  label: '最早更新',
                  selected: sortMode == DiarySortMode.updatedAsc,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.sortUpdatedAsc);
                  },
                ),
                _ActionTile(
                  label: '标题 A-Z',
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
                      '显示布局',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _ActionTile(
                  label: '列表',
                  selected: layoutMode == DiaryLayoutMode.list,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onMenuSelected(DiaryMenuAction.layoutList);
                  },
                ),
                _ActionTile(
                  label: '瀑布流',
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
  const _SearchPreview({
    super.key,
    required this.searchPreviewText,
    required this.height,
    required this.onTap,
  });

  final String searchPreviewText;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hintStyle = Theme.of(context).textTheme.bodyMedium;
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    final displayedText = searchPreviewText.trim();
    final hasText = displayedText.isNotEmpty;

    // 未进入搜索态时展示的“可点击搜索预览条”。
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
                              hasText ? displayedText : '搜索标题或内容',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  hasText
                                      ? textStyle?.copyWith(color: colorScheme.onSurface)
                                      : hintStyle?.copyWith(
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

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.height,
    required this.hasSearchText,
    required this.onExitSearch,
    required this.onClearSearch,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final double height;
  final bool hasSearchText;
  final VoidCallback onExitSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 搜索态输入条：左侧返回、中央输入、右侧按需出现清空按钮。
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.nav),
        boxShadow: AppEffects.softShadow,
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '取消搜索',
                        splashRadius: 18,
                        onPressed: onExitSearch,
                        icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 16),
                      ),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          focusNode: searchFocusNode,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onChanged: onSearchChanged,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '搜索标题或内容',
                            border: InputBorder.none,
                            hintStyle: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child:
                            hasSearchText
                                ? IconButton(
                                  key: const ValueKey<String>('clear_search_button'),
                                  tooltip: '清空',
                                  splashRadius: 18,
                                  onPressed: onClearSearch,
                                  icon: const FaIcon(
                                    FontAwesomeIcons.xmark,
                                    size: 14,
                                  ),
                                )
                                : const SizedBox(
                                  key: ValueKey<String>('clear_search_placeholder'),
                                  width: 40,
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
    );
  }
}

class _AnimatedTrailingActions extends StatelessWidget {
  const _AnimatedTrailingActions({
    required this.visible,
    required this.duration,
    required this.onOpenArchived,
    required this.onOpenSettings,
  });

  final bool visible;
  final Duration duration;
  final VoidCallback onOpenArchived;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    // 通过 Size + Opacity 双通道动画，让右侧操作区在搜索态下平滑让位。
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      child: AnimatedOpacity(
        duration: duration,
        curve: Curves.easeOutCubic,
        opacity: visible ? 1 : 0,
        child:
            visible
                ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '已归档笔记',
                      onPressed: onOpenArchived,
                      icon: const FaIcon(FontAwesomeIcons.boxArchive, size: 18),
                    ),
                    IconButton(
                      tooltip: '更多',
                      onPressed: onOpenSettings,
                      icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
                    ),
                  ],
                )
                : const SizedBox.shrink(),
      ),
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
    // 设置弹层中的单行动作项（支持选中状态勾选）。
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: AppSpacing.l),
      onTap: onTap,
      title: Text(label),
      trailing: selected ? const FaIcon(FontAwesomeIcons.check, size: 16) : null,
    );
  }
}
