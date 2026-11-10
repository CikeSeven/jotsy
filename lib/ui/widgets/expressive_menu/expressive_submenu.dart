import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'expressive_menu_anchor.dart';
import 'expressive_menu_item.dart';
import 'expressive_menu_layout.dart';
import 'expressive_menu_row.dart';

/// 打开二级菜单的一项：行尾带 ›，点按后二级菜单从这一行变形展开（移植自
/// miuix 的 CascadingListPopup）：这一行长成一块新面板盖在主菜单上，顶部
/// 是这一行的副本（› 转向上方，点按收回），下面是分隔线与 [menuChildren]；
/// 主菜单缩到 0.95 并盖上半透明遮罩，点遮罩、点外部或返回都先收回二级菜单。
///
/// 级联深度上限为 2：二级菜单里再放 [ExpressiveSubmenuItem] 不会再展开。
///
/// [menuChildren] 在点按时取定：二级菜单显示期间外面重建不会刷新它。要随
/// 选择即时变化的内容（保持菜单打开的单选项的对勾）应放进自己维护选中态的
/// 子组件里。
class ExpressiveSubmenuItem extends StatefulWidget {
  const ExpressiveSubmenuItem({
    super.key,
    required this.child,
    required this.menuChildren,
    this.leadingIcon,
  });

  /// 条目文字；二级菜单顶部的标题行也用它。
  final Widget child;

  /// 前置图标，与 [ExpressiveMenuItem.leadingIcon] 相同。
  final Widget? leadingIcon;

  /// 二级菜单的内容，通常是若干 [ExpressiveMenuItem]。
  final List<Widget> menuChildren;

  @override
  State<ExpressiveSubmenuItem> createState() => _ExpressiveSubmenuItemState();
}

class _ExpressiveSubmenuItemState extends State<ExpressiveSubmenuItem> {
  /// 这一行的焦点：键盘打开二级菜单再收回时，焦点回到这一行。
  final FocusNode _focus = FocusNode(debugLabel: 'ExpressiveSubmenuItem');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpressiveMenuItem(
    closeOnActivate: false,
    focusNode: _focus,
    leadingIcon: widget.leadingIcon,
    trailingIcon: const ExpressiveSubmenuChevron(),
    onPressed: () => ExpressiveMenuAnchorState.maybeOf(
      context,
    )?.openSubmenu(widget, context, _focus),
    child: widget.child,
  );
}

/// 二级菜单入口行尾的 ›（RTL 为 ‹），10 × 16 的格子；在标题行里随 [turns]
/// 转向上方。
class ExpressiveSubmenuChevron extends StatelessWidget {
  const ExpressiveSubmenuChevron({super.key, this.turns});

  /// 转过的圈数；null 不转。
  final Animation<double>? turns;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    Widget icon = FaIcon(
      rtl ? FontAwesomeIcons.angleLeft : FontAwesomeIcons.angleRight,
      size: ExpressiveMenuRowMetrics.chevronCell.height,
    );
    final turns = this.turns;
    if (turns != null) icon = RotationTransition(turns: turns, child: icon);
    return SizedBox.fromSize(
      size: ExpressiveMenuRowMetrics.chevronCell,
      child: OverflowBox(
        maxWidth: ExpressiveMenuRowMetrics.chevronCell.height,
        child: icon,
      ),
    );
  }
}

/// 二级菜单顶部的标题行：入口行的副本，点按收回二级菜单；读屏读作
/// “返回，标题”。
///
/// 变形途中（[expand] 从 0 到 1）整行高度从触发行的高度 [anchorHeight]
/// 插值到自身高度（上 20、下 12），文字的上内边距从触发行的 [anchorPadTop]
/// 插值到 20：起点与触发行逐像素重合，看起来就是那一行本身长成了面板。
/// 行尾 › 随 [arrow] 转向上方（LTR −90°、RTL +90°）。
class ExpressiveSubmenuHeader extends StatelessWidget {
  const ExpressiveSubmenuHeader({
    super.key,
    required this.item,
    required this.expand,
    required this.arrow,
    required this.anchorHeight,
    required this.anchorPadTop,
    required this.metrics,
    required this.onCollapse,
  });

