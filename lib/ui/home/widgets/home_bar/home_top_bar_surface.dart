import 'package:flutter/widgets.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../widgets/glass/glass_surface.dart';
import 'home_chrome_scope.dart';

/// 首页四个 Tab（日记 / 日历 / 探索 / 设置）顶栏下缘到第一块内容的统一距离。
///
/// 四个 Tab 的顶栏结构各不相同（日记是刊头 + 钉住的标签栏，日历是可收起
/// 月份行的页头，探索 / 设置是叠在 Stack 上的 PageHeader），间距如果各写
/// 各的，有背景图时顶栏下缘一清楚，四页就会一页一个样。统一从这里取。
const double kHomeTopContentGap = AppSpacing.m;

/// 首页 Tab 顶栏的底：实色时就是页面原来画的那块颜色，玻璃时换成
/// 直角、贴边的 [GlassSurface]。
///
/// 实色分支只有一个 [ColoredBox]，不多包任何会改变布局或绘制的节点：
/// 没有 [HomeChromeScope]（独立使用、单页测试）或顶栏不用玻璃时，渲染结果
/// 与改版前逐像素一致。高对比度时玻璃退回不透明底色、不模糊（见
/// `HomeBarResolvedStyle.translucent`），但仍保留玻璃顶栏的结构。
class HomeTopBarSurface extends StatelessWidget {
  const HomeTopBarSurface({
    super.key,
    required this.solidColor,
    this.showHairline = true,
    this.grouped = false,
    required this.child,
  });

  /// 实色时的底色（页面原来画的颜色，如 surface 或日记页的页面底色）。
  final Color solidColor;

  /// 玻璃时是否允许画底部细线（还要用户打开顶栏分隔线）；日记页的多段
  /// 顶栏只让最下面一段画。
  final bool showHairline;

  /// 是否与同一 BackdropGroup 下的其他玻璃共用背景（见 [GlassSurface.grouped]）。
  final bool grouped;
  final Widget child;

  /// 顶栏下缘看不看得见：首页顶栏用玻璃（磨砂条与下方内容分得开），
  /// 或者设置要求这个 Tab 区域画背景（实色栏与透明页面底不再同色）。
  ///
  /// 背景看的是“设置要不要画”（[AppPageBackdrop.wantsBackground]）而不是
  /// “此刻画没画”：图片要异步解码，按后者判断时解码回来那一刻间距才出现，
  /// 打开首页时内容会往下跳一下。文件缺失 / 解码失败时因此会多留 12，可以
  /// 接受。
  ///
  /// 经典且没有背景时栏色与页面底同为 surface，顶栏和内容连成一片，下缘
  /// 看不出来——这时内容本就贴着顶栏排，改版前就是这样。
  static bool bottomEdgeVisibleOf(BuildContext context) =>
      HomeChromeScope.glassTopBarsOf(context) ||
      AppPageBackdrop.of(context).wantsBackground;

  /// 日记 / 设置 Tab 顶栏下缘与第一块内容之间要补的间距：下缘看得见时为
  /// [kHomeTopContentGap]，否则为 0（经典无背景与改版前逐像素一致）。
  ///
  /// 日历与探索的第一块内容本来就在页头下方固定留了同样的 12，无论有没有
  /// 背景都在，不经这里。
  static double contentGapOf(BuildContext context) =>
      bottomEdgeVisibleOf(context) ? kHomeTopContentGap : 0;

  @override
  Widget build(BuildContext context) {
    final style = HomeChromeScope.maybeStyleOf(context);
    if (style == null || !style.glassTopBars) {
      return ColoredBox(color: solidColor, child: child);
    }
    return GlassSurface(
      fill: style.fill,
      blur: style.translucent,
      blurSigma: style.blurSigma,
      bottomHairline: showHairline && style.topBarHairline
          ? style.hairlineColor
          : null,
      bottomHairlineWidth: style.hairlineWidth,
      grouped: grouped,
      child: child,
    );
  }
}

/// 实色顶栏时把状态栏那一条垫成顶栏色。
///
/// 日记页实色时用 SafeArea 让出状态栏，刊头从状态栏线以下开始画；状态栏
/// 那一条原本由页面底色垫着，与顶栏同为 surface。区域画了背景后页面底变
/// 透明，那一条就露出背景，下面的顶栏却仍是实色，看起来断成两截。这里在
/// [child] 之下垫一条 [color] 色、高为状态栏高度的底，顶栏视觉上从屏幕顶端
/// 一直延伸到它的下缘，与没有背景时一致。
///
/// [color] 一般取 [colorOf]；为 null 时不画（玻璃顶栏铺到状态栏，或没有
/// 背景时由同色的页面底垫着，画面与改版前逐像素一致）。结构始终是同一个
/// Stack、[child] 始终在同一位置，切换材质或背景时列表不会被重新挂载、滚动
/// 位置不丢。
class HomeStatusBarFill extends StatelessWidget {
  const HomeStatusBarFill({
    super.key,
    required this.color,
    required this.child,
  });

  /// 状态栏那一条的底色；null 时不画。
  final Color? color;
  final Widget child;

  /// 首页 Tab 页面该垫的颜色：实色顶栏且设置要求这个区域画背景时为实色栏
  /// 底色（[AppPageBackdrop.solidBarColor]），否则为 null。
  ///
  /// 同样按 [AppPageBackdrop.wantsBackground] 而不是解码进度判断：图片还在
  /// 解码时 solidBarColor 就是 surface，垫上与解码完成后一样，不会闪。没有
  /// 背景时本就由同色的页面底垫着，不必画；玻璃顶栏自己铺到状态栏。
  static Color? colorOf(BuildContext context) {
    if (HomeChromeScope.glassTopBarsOf(context)) return null;
    final backdrop = AppPageBackdrop.of(context);
    return backdrop.wantsBackground ? backdrop.solidBarColor : null;
  }

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    final top = MediaQuery.paddingOf(context).top;
    // 色条不用 Positioned：Positioned 的宽度取决于 Stack，而 passthrough 的
    // Stack 只跟着 [child] 的大小走——child 在宽松约束下缩成一点（如
    // Scaffold body 里尚未出现的加载指示器）时色条也跟着没了。改成铺满可用
    // 区域的 Align，Stack 至少与可用区域一样大，[child] 仍按原约束布局、
    // 停在左上角，与直接放进 body 时的位置相同。
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        // 只是垫底的颜色，点按交给上面的内容与系统（如点状态栏回到顶部）。
        IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              height: top,
              child: color == null || top <= 0
                  ? null
                  : ColoredBox(color: color),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
