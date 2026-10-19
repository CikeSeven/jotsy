import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../widgets/expressive_icon_swap.dart';

/// 日记列表布局模式。
enum DiaryLayoutMode { list, waterfall }

/// 日记页顶部头部区块。
///
/// 布局职责：
/// - 普通态：搜索条占满左侧，右侧为草稿箱（有草稿时带份数角标）、归档列表
///   与视图选项入口；
/// - 多选态：左侧为已选数量，右侧为批量操作（取消、置顶、归档、导出、删除）。
class DiaryHeadSection extends StatelessWidget {
  // ==================== 头部过渡动画常量 ====================
  static const double _headerContentHeight = 52;
  static const double _searchPreviewHeight = 40;

  const DiaryHeadSection({
    super.key,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.onCancelSelection,
    required this.isPinActionUnpin,
    required this.onPinSelected,
    required this.onArchiveSelected,
    required this.onExportSelected,
    required this.onDeleteSelected,
    required this.onOpenArchived,
    required this.onOpenDrafts,
    required this.draftCount,
    required this.onOpenViewOptions,
    required this.onOpenSearchPage,
    this.searchHint,
  });

  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback onCancelSelection;
  final bool isPinActionUnpin;
  final VoidCallback onPinSelected;
  final VoidCallback onArchiveSelected;
  final VoidCallback onExportSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onOpenArchived;
  final VoidCallback onOpenDrafts;

  /// 草稿份数，大于 0 时草稿箱图标带角标。
  final int draftCount;

  /// 打开视图选项面板（排序与布局），面板由页面控制器负责呈现。
  final VoidCallback onOpenViewOptions;
  final VoidCallback onOpenSearchPage;

  /// 搜索条占位文字；null 时用默认文案（在日记本里时为“在「旅行」中搜索”）。
  final String? searchHint;

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
        // 普通态与多选态之间交叉淡入并轻微横移，避免长按进入多选时整行
        // 按钮硬切；两态各自以 key 区分，内部按钮状态互不复用。
        child: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[...previousChildren, ?currentChild],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: isSelectionMode
              ? _buildSelectionRow(context)
              : _buildDefaultRow(context),
        ),
      ),
    );
  }

  /// 多选态：已选数量 + 批量操作按钮组。
  Widget _buildSelectionRow(BuildContext context) {
    return Row(
      key: const ValueKey<String>('head_selection'),
      children: [
        Expanded(
          child: Text(
            context.l10n.autoT0099(selectedCount.toString()),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
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
          tooltip: isPinActionUnpin
              ? context.l10n.diaryUnpinSelected
              : context.l10n.diaryPinSelected,
          onPressed: onPinSelected,
          // 选中项全部已置顶时变为“取消置顶”：图标缩放淡入切换，而不是硬切。
          icon: ExpressiveIconSwap(
            switchKey: isPinActionUnpin,
            child: FaIcon(
              isPinActionUnpin
                  ? FontAwesomeIcons.thumbtackSlash
                  : FontAwesomeIcons.thumbtack,
              size: 18,
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.autoT0140,
          onPressed: onArchiveSelected,
          icon: const FaIcon(FontAwesomeIcons.boxArchive, size: 18),
        ),
        IconButton(
          tooltip: context.l10n.diaryExportSelected,
          onPressed: onExportSelected,
          icon: const FaIcon(FontAwesomeIcons.fileExport, size: 18),
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
      ],
    );
  }

  /// 普通态：搜索预览占满左侧，右侧为操作区。
  Widget _buildDefaultRow(BuildContext context) {
    return Row(
      key: const ValueKey<String>('head_default'),
      children: [
        Expanded(
          child: _SearchPreview(
            key: const ValueKey<String>('search_preview'),
            height: _searchPreviewHeight,
            onTap: onOpenSearchPage,
            hint: searchHint,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        _TrailingActions(
          onOpenDrafts: onOpenDrafts,
          draftCount: draftCount,
          onOpenArchived: onOpenArchived,
          onOpenViewOptions: onOpenViewOptions,
        ),
      ],
    );
  }
}

class _SearchPreview extends StatelessWidget {
  const _SearchPreview({
    super.key,
    required this.height,
    required this.onTap,
    this.hint,
  });

  final double height;
  final VoidCallback onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;

    // 未进入搜索页时展示的“可点击搜索预览条”，采用 Expressive 柔和胶囊风格。
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.nav),
        color: isLight
            ? ExpressiveSurfaces.cardColor(colorScheme)
            : colorScheme.surfaceContainerHigh,
        border: Border.all(
          color: ExpressiveSurfaces.cardBorderColor(colorScheme),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.nav),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.magnifyingGlass,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hint ?? context.l10n.diarySearchPreviewHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrailingActions extends StatelessWidget {
  const _TrailingActions({
    required this.onOpenDrafts,
    required this.draftCount,
    required this.onOpenArchived,
    required this.onOpenViewOptions,
  });

  final VoidCallback onOpenDrafts;
  final int draftCount;
  final VoidCallback onOpenArchived;
  final VoidCallback onOpenViewOptions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.l10n.diaryDraftsTitle,
          onPressed: onOpenDrafts,
          // 角标用主色而不是默认的错误色：草稿是“还没写完”，不是警告。
          icon: Badge.count(
            count: draftCount,
            maxCount: 99,
            isLabelVisible: draftCount > 0,
            backgroundColor: colorScheme.primary,
            textColor: colorScheme.onPrimary,
            child: const FaIcon(FontAwesomeIcons.filePen, size: 18),
          ),
        ),
        IconButton(
          tooltip: context.l10n.autoT0148,
          onPressed: onOpenArchived,
          icon: const FaIcon(FontAwesomeIcons.boxArchive, size: 18),
        ),
        IconButton(
          tooltip: context.l10n.autoT0125,
          onPressed: onOpenViewOptions,
          icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
        ),
      ],
    );
  }
}
