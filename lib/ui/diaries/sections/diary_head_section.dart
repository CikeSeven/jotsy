import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../home/widgets/home_bar/home_chrome_scope.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/select_all_button.dart';

/// 日记列表布局模式。
enum DiaryLayoutMode { list, waterfall }

/// 日记页顶部头部区块。
///
/// 布局职责：
/// - 普通态：搜索条占满左侧，右侧为草稿箱（有草稿时带份数角标）、归档列表
///   与视图选项入口；
/// - 多选态：取消 · 全选开关（勾选框 + 已选数量） · 收进日记本 · 归档 ·
///   删除 · 更多（置顶或取消置顶、设置标签、导出；在普通日记本里另有“从
///   本日记本移出”“移动到…”，最多 5 项、都是单行动作，仍用弹出菜单而不是
///   底部面板）。全选开关不另占一个图标按钮位（320dp 宽时放不下第 6 个
///   按钮），而是把“已选数量”整块做成开关，点按在全选 / 取消全选之间切换；
///   全选的范围与“已全选”的判断由页面给出（见 DiariesSelectAllController）。
///   取消全选后选中为 0、仍在多选，此时批量操作停用。
class DiaryHeadSection extends StatelessWidget {
  // ==================== 头部过渡动画常量 ====================
  static const double _headerContentHeight = 52;
  static const double _searchPreviewHeight = 40;

  const DiaryHeadSection({
    super.key,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.onCancelSelection,
    required this.allSelected,
    required this.onToggleSelectAll,
    required this.isPinActionUnpin,
    required this.onPinSelected,
    required this.onArchiveSelected,
    required this.onSetTagsSelected,
    required this.onExportSelected,
    required this.onDeleteSelected,
    this.onAddToNotebookSelected,
    this.onRemoveFromNotebookSelected,
    this.onMoveToNotebookSelected,
    required this.onOpenArchived,
    required this.onOpenDrafts,
    required this.draftCount,
    required this.onOpenViewOptions,
    required this.onOpenSearchPage,
    this.searchHint,
    this.onOpenAi,
  });

  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback onCancelSelection;

  /// 当前列表的全部日记（含还没分页加载的）都已选中：全选开关为实心。
  final bool allSelected;

  /// 点按全选开关：已全选时取消全选（留在多选），否则全选。
  final VoidCallback onToggleSelectAll;
  final bool isPinActionUnpin;
  final VoidCallback onPinSelected;
  final VoidCallback onArchiveSelected;

  /// 给所选日记批量加上或去掉标签（三态标签面板）。
  final VoidCallback onSetTagsSelected;
  final VoidCallback onExportSelected;
  final VoidCallback onDeleteSelected;

  /// 收进日记本（三态选择器）；为 null 时（日记本功能关闭）不显示这个按钮。
  final VoidCallback? onAddToNotebookSelected;

  /// 从当前日记本移出 / 移动到另一本：只在普通日记本里提供，否则为 null，
  /// 菜单里不出现这两项。
  final VoidCallback? onRemoveFromNotebookSelected;
  final VoidCallback? onMoveToNotebookSelected;
  final VoidCallback onOpenArchived;
  final VoidCallback onOpenDrafts;

  /// 草稿份数，大于 0 时草稿箱图标带角标。
  final int draftCount;

  /// 打开视图选项面板（排序与布局），面板由页面控制器负责呈现。
  final VoidCallback onOpenViewOptions;
  final VoidCallback onOpenSearchPage;

  /// 搜索条占位文字；null 时用默认文案（在日记本里时为“在「旅行」中搜索”）。
  final String? searchHint;

  /// 打开 AI 助手主页；AI 不可用（或对话、回顾都关闭）时为 null，不显示。
  final VoidCallback? onOpenAi;

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

  /// 多选态：取消 + 全选开关（已选数量） + 常用批量操作，其余收进“更多”
  /// 菜单。
  ///
  /// 与改版前同样是 5 个图标按钮 + 数量，320dp 宽也放得下；数量文字放不下
  /// 时按比例缩小而不是省略（“已选择 1…”读不出数量）。一篇都没选（取消
  /// 全选后）时批量操作停用。
  Widget _buildSelectionRow(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = selectedCount > 0;
    final onRemove = onRemoveFromNotebookSelected;
    final onMove = onMoveToNotebookSelected;
    return Row(
      key: const ValueKey<String>('head_selection'),
      children: [
        IconButton(
          tooltip: l10n.commonCancel,
          onPressed: onCancelSelection,
          icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
        ),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _SelectAllCount(
              selectedCount: selectedCount,
              allSelected: allSelected,
              onToggle: onToggleSelectAll,
            ),
          ),
        ),
        if (onAddToNotebookSelected case final onAddToNotebook?)
          IconButton(
            tooltip: l10n.notebookPickerTitle,
            onPressed: hasSelection ? onAddToNotebook : null,
            icon: const FaIcon(FontAwesomeIcons.bookBookmark, size: 18),
          ),
        IconButton(
          tooltip: l10n.autoT0140,
          onPressed: hasSelection ? onArchiveSelected : null,
          icon: const FaIcon(FontAwesomeIcons.boxArchive, size: 18),
        ),
        IconButton(
          tooltip: l10n.commonDelete,
          onPressed: hasSelection ? onDeleteSelected : null,
          // 停用时不用错误色，交给 IconButton 的停用色。
          icon: FaIcon(
            FontAwesomeIcons.trashCan,
            size: 18,
            color: hasSelection ? colorScheme.error : null,
          ),
        ),
        ExpressiveMenuButton(
          enabled: hasSelection,
          tooltip: l10n.notebookSelectionMore,
          icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
          items: <Widget>[
            // 选中项全部已置顶时为“取消置顶”。
            ExpressiveMenuItem(
              leadingIcon: FaIcon(
                isPinActionUnpin
                    ? FontAwesomeIcons.thumbtackSlash
                    : FontAwesomeIcons.thumbtack,
              ),
              onPressed: onPinSelected,
              child: Text(
                isPinActionUnpin
                    ? l10n.diaryUnpinSelected
                    : l10n.diaryPinSelected,
              ),
            ),
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.tags),
              onPressed: onSetTagsSelected,
              child: Text(l10n.diaryTagBatchAction),
            ),
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.fileExport),
              onPressed: onExportSelected,
              child: Text(l10n.diaryExportSelected),
            ),
            if (onRemove != null)
              ExpressiveMenuItem(
                leadingIcon: const FaIcon(FontAwesomeIcons.folderMinus),
                onPressed: onRemove,
                child: Text(l10n.notebookRemoveFromCurrent),
              ),
            if (onMove != null)
              ExpressiveMenuItem(
                leadingIcon: const FaIcon(FontAwesomeIcons.rightLeft),
                onPressed: onMove,
                child: Text(l10n.notebookMoveTo),
              ),
          ],
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
          onOpenAi: onOpenAi,
          onOpenDrafts: onOpenDrafts,
          draftCount: draftCount,
          onOpenArchived: onOpenArchived,
          onOpenViewOptions: onOpenViewOptions,
        ),
      ],
    );
  }
}

