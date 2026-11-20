import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../glass/glass_reveal.dart';
import '../glass/glass_surface.dart';
import '../width_layout_builder.dart';
import 'floating_island.dart';

/// 浮岛顶栏的布局：状态栏下方一行，左岛（返回）、居中的标题胶囊、右岛
/// （动作），没有整条底色——页面内容从岛与岛之间露出来。
///
/// - 几何：岛高 48，上下各留 [islandGap]，状态栏下方一共占 [extent]（56，
///   与原来的整条顶栏同高，内容的上边距因此不变）。左右离内容列边缘
///   [edgeInset]：给出 [contentMaxWidth] 时与居中的正文列对齐（宽窗口不贴
///   窗口边），否则离屏幕边 12。
/// - 标题胶囊真正居中（[NavigationToolbar]），放不下时在两岛之间收窄、
///   省略号截断。
/// - 显隐：[reveal]（1 显示、0 隐藏，可略微越过 1 的弹簧过冲）推动整行上移
///   离开屏幕并淡出；玻璃时淡出经 [GlassReveal]，经典时用 Opacity。几乎
///   隐藏时不接收点按、不进读屏。
class FloatingTopBar extends StatelessWidget {
  const FloatingTopBar({
    super.key,
    this.leading,
    this.middle,
    this.trailing,
    this.contentMaxWidth,
    this.reveal = kAlwaysCompleteAnimation,
  });

  /// 岛上下各留的空隙。
  static const double islandGap = 4;

  /// 状态栏下方被浮岛占用的高度：内容在静止时应从这里以下开始（或让头图
  /// 垫在岛下面）。
  static const double extent = FloatingIsland.height + islandGap * 2;

  final Widget? leading;
  final Widget? middle;
  final Widget? trailing;

  /// 正文列的最大宽度（如 `AppContentWidth.reading`），岛与它对齐。
  final double? contentMaxWidth;
  final Animation<double> reveal;

  /// 岛离可用区域左右边缘的距离。
  static double edgeInset(double width, double? contentMaxWidth) {
    if (contentMaxWidth == null || !width.isFinite) {
      return 12;
    }
    // 正文从 gutter 开始；岛比正文再往外 4，图标中心与正文的视觉边缘对齐。
    return math.max(12, AppContentWidth.gutter(width, contentMaxWidth) - 4);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;
    final glass = AppGlass.of(context).isGlass(AppGlassComponent.topBars);
    final row = WidthLayoutBuilder(
      builder: (BuildContext context, double width) {
        final inset = edgeInset(width, contentMaxWidth);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            inset,
            top + islandGap,
            inset,
            islandGap,
          ),
          child: SizedBox(
            height: FloatingIsland.height,
            child: NavigationToolbar(
              leading: leading,
              middle: middle,
              trailing: trailing,
              middleSpacing: 8,
            ),
          ),
        );
      },
    );
    return AnimatedBuilder(
      animation: reveal,
      child: row,
      builder: (BuildContext context, Widget? child) {
        final value = reveal.value;
        final opacity = value.clamp(0.0, 1.0);
        final hidden = opacity < 0.05;
        return IgnorePointer(
          ignoring: hidden,
          child: ExcludeSemantics(
            excluding: hidden,
            child: Transform.translate(
              offset: Offset(0, -(top + extent) * (1 - value)),
              child: glass
                  ? GlassReveal(progress: opacity, child: child!)
                  : Opacity(opacity: opacity, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// 状态栏那一条的底，并往下铺过浮岛那一行逐渐变透明（与首页顶栏同一种
/// 渐隐曲线，经 [GlassSurface.fadeToBottom]）：上半截是不透明的底，状态栏
/// 图标在任何头图与背景上都看得清；下半截淡到没有，滚上去的内容在浮岛之下
/// 逐渐隐去，不再在状态栏下沿切出一道硬边。浮岛画在它之上。
///
/// 只是一次透明度过渡，不模糊：经典时为 [color]（纸色 / 页面色），玻璃时为
/// 玻璃的不透明等效色（`AppGlassResolved.solidFill`）。半透明加重模糊时，
/// 底下正文里的彩色标签、图片会被糊成色块从状态栏那里透上来，显得脏；不
/// 模糊也让压在上面的玻璃浮岛照常模糊（同一区域只有岛这一层模糊）。高对比度时不渐隐，回到只垫状态栏、下沿是实边（与
/// 首页顶栏一致）。渐隐的尽头正好是内容静止时的上沿
/// （[FloatingTopBar.extent]），没有通栏头图时内容静止时不被遮住。
///
/// 同时决定状态栏图标的明暗：按所在的主题（预览页是这一篇的整页主题）给出
/// [SystemUiOverlayStyle]，浮岛隐藏时也不会回落到应用主题。
class FloatingTopBarStatusStrip extends StatelessWidget {
  const FloatingTopBarStatusStrip({super.key, required this.color});

  final Color color;

  /// 状态栏之下渐隐带的高度：铺过浮岛那一行。
  static const double fadeExtent = FloatingTopBar.extent;

  /// 此处是否渐隐（高对比度时不渐隐）。
  static bool fadesOf(BuildContext context) =>
      !MediaQuery.highContrastOf(context);

  /// 按 [theme] 的明暗给出的状态栏样式（主题里设了顶栏样式时用主题的）。
  static SystemUiOverlayStyle overlayStyleOf(ThemeData theme) {
    final isLight = theme.colorScheme.brightness == Brightness.light;
    return theme.appBarTheme.systemOverlayStyle ??
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isLight
              ? Brightness.dark
              : Brightness.light,
        );
  }

  @override
  Widget build(BuildContext context) {
    final fades = fadesOf(context);
    final height =
        MediaQuery.viewPaddingOf(context).top + (fades ? fadeExtent : 0);
    final glass = AppGlass.of(context);
    final target = glass.isGlass(AppGlassComponent.topBars)
        ? glass.solidFill
        : color;
    // 翻页换篇时底色随之过渡，不在半途硬切。
    final Widget fill = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
      builder: (BuildContext context, Color? value, Widget? _) => GlassSurface(
        fill: value ?? target,
        blur: false,
        fadeToBottom: fades,
        child: const SizedBox.expand(),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyleOf(Theme.of(context)),
      child: IgnorePointer(
        child: SizedBox(width: double.infinity, height: height, child: fill),
      ),
    );
  }
}
