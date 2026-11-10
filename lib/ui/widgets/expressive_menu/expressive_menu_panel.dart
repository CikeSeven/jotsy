import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import 'expressive_menu_surface.dart';

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

/// 菜单面板：玻璃表面 [ExpressiveMenuSurface]、内边距 8；宽度取内容固有宽度
/// （最小 176，最大 [maxWidth]），高度超出可用区域时内部滚动。
///
/// 换页（进出二级菜单）：[pageKey] 变化时整页重建，新一页随 [pageReveal]
/// 淡入并从 [pageForward] 决定的方向横移 6%；表面尺寸经 AnimatedSize 过渡到
/// 新一页的大小（fast / effects），玻璃表面本身不参与淡入。
class ExpressiveMenuPanel extends StatelessWidget {
  const ExpressiveMenuPanel({
    super.key,
    required this.reveal,
    required this.scrollController,
    required this.showScrollbar,
    required this.maxWidth,
    required this.children,
    this.pageKey,
    this.pageReveal = kAlwaysCompleteAnimation,
    this.pageForward = true,
    this.withSurface = true,
  });

  static const double minWidth = 176;
  static const double padding = 8;

  /// 展开进度：驱动表面的底色、描边、模糊与内容淡入。
  final Animation<double> reveal;
  final ScrollController scrollController;
  final bool showScrollbar;
  final double maxWidth;
  final List<Widget> children;

  /// 当前一页的身份；变化时换页。
  final Key? pageKey;

  /// 当前一页的显现进度（淡入与横移）。
  final Animation<double> pageReveal;

  /// 进入下一级（从结束方向移入）为 true，退回上一级为 false。
  final bool pageForward;

  /// 是否自带玻璃表面。按钮长成菜单（ExpressiveMenuMorph）时玻璃由形变单独
  /// 画、内容的淡入也由它负责：这里只垫一层透明 Material 承接水波纹，
  /// [reveal] 不用。
  final bool withSurface;

  static const double _pageShift = 0.06;

  @override
  Widget build(BuildContext context) {
    final page = KeyedSubtree(
      key: pageKey,
      child: FadeTransition(
        opacity: pageReveal,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(pageForward ? _pageShift : -_pageShift, 0),
            end: Offset.zero,
          ).animate(pageReveal),
          // 按阅读方向翻转：RTL 下“结束方向”在左。
          textDirection: Directionality.of(context),
          child: ListBody(children: children),
        ),
      ),
    );
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
            child: page,
          ),
        ),
      ),
    );
    // 尺寸过渡放在表面里面：表面（圆角、描边、投影）随过渡中的尺寸画，
    // 内容按新一页的最终尺寸布局、只被裁切。首次布局直接取内容尺寸，不从
    // 0 长出来。
    //
    // 减少动画时不套 AnimatedSize：它的时长不能为 0（见 durationNonZero），
    // 1ms 的过渡仍要等两帧（检测到变化的那帧与 ticker 起步的那帧）才到位，
    // 换页时会先露出两帧裁切的内容。代价是菜单开着时切换减少动画，内容会
    // 重建一次（滚动位置回到顶部）。
    final sized = ExpressiveMotion.reduceMotion(context)
        ? IntrinsicWidth(child: content)
        : AnimatedSize(
            duration: ExpressiveMotion.fast,
            curve: ExpressiveMotion.effects,
            alignment: AlignmentDirectional.topStart,
            child: IntrinsicWidth(child: content),
          );
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: math.min(minWidth, maxWidth),
        maxWidth: maxWidth,
      ),
      // 按最终尺寸布局，缩放只发生在绘制阶段，文字不会逐帧重排。
      child: RepaintBoundary(
        child: withSurface
            ? ExpressiveMenuSurface(reveal: reveal, child: sized)
            : Material(type: MaterialType.transparency, child: sized),
      ),
    );
  }
}