/// 多选顶栏的全选开关：勾选框图形（与草稿箱、回收站的全选按钮同一套，
/// 见 [SelectAllIcon]）+ 已选数量，整块可点。
///
/// 数量文字放不下时按比例缩小（FittedBox）而不是省略。勾选框占去了原本
/// 给数量的一截宽度：窄窗口（360dp 宽且多选栏有 5 个按钮时只剩约 55dp）里
/// “已选择 N 项”要缩到不足原字号的 [_minTextScale]、几乎读不出来，这时改为
/// 只显示数字（“☑ 25”）。按哪种显示只看可用宽度（以三位数的文案量），不随
/// 数量位数来回切换；读屏的值始终是完整的“已选择 N 项”。触控区高度至少
/// 48dp。读屏为按钮：标签是“全选 / 取消全选”，值是已选数量。
class _SelectAllCount extends StatelessWidget {
  const _SelectAllCount({
    required this.selectedCount,
    required this.allSelected,
    required this.onToggle,
  });

  static const double _minTouchExtent = 48;

  /// 勾选框图形的宽度（[SelectAllIcon] 为 18dp 的图标）。
  static const double _iconExtent = 18;
  static const double _minTextScale = 0.5;

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final action = allSelected ? l10n.commonDeselectAll : l10n.commonSelectAll;
    final countText = l10n.autoT0099(selectedCount.toString());
    final style = theme.textTheme.titleLarge?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
    );
    return Tooltip(
      message: action,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: action,
        value: countText,
        onTap: onToggle,
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey<String>('head_select_all'),
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppRadii.nav),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minTouchExtent),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xs,
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final budget =
                      constraints.maxWidth - _iconExtent - AppSpacing.s;
                  final shown =
                      _fitsAtReadableSize(
                        context,
                        l10n.autoT0099('000'),
                        style,
                        budget: budget,
                      )
                      ? countText
                      : selectedCount.toString();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SelectAllIcon(
                        allSelected: allSelected,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(shown, style: style, maxLines: 1),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [text] 缩放到 [budget] 宽时是否仍不小于原字号的 [_minTextScale]。
  static bool _fitsAtReadableSize(
    BuildContext context,
    String text,
    TextStyle? style, {
    required double budget,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width <= 0 || budget >= width * _minTextScale;
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

    // “控件”为玻璃时与点开后的搜索页输入框同一材质（玻璃底色 + 玻璃描边）。
    // 否则：玻璃顶栏上不透明的卡片色会挖出一块实心色块、遮住后面透出的
    // 内容，改成在玻璃上轻轻压一层前景色，保留描边勾出胶囊轮廓。
    final glassField = AppGlassField.of(context);
    final glassTopBars = HomeChromeScope.glassTopBarsOf(context);
    final Color fill;
    if (glassField != null) {
      fill = glassField.fill;
    } else if (glassTopBars) {
      fill = colorScheme.onSurface.withValues(alpha: isLight ? 0.05 : 0.08);
    } else {
      fill = isLight
          ? ExpressiveSurfaces.cardColor(colorScheme)
          : colorScheme.surfaceContainerHigh;
    }
    final glassSide = glassField?.border;

    // 未进入搜索页时展示的“可点击搜索预览条”，采用 Expressive 柔和胶囊风格。
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.nav),
        color: fill,
        border: glassField != null
            ? (glassSide == null ? null : Border.fromBorderSide(glassSide))
            : Border.all(
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
    required this.onOpenAi,
    required this.onOpenDrafts,
    required this.draftCount,
    required this.onOpenArchived,
    required this.onOpenViewOptions,
  });

  final VoidCallback? onOpenAi;
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
        if (onOpenAi != null)
          IconButton(
            tooltip: context.l10n.aiHubTooltip,
            onPressed: onOpenAi,
            icon: const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 18),
          ),
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
