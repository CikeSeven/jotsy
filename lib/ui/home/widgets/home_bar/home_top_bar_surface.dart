import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../widgets/glass/glass_surface.dart';
import 'home_chrome_scope.dart';

/// 首页各 Tab（日记 / 待办 / 日历 / 探索）顶栏下缘到第一块内容的统一距离。
///
/// 各 Tab 的顶栏结构各不相同（日记是刊头 + 钉住的标签栏，日历是可收起
/// 月份行的页头，待办 / 探索是叠在 Stack 上的 PageHeader），间距如果各写
/// 各的，有背景图时顶栏下缘一清楚，几页就会一页一个样。统一从这里取。
const double kHomeTopContentGap = AppSpacing.m;

/// 由上下几片拼成的顶栏（日记页：浮动的刊头 + 钉住的标签栏）里，上面各片
/// 此刻露出来的总高度：上面的片（[HomeTopBarSurface.upper]）在布局时写入，
/// 最下面那片的玻璃据此知道自己往上铺的那截露出来多少，渐变从露出来的上缘
/// 起算。由页面的 State 持有并传给各片。
///
/// 高度在布局阶段才知道，所以走监听 + 重画，不经过重建；上面的片先布局、
/// 两片都布局完才绘制，不会错开一帧。
class HomeTopBarStackLink extends ValueNotifier<double> {
  HomeTopBarStackLink() : super(0);
}

/// 首页 Tab 顶栏的底：在首页之下（有 [HomeChromeScope]）恒为直角、贴边的
/// [GlassSurface]，与悬浮底栏同一配方（底色、模糊、饱和度）。
///
/// 没有 [HomeChromeScope]（独立使用、单页测试）时只有一个 [ColoredBox]，
/// 不多包任何会改变布局或绘制的节点，画的就是页面原来的那块颜色。高对比度
/// 时玻璃退回不透明底色、不模糊（见 `HomeBarResolvedStyle.translucent`），
/// 但仍保留玻璃顶栏的结构。
///
/// 透明度：整条顶栏自上而下逐渐变透明——从顶栏露出来的上缘（屏幕顶端）
/// 到下缘，底色与模糊一起由完整淡到没有（见
/// `HomeBarResolvedStyle.topBarFades`）；滚到栏下的内容越靠近下缘越清楚，
/// 下缘处与页面连成一片，没有硬边。栏里的文字与按钮不跟着变淡。用户打开
/// 顶栏分隔线时改为均匀的玻璃加一条细线，高对比度时为不透明的实边。渐变
/// 按顶栏当时的高度铺：日历月份行收起、日记刊头收起或标签栏展开时都跟着。
///
/// 由上下几片拼成的顶栏只有一块玻璃：最下面一片用默认构造、经
/// [glassAbove] 把玻璃往上铺到上面各片之后，下缘也由它处理；上面的片用
/// [HomeTopBarSurface.upper]，只画内容，并经同一个 [link] 报上自己的高度。
/// 原因见 `GlassSurface.extendAbove`。
class HomeTopBarSurface extends StatelessWidget {
  /// 自己画玻璃的一片：单片的顶栏，或多片顶栏最下面的那一片。
  const HomeTopBarSurface({
    super.key,
    required this.solidColor,
    this.glassAbove = 0,
    this.link,
    required this.child,
  }) : _upper = false;

  /// 多片顶栏里叠在玻璃那一片上方的片：在首页之下不画底、只画内容，底由
  /// 下面那一片的玻璃（[glassAbove]）垫着，并把自己的高度写进 [link]；
  /// 不在首页之下时仍是自己的 [ColoredBox]。
  const HomeTopBarSurface.upper({
    super.key,
    required this.solidColor,
    required HomeTopBarStackLink this.link,
    required this.child,
  }) : glassAbove = 0,
       _upper = true;

  /// 不在首页之下时的底色（页面原来画的颜色，如 surface 或日记页的页面
  /// 底色）。
  final Color solidColor;

