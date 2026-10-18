import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_radii.dart';

/// 菜单可以占用的区域：安全区（扣掉系统栏、键盘与显示特征）再留 8dp 边距，
/// 以及面板的最大宽度（所在屏幕宽度 − 32）。
class ExpressiveMenuArea {
  const ExpressiveMenuArea({required this.bounds, required this.maxWidth});

  /// 菜单到安全区边缘的最小距离。
  static const double screenMargin = 8;

  /// 宽度留白：菜单最宽为所在屏幕宽度减去它。
  static const double horizontalReserve = 32;

  final Rect bounds;
  final double maxWidth;

  static ExpressiveMenuArea of(BuildContext context, RawMenuOverlayInfo info) {
    // 系统栏与键盘取自视图本身：Scaffold 正文、底部面板会在局部 MediaQuery
    // 里抹掉顶部 padding，用局部值会让翻到上方的菜单钻进状态栏。
    final view = MediaQueryData.fromView(View.of(context));
    final viewport = view.padding.deflateRect(
      view.viewInsets.deflateRect(Offset.zero & info.overlaySize),
    );
    // 折叠屏铰链等显示特征两侧各算一块屏幕，菜单只放在离锚点最近的那块上。
    final screens = DisplayFeatureSubScreen.subScreensInBounds(
      viewport,
      DisplayFeatureSubScreen.avoidBounds(view),
    );
    final screen = screens.isEmpty
        ? viewport
        : screens.reduce(
            (Rect a, Rect b) =>
                (a.center - info.anchorRect.center).distanceSquared <=
                    (b.center - info.anchorRect.center).distanceSquared
                ? a
                : b,
          );
    return ExpressiveMenuArea(
      bounds: screen.deflate(screenMargin),
      maxWidth: math.max(0, screen.width - horizontalReserve),
    );
  }
}

/// 菜单表面：surfaceContainer、无着色、elevation 2、28 圆角、内边距 8；
/// 宽度取内容固有宽度（最小 176，最大 [maxWidth]），高度超出可用区域时内部滚动。
class ExpressiveMenuPanel extends StatelessWidget {
  const ExpressiveMenuPanel({
    super.key,
    required this.opacity,
    required this.scrollController,
    required this.showScrollbar,
    required this.maxWidth,
    required this.children,
  });

  static const double minWidth = 176;
  static const double padding = 8;

  final Animation<double> opacity;
  final ScrollController scrollController;
  final bool showScrollbar;
  final double maxWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(padding),
      child: ScrollConfiguration(
        // 关掉平台默认滚动条与越界效果，滚动条由下面的 Scrollbar 按
        // [showScrollbar] 控制。
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          overscroll: false,
          physics: const ClampingScrollPhysics(),
        ),
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: showScrollbar,
          child: SingleChildScrollView(
            controller: scrollController,
            primary: false,
            child: ListBody(children: children),
          ),
        ),
      ),
    );
    return FadeTransition(
      opacity: opacity,
      alwaysIncludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: math.min(minWidth, maxWidth),
          maxWidth: maxWidth,
        ),
        // 按最终尺寸布局，缩放只发生在绘制阶段，文字不会逐帧重排。
        child: RepaintBoundary(
          child: IntrinsicWidth(
            child: Material(
              color: colors.surfaceContainer,
              surfaceTintColor: Colors.transparent,
              elevation: 2,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppRadii.nav)),
              ),
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
