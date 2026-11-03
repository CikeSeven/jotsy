import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';
import '../expressive_menu/expressive_menu_surface.dart';
import 'app_text_menu_action.dart';
import 'app_text_selection_layout.dart';
import 'app_text_toolbar_buttons.dart';

/// 手机上的文字选区菜单：贴着选区的玻璃胶囊，主行放编辑类操作，其余收在
/// 「更多」后面，展开为两列次要区。
///
/// - 输入：选区锚点 [anchors]（全局坐标）与菜单项 [actions]。
/// - 输出：铺满所在覆盖层的盒子，胶囊按 [AppTextToolbarGeometry] 定位在其中；
///   既能直接作为 Flutter `contextMenuBuilder` 的返回值（被插进根 Overlay），
///   也能放进调用方自己的 OverlayEntry（日记正文）。两种情况下覆盖层都从屏幕
///   原点开始，锚点的全局坐标即覆盖层坐标。
/// - 副作用：无。点按某项只调用它的 `onPressed`，收起菜单由调用方负责。
///
/// 排布：主行先放 [AppTextMenuSlot.primary]、再放 [AppTextMenuSlot.lead]（各自
/// 保持原顺序，即「剪切、复制、粘贴、全选、AI」：编辑类操作是最常点的，固定
/// 在手指最先看到的位置，AI 跟在后面；桌面竖排菜单里 lead 仍是最上面一组）；
/// 有次要项时末尾是「更多」。主行放不下（可用宽 = 覆盖层宽 − 左右安全区 −
/// 左右各 8）时从末尾把项挪进次要区最前面（[fitAppTextToolbarRow]），所以
/// 窄屏上 AI 会最先进「更多」。
///
/// 展开状态是组件内部状态：[collapseScope] 变了（如选区变了）即回到收起态，
/// 胶囊本身不重新挂载、不重播入场动画——拖动选区把手时选区每帧都在变，换
/// key 会让胶囊每帧重建、反复从 0.96 缩放淡入。重新打开菜单时调用方插入的是
/// 新的胶囊，自然从收起态开始。展开时主行原地不动，次要区长在远离选区的一侧——胶囊在选区
/// 上方时次要区在主行之上（底边固定、向上长），在下方时在主行之下。
///
/// 动效：挂载时表面由浅到深（`fast` / `effects`），同时 0.96→1 缩放，原点在
/// 贴着选区那条边的中点；展开 / 收起经 AnimatedSize（`medium` / `spatial`），
/// 次要区内容淡入（`fast`）。淡入只套在玻璃里面的内容上：整块玻璃放进透明度
/// 层会采不到背景、闪出没有模糊的底。减少动画时全部瞬时。
class AppTextSelectionToolbar extends StatefulWidget {
  const AppTextSelectionToolbar({
    super.key,
    required this.anchors,
    required this.actions,
    this.collapseScope,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<AppTextMenuAction> actions;

  /// 展开态所属的范围（如当前选区）：与上一次不相等时把展开的次要区收起。
  /// 为 null 时只在胶囊重新挂载时回到收起态。
  final Object? collapseScope;

  /// 胶囊内边距。
  static const double padding = 4;

  /// 展开后卡片的最小宽度。
  static const double expandedMinWidth = 256;

  /// 收起时的高度（主行 + 上下内边距），决定放在选区上方还是下方。
  static const double collapsedHeight =
      AppTextToolbarMetrics.rowHeight + padding * 2;

  /// 胶囊里文字的最大缩放：主行高度固定为 56，再大会把文字挤出按钮。
  static const double maxTextScale = 2;

  @override
  State<AppTextSelectionToolbar> createState() =>
      _AppTextSelectionToolbarState();
}

class _AppTextSelectionToolbarState extends State<AppTextSelectionToolbar>
    with SingleTickerProviderStateMixin {
  static const double _openScale = 0.96;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.fast,
  );
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _reveal,
    curve: ExpressiveMotion.effects,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: _openScale,
    end: 1,
  ).animate(_progress);
  bool _started = false;
  bool _expanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 时长要读 MediaQuery（减少动画），只能在这里而不是 initState 里开始。
    _reveal.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.fast,
    );
    if (ExpressiveMotion.reduceMotion(context)) {
      _reveal.value = 1;
    } else if (!_started) {
      _reveal.forward();
    }
    _started = true;
  }

  @override
  void didUpdateWidget(AppTextSelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只收起，不碰入场动画：胶囊原地换内容。
    if (oldWidget.collapseScope != widget.collapseScope) _expanded = false;
  }

  @override
  void dispose() {
    _progress.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) => widget.actions.isEmpty
      // 没有任何动作时什么也不画（与 AdaptiveTextSelectionToolbar 一致），
      // 不留一块空胶囊。
      ? const SizedBox.shrink()
      : MediaQuery.withClampedTextScaling(
          maxScaleFactor: AppTextSelectionToolbar.maxTextScale,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                _buildLayout(context, constraints.biggest),
          ),
        );

  Widget _buildLayout(BuildContext context, Size overlaySize) {
    // 系统栏与键盘取自视图本身：局部 MediaQuery 可能已被 Scaffold 抹掉顶部
    // padding，用它会让菜单钻进状态栏（与 ExpressiveMenuArea 同一考虑）。
    final view = MediaQueryData.fromView(View.of(context));
    final geometry = AppTextToolbarGeometry(
      overlaySize: overlaySize,
      safePadding: view.padding.copyWith(
        bottom: math.max(view.padding.bottom, view.viewInsets.bottom),
      ),
      primaryAnchor: widget.anchors.primaryAnchor,
      secondaryAnchor: widget.anchors.secondaryAnchor,
      collapsedHeight: AppTextSelectionToolbar.collapsedHeight,
    );
    final l10n = context.l10n;
    final rowItems = <AppTextMenuAction>[
      for (final slot in <AppTextMenuSlot>[
        AppTextMenuSlot.primary,
        AppTextMenuSlot.lead,
      ])
        ...widget.actions.where((AppTextMenuAction a) => a.slot == slot),
    ];
    final secondary = widget.actions
        .where((AppTextMenuAction a) => a.slot == AppTextMenuSlot.secondary)
        .toList();
    final widths = <double>[
      for (final action in rowItems)
        AppTextToolbarMetrics.buttonWidthOf(context, action.label),
    ];
    final moreWidth = math.max(
      AppTextToolbarMetrics.buttonWidthOf(context, l10n.textSelectionMenuMore),
      AppTextToolbarMetrics.buttonWidthOf(context, l10n.textSelectionMenuLess),
    );
    final fit = fitAppTextToolbarRow<AppTextMenuAction>(
      items: rowItems,
      widths: widths,
      moreWidth: moreWidth,
      hasSecondary: secondary.isNotEmpty,
      available: geometry.availableWidth,
      chrome: AppTextSelectionToolbar.padding * 2,
    );
    final overflow = <AppTextMenuAction>[...fit.overflow, ...secondary];
    final expanded = _expanded && overflow.isNotEmpty;
    final above = geometry.above;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        // 留在主行的是 rowItems 的前缀，宽度按下标对应。
        for (var i = 0; i < fit.row.length; i++)
          AppTextToolbarRowButton(action: fit.row[i], width: widths[i]),
        if (overflow.isNotEmpty)
          AppTextToolbarMoreButton(
            expanded: expanded,
            moreLabel: l10n.textSelectionMenuMore,
            lessLabel: l10n.textSelectionMenuLess,
            width: moreWidth,
            onPressed: _toggle,
          ),
      ],
    );
    final secondaryArea = expanded
        ? _secondaryArea(
            context,
            overflow,
            maxHeight:
                geometry.availableHeight -
                AppTextSelectionToolbar.collapsedHeight -
                AppTextToolbarMetrics.dividerHeight,
            above: above,
          )
        : null;
    final children = <Widget>[
      if (above && secondaryArea != null) secondaryArea,
      row,
      if (!above && secondaryArea != null) secondaryArea,
    ];
    final alignment = above ? Alignment.bottomCenter : Alignment.topCenter;
    final minWidth = expanded
        ? math.max(
            0.0,
            math.min(
                  AppTextSelectionToolbar.expandedMinWidth,
                  geometry.availableWidth,
                ) -
                AppTextSelectionToolbar.padding * 2,
          )
        : 0.0;

    final card = ScaleTransition(
      scale: _scale,
      alignment: alignment,
      child: RepaintBoundary(
        child: ExpressiveMenuSurface(
          reveal: _progress,
          child: AnimatedSize(
            alignment: alignment,
            duration: ExpressiveMotion.durationNonZero(
              context,
              ExpressiveMotion.medium,
            ),
            curve: ExpressiveMotion.spatial,
            child: Padding(
              padding: const EdgeInsets.all(AppTextSelectionToolbar.padding),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return CustomSingleChildLayout(
      delegate: AppTextSelectionLayoutDelegate(geometry),
      child: card,
    );
  }

  /// 次要区：分隔线 + 两列网格，分隔线始终在网格与主行之间；内容淡入。
  Widget _secondaryArea(
    BuildContext context,
    List<AppTextMenuAction> actions, {
    required double maxHeight,
    required bool above,
  }) {
    final divider = Divider(
      height: AppTextToolbarMetrics.dividerHeight,
      thickness: 1,
      indent: AppTextToolbarMetrics.dividerIndent,
      endIndent: AppTextToolbarMetrics.dividerIndent,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    final grid = AppTextToolbarSecondaryGrid(
      actions: actions,
      maxHeight: maxHeight,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      curve: ExpressiveMotion.effects,
      builder: (BuildContext context, double opacity, Widget? child) =>
          Opacity(opacity: opacity, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: above ? <Widget>[grid, divider] : <Widget>[divider, grid],
      ),
    );
  }
}