  /// 玻璃越过这一片的上缘再往上铺多高，垫到用 [HomeTopBarSurface.upper]
  /// 构建、叠在它上方的那几片之后：取上面各片可能的最大总高度，铺过头的
  /// 部分落在滚动视图之外。单片的顶栏为 0。
  final double glassAbove;

  /// 多片顶栏各片共用的纽带（见 [HomeTopBarStackLink]）：上面的片写入
  /// 自己的高度，最下面一片据此知道往上铺的那截露出来多少。单片的顶栏
  /// 不用传。
  final HomeTopBarStackLink? link;

  final bool _upper;
  final Widget child;

  /// 顶栏下缘看不看得见：在首页之下顶栏恒为玻璃（磨砂条与下方内容分得
  /// 开），或者设置要求这个 Tab 区域画背景（实色栏与透明页面底不再同色）。
  ///
  /// 背景看的是“设置要不要画”（[AppPageBackdrop.wantsBackground]）而不是
  /// “此刻画没画”：图片要异步解码，按后者判断时解码回来那一刻间距才出现，
  /// 打开首页时内容会往下跳一下。文件缺失 / 解码失败时因此会多留 12，可以
  /// 接受。
  ///
  /// 不在首页之下且没有背景时栏色与页面底同为 surface，顶栏和内容连成
  /// 一片，下缘看不出来——这时内容本就贴着顶栏排。
  static bool bottomEdgeVisibleOf(BuildContext context) =>
      HomeChromeScope.glassTopBarsOf(context) ||
      AppPageBackdrop.of(context).wantsBackground;

  /// 日记 Tab 顶栏下缘与第一块内容之间要补的间距：下缘看得见时为
  /// [kHomeTopContentGap]，否则为 0（经典无背景与改版前逐像素一致）。
  ///
  /// 日历与探索的第一块内容本来就在页头下方固定留了同样的 12，无论有没有
  /// 背景都在，不经这里。
  static double contentGapOf(BuildContext context) =>
      bottomEdgeVisibleOf(context) ? kHomeTopContentGap : 0;

  @override
  Widget build(BuildContext context) {
    final style = HomeChromeScope.maybeStyleOf(context);
    if (style == null) {
      return ColoredBox(color: solidColor, child: child);
    }
    if (_upper) {
      // 底由下面那片的玻璃垫着；透明的 Material 接住按钮的水波纹，否则墨迹
      // 会画到更外层、被玻璃盖住的 Material 上。
      return _ReportExtent(
        link: link!,
        child: Material(type: MaterialType.transparency, child: child),
      );
    }
    return GlassSurface(
      fill: style.fill,
      blur: style.translucent,
      blurSigma: style.blurSigma,
      saturation: style.saturation,
      bottomHairline: style.topBarHairline ? style.hairlineColor : null,
      // 不渐变时传 false 而不是 null：渐变用的节点一直在，打开分隔线或系统
      // 切换高对比度时栏里的内容不会被重新挂载。
      fadeToBottom: style.topBarFades,
      extendAbove: glassAbove,
      extendAboveVisible: glassAbove > 0 ? link : null,
      child: child,
    );
  }
}

/// 把自己的高度在布局时写进 [link]（多片顶栏上面的片用）。
class _ReportExtent extends SingleChildRenderObjectWidget {
  const _ReportExtent({required this.link, super.child});

  final HomeTopBarStackLink link;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportExtent(link);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReportExtent renderObject,
  ) {
    renderObject.link = link;
  }
}

class _RenderReportExtent extends RenderProxyBox {
  _RenderReportExtent(this._link);

  HomeTopBarStackLink _link;
  set link(HomeTopBarStackLink value) {
    if (identical(value, _link)) return;
    _link = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    // 监听者只有下面那片玻璃的画笔（markNeedsPaint），布局阶段通知是允许
    // 的；高度没变时 ValueNotifier 不通知。
    _link.value = size.height;
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
