// 宽窗口（≥ 600dp）首页左侧的导航栏，取代底栏。
//
// 输入：导航项（从上往下排）、选中项、点按回调、已解析的首页栏样式与顶部
// 的新建按钮；输出：96dp 宽、铺满高度的竖栏，无副作用。设置不是 Tab，不在
// 这里（从日记页顶栏“更多”进入）。
//
// - 底色默认与页面连成一片，给玻璃染了色时改用它的不透明等效色（见
//   [HomeNavRail.backgroundOf]）；从不画玻璃：侧边栏下面没有会滚过去的
//   内容，模糊没有意义；也不画分隔线；
// - 导航项与底栏同一套视觉口径（见 [HomeNavRailDestination]）：同样大小
//   的一格、同样的图标与文字、铺满一格的胶囊指示器，颜色经
//   [HomeNavColors.resolve]，文字模式读 [HomeBarResolvedStyle]，选中动画
//   复用 [HomeNavSelectionAnimator]；
// - 指示器区域有悬停 8% / 焦点 12% 的状态层（光标随平台默认，与应用里
//   其他按钮一致），文字不显示时给长按 / 悬停提示；
// - 高度不够（矮窗口、超大字体）时整列可滚动，不溢出。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_breakpoints.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../app_surface/widgets/app_glass_fab.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../app_surface/widgets/app_glass_surface.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../widgets/launch_reveal.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';
import 'home_nav_bar.dart';
import 'home_nav_colors.dart';
import 'home_nav_rail_destination.dart';

export 'home_nav_rail_destination.dart';

/// 宽窗口首页的左侧导航栏。
class HomeNavRail extends StatelessWidget {
  const HomeNavRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.style,
    this.leading,
  });

  /// 栏顶与新建按钮之间的留白；列放不下而滚动时也是最后一项下方的留白。
  static const double edgePadding = 16;

  /// 新建按钮与第一个导航项之间的距离。
  static const double leadingGap = 28;

  /// 相邻导航项之间的距离（不含导航项自身上下的 [itemPadding]）：上一格
  /// 的底到下一格的顶共 itemSpacing + 2 × itemPadding = 8。
  static const double itemSpacing = 4;

  /// 每个导航项上下各自的内边距，算进点按区域。栏顶 / 栏底的留白与新建按钮
  /// 下方的间距扣掉它，第一格到新建按钮仍是 [leadingGap]、滚到底时最后一格
  /// 到栏底仍是 [edgePadding]。
  static const double itemPadding = HomeNavRailDestination.verticalPadding;

  /// 侧边栏底色。侧边栏不模糊，是一整条不透明的表面：
  /// - 玻璃染了主题色调（`style.tinted`）：用玻璃底色的不透明等效色
  ///   solidFill，与高对比度下的悬浮底栏同一颜色——宽窗口下同样看得到；
  /// - 中性色调（默认）：与页面连成一片。当前 Tab 区域设了背景时
  ///   （[backdrop] 实际在画）取该区域的实色栏底色——纯色背景时与页面同色，
  ///   图片背景时保持不透明的 surface；没有背景时取 navigationBarTheme 的
  ///   背景色（亮色与页面画布同色，暗色 surfaceContainer）。
  static Color backgroundOf(
    ThemeData theme,
    HomeBarResolvedStyle style, {
    AppPageBackdrop? backdrop,
  }) {
    if (style.tinted) {
      return style.solidFill;
    }
    if (backdrop != null && backdrop.hasBackground) {
      return backdrop.solidBarColor;
    }
    return theme.navigationBarTheme.backgroundColor ??
        theme.colorScheme.surfaceContainer;
  }

  /// 导航项（至少一项），从新建按钮下方往下排。
  final List<BottomNavItem> items;

  /// 选中项；越界时夹到有效范围（Tab 集合变化的那一帧可能短暂越界）。
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final HomeBarResolvedStyle style;

  /// 栏顶的主操作（新建按钮，见 [HomeNavRailCreateButton]）。
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final selected = count == 0 ? 0 : selectedIndex.clamp(0, count - 1);
    final colors = HomeNavColors.resolve(Theme.of(context), style);
    final duration = ExpressiveMotion.duration(context);

    Widget item(int index) => HomeNavSelectionAnimator(
      selected: index == selected,
      duration: duration,
      builder: (context, selection, labelCurve) => HomeNavRailDestination(
        icon: items[index].icon,
        label: items[index].label,
        selected: index == selected,
        selection: selection,
        labelCurve: labelCurve,
        style: style,
        colors: colors,
        onTap: () => onTap(index),
      ),
    );

    final column = Column(
      children: <Widget>[
        const SizedBox(height: edgePadding),
        if (leading != null) ...<Widget>[
          leading!,
          const SizedBox(height: leadingGap - itemPadding),
        ],
        for (var i = 0; i < count; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: itemSpacing),
          item(i),
        ],
        const SizedBox(height: edgePadding - itemPadding),
      ],
    );

    return LaunchReveal(
      slot: LaunchRevealSlot.navigation,
      // 透明度以外的材质：Material 承载指示器（Ink）与水波纹。
      child: Material(
        color: backgroundOf(
          Theme.of(context),
          style,
          backdrop: AppPageBackdrop.maybeOf(context),
        ),
        child: SizedBox(
          width: AppContentWidth.navRail,
          // 只避让侧边栏所在一侧（从右到左的语言下栏在右侧）与上下的系统
          // 内边距，另一侧挨着页面区。
          child: SafeArea(
            left: Directionality.of(context) == TextDirection.ltr,
            right: Directionality.of(context) == TextDirection.rtl,
            // 矮窗口或超大字体放不下时整列滚动；放得下时铺满高度（底色
            // 到底），导航项靠上。
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: CustomScrollView(
                primary: false,
                slivers: <Widget>[
                  SliverFillRemaining(hasScrollBody: false, child: column),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 侧边栏顶部的新建按钮：56×56、圆角 16 的 FAB（primaryContainer），
/// 文字只作提示与读屏（与紧凑窗口的全局 FAB 同一文案）。
class HomeNavRailCreateButton extends StatelessWidget {
  const HomeNavRailCreateButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  static const double size = 56;
  static const double radius = 16;

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = AppGlass.of(context).isGlass(AppGlassComponent.controls);
    final button = FloatingActionButton(
      // 同一路由里可能还有别的 FAB（各 Tab 页面），不参与 Hero 飞行。
      heroTag: null,
      tooltip: label,
      onPressed: onPressed,
      // 玻璃时底色交给外面的玻璃表面（AppGlassFab 经局部主题把它换成透明）。
      backgroundColor: glass ? null : scheme.primaryContainer,
      // 前景同理：玻璃时交给 AppGlassFab 的局部主题（含对比度兜底）。
      foregroundColor: glass ? null : scheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const FaIcon(FontAwesomeIcons.plus, size: 20),
    );
    if (!glass) return button;
    // 侧栏上没有可模糊的内容（下面只有侧栏自己的底色 / 页面背景），不模糊，
    // 只要主色半透明底色。调用方负责入场不经透明度层（GlassReveal）。
    return AppGlassFab(
      borderRadius: BorderRadius.circular(radius),
      blur: AppGlassBlur.none,
      child: button,
    );
  }
}
