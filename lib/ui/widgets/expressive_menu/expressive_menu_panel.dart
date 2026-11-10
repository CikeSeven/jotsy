import 'package:flutter/material.dart';

import '../glass/glass_surface.dart';
import 'expressive_menu_row.dart';
import 'expressive_menu_surface.dart';

/// 一块菜单面板（主菜单或二级菜单）：玻璃底 + 可滚动的一列菜单行。
///
/// - 宽度：取内容固有宽度，夹在 [minWidth]–[maxWidth]（miuix 为 200–288；
///   二级菜单至少与主菜单同宽，由布局经约束给出），超过可用宽度时再收窄。
/// - 高度：超过布局给出的最大高度时内部滚动；只在展开完成后显示滚动条
///   （[showScrollbar]），缩放与裁切展开过程中不闪现。
/// - 上下各留 [ExpressiveMenuRowMetrics.panelPadding]：与行自身的 12 合起来，
///   首末行的文字离面板边缘 20（同 miuix），按下高亮仍铺到边缘（见
///   [ExpressiveMenuRowEdges]）。有 [header]（二级菜单的标题行）时顶部不留：
///   标题行自己带 20 的上内边距，并在变形时从触发行的内边距插值过来。
/// - 玻璃：[GlassSurface] 画半透明底色与背景模糊（直角，形状由布局按超椭圆
///   裁出），[alpha] 同时驱动玻璃的显现与内容的淡入——不把整块玻璃放进
///   透明度层，否则模糊采不到页面。[solid]（菜单铺了变暗层）、减少动画或
///   高对比度时为不透明底（同一底色叠在页面底色上），不模糊。
class ExpressiveMenuPanel extends StatefulWidget {
  const ExpressiveMenuPanel({
    super.key,
    required this.alpha,
    required this.showScrollbar,
    required this.children,
    this.scrollController,
    this.header,
    this.solid = false,
    this.minWidth = defaultMinWidth,
    this.maxWidth = defaultMaxWidth,
  });

  static const double defaultMinWidth = 200;
  static const double defaultMaxWidth = 288;

  final Animation<double> alpha;

  /// 不传时面板自己建一个（二级菜单每次展开都是新的一块，滚动从顶部开始）。
  final ScrollController? scrollController;
  final bool showScrollbar;
  final List<Widget> children;
  final Widget? header;

  /// 不透明底、不模糊（菜单铺了变暗层时）；减少动画或高对比度时总是不透明。
  final bool solid;
  final double minWidth;
  final double maxWidth;

  @override
  State<ExpressiveMenuPanel> createState() => _ExpressiveMenuPanelState();
}

class _ExpressiveMenuPanelState extends State<ExpressiveMenuPanel> {
  final GlobalKey _contentKey = GlobalKey(debugLabel: 'ExpressiveMenuPanel');
  ScrollController? _ownScroll;

  ScrollController get _scroll =>
      widget.scrollController ?? (_ownScroll ??= ScrollController());

  @override
  void dispose() {
    _ownScroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    final content = ExpressiveMenuRowEdges(
      contentKey: _contentKey,
      child: ScrollConfiguration(
        // 关掉平台默认滚动条与越界效果，滚动条由下面的 Scrollbar 按
        // [showScrollbar] 控制。
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          overscroll: false,
          physics: const ClampingScrollPhysics(),
        ),
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: widget.showScrollbar,
          child: SingleChildScrollView(
            controller: _scroll,
            primary: false,
            child: Padding(
              key: _contentKey,
              padding: EdgeInsets.only(
                top: header == null ? ExpressiveMenuRowMetrics.panelPadding : 0,
                bottom: ExpressiveMenuRowMetrics.panelPadding,
              ),
              child: ListBody(children: <Widget>[?header, ...widget.children]),
            ),
          ),
        ),
      ),
    );
    final colors = Theme.of(context).colorScheme;
    final solid = widget.solid || ExpressiveMenuSurface.solidOf(context);
    final tint = ExpressiveMenuSurface.tintOf(colors);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minWidth,
        maxWidth: widget.maxWidth,
      ),
      // 按最终尺寸布局，缩放只发生在绘制阶段，文字不会逐帧重排。
      child: IntrinsicWidth(
        child: AnimatedBuilder(
          animation: widget.alpha,
          builder: (BuildContext context, Widget? child) => GlassSurface(
            fill: solid ? Color.alphaBlend(tint, colors.surface) : tint,
            blurSigma: ExpressiveMenuSurface.blurSigma,
            blur: !solid,
            progress: widget.alpha.value.clamp(0.0, 1.0),
            child: child!,
          ),
          child: FadeTransition(
            opacity: widget.alpha,
            alwaysIncludeSemantics: true,
            child: RepaintBoundary(child: content),
          ),
        ),
      ),
    );
  }
}