  final ExpressiveSubmenuItem item;
  final Animation<double> expand;
  final Animation<double> arrow;
  final double anchorHeight;
  final double anchorPadTop;
  final ExpressiveSubmenuMetrics metrics;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExpressiveMenuRowInk(
      onTap: onCollapse,
      expanded: true,
      child: _MorphHeaderLayout(
        expand: expand,
        anchorHeight: anchorHeight,
        anchorPadTop: anchorPadTop,
        metrics: metrics,
        child: ExpressiveMenuRowContent(
          padding: const EdgeInsets.symmetric(
            horizontal: ExpressiveMenuRowMetrics.horizontalPadding,
          ),
          leadingIcon: item.leadingIcon,
          trailing: ExpressiveSubmenuChevron(
            turns: arrow.drive(
              Tween<double>(begin: 0, end: rtl ? 0.25 : -0.25),
            ),
          ),
          child: Semantics(
            label: MaterialLocalizations.of(context).backButtonTooltip,
            child: item.child,
          ),
        ),
      ),
    );
  }
}

/// 标题行的变形布局：高度与上内边距随 [expand] 插值，并把“比展开完少了
/// 多少高”报给 [metrics]（布局据此还原二级菜单展开完的高度）。
class _MorphHeaderLayout extends SingleChildRenderObjectWidget {
  const _MorphHeaderLayout({
    required this.expand,
    required this.anchorHeight,
    required this.anchorPadTop,
    required this.metrics,
    required super.child,
  });

  final Animation<double> expand;
  final double anchorHeight;
  final double anchorPadTop;
  final ExpressiveSubmenuMetrics metrics;

  @override
  _RenderMorphHeader createRenderObject(BuildContext context) =>
      _RenderMorphHeader(
        expand: expand,
        anchorHeight: anchorHeight,
        anchorPadTop: anchorPadTop,
        metrics: metrics,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphHeader renderObject,
  ) {
    renderObject
      ..expand = expand
      ..anchorHeight = anchorHeight
      ..anchorPadTop = anchorPadTop
      ..metrics = metrics;
  }
}

class _RenderMorphHeader extends RenderShiftedBox {
  _RenderMorphHeader({
    required this._expand,
    required this._anchorHeight,
    required this._anchorPadTop,
    required this._metrics,
  }) : super(null);

  static const double _padTop = ExpressiveMenuRowMetrics.edgePadding;
  static const double _padBottom = ExpressiveMenuRowMetrics.verticalPadding;

  Animation<double> _expand;
  set expand(Animation<double> value) {
    if (value == _expand) return;
    if (attached) _expand.removeListener(markNeedsLayout);
    _expand = value;
    if (attached) _expand.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  double _anchorHeight;
  set anchorHeight(double value) {
    if (value == _anchorHeight) return;
    _anchorHeight = value;
    markNeedsLayout();
  }

  double _anchorPadTop;
  set anchorPadTop(double value) {
    if (value == _anchorPadTop) return;
    _anchorPadTop = value;
    markNeedsLayout();
  }

  ExpressiveSubmenuMetrics _metrics;
  set metrics(ExpressiveSubmenuMetrics value) {
    if (identical(value, _metrics)) return;
    _metrics = value;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _expand.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _expand.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      (child?.getMinIntrinsicHeight(width) ?? 0) + _padTop + _padBottom;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      (child?.getMaxIntrinsicHeight(width) ?? 0) + _padTop + _padBottom;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    final childSize = child == null
        ? Size.zero
        : child.getDryLayout(
            constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
          );
    return constraints.constrain(
      Size(childSize.width, childSize.height + _padTop + _padBottom),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
      parentUsesSize: true,
    );
    final f = _expand.value;
    final full = child.size.height + _padTop + _padBottom;
    final height = _anchorHeight <= 0
        ? full
        : math.max(0.0, lerpExpressiveValue(_anchorHeight, full, f));
    final padTop = _anchorHeight <= 0
        ? _padTop
        : lerpExpressiveValue(_anchorPadTop, _padTop, f);
    (child.parentData! as BoxParentData).offset = Offset(0, padTop);
    size = constraints.constrain(Size(child.size.width, height));
    _metrics.collapsedDelta = full - size.height;
  }
}

/// 菜单里分组之间的分隔线：`outlineVariant` 1.5dp，左右缩进 20、上下各留 4
/// （同 miuix）。
class ExpressiveMenuDivider extends StatelessWidget {
  const ExpressiveMenuDivider({super.key});

  static const double inset = ExpressiveMenuRowMetrics.horizontalPadding;
  static const double spacing = 4;
  static const double thickness = 1.5;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: inset, vertical: spacing),
    child: Divider(
      height: thickness,
      thickness: thickness,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}
