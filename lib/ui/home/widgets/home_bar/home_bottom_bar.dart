import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/bottom_nav.dart';
import '../../../widgets/launch_reveal.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';
import 'home_floating_bar.dart';

/// 首页 `Scaffold.bottomNavigationBar` 槽位里的底栏：按材质在实色贴底栏与
/// 玻璃悬浮胶囊之间切换，并负责启动编排与“滚动时隐藏”的位移。
///
/// 输入：导航项、选中项、点按回调、已解析样式 [style]、页面位置
/// [position]、并排新建按钮 [inlineAction] 与是否显示，以及 [hidden]（滚动
/// 隐藏的结果，由首页决定）；输出：槽位内容，无副作用。
///
/// - 实色：与改版前完全相同的 `LaunchReveal(navigation) → BottomNav`（启动
///   测试依赖每个槽位下的 Opacity）；实色栏不响应 [hidden]；
/// - 玻璃：外边距（左右 sideMargin、下方系统手势条 + bottomGap）在胶囊之外，
///   透明且不拦截点按；系统手势条取 viewPadding，首页不随键盘缩放
///   （resizeToAvoidBottomInset: false），键盘弹出时底栏不跟着上移；
///   隐藏时整条向下移出屏幕（连同投影），从不淡出玻璃；启动编排用
///   [LaunchReveal.builder]，玻璃只经 `progress` 显现，绝不放进 Opacity。
class HomeBottomBar extends StatelessWidget {
  const HomeBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.style,
    this.position,
    this.inlineAction,
    this.showInlineAction = false,
    this.hidden = false,
  });

  /// 隐藏时在栏高、底部间距与手势条之外再多移的距离，让投影也完全离开屏幕。
  static const double hiddenShadowAllowance = 32;

  final List<BottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final HomeBarResolvedStyle style;
  final ValueListenable<double>? position;
  final Widget? inlineAction;
  final bool showInlineAction;
  final bool hidden;

  /// 玻璃悬浮底栏在屏幕底部占用的高度（胶囊 + 底部间距 + 系统手势条）；
  /// FAB 等浮在底栏上方的元素按它让位。
  static double floatingSlotExtent(
    BuildContext context,
    HomeBarResolvedStyle style,
  ) =>
      style.barHeight +
      style.bottomGap +
      MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    if (!style.isGlass) {
      return LaunchReveal(
        slot: LaunchRevealSlot.navigation,
        child: BottomNav(
          items: items,
          selectedIndex: selectedIndex,
          onTap: onTap,
          style: style,
          position: position,
        ),
      );
    }
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final hiddenOffset =
        style.barHeight + style.bottomGap + bottomInset + hiddenShadowAllowance;
    return Padding(
      padding: EdgeInsets.only(
        left: style.sideMargin,
        right: style.sideMargin,
        bottom: bottomInset + style.bottomGap,
      ),
      // 位移而不是淡出：玻璃不能放进透明度层。TweenAnimationBuilder 从当前值
      // 补间到新终点，滚动中途反向时不会跳变；减少动画时长为 0，直接到位。
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: hidden ? hiddenOffset : 0),
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.standard),
        curve: ExpressiveMotion.spatial,
        builder: (BuildContext context, double dy, Widget? child) =>
            Transform.translate(offset: Offset(0, dy), child: child),
        child: LaunchReveal.builder(
          slot: LaunchRevealSlot.navigation,
          builder: (BuildContext context, double opacity, Widget? _) =>
              HomeFloatingBar(
                items: items,
                selectedIndex: selectedIndex,
                onTap: onTap,
                style: style,
                position: position,
                progress: opacity,
                inlineAction: inlineAction,
                showInlineAction: showInlineAction,
              ),
        ),
      ),
    );
  }
}
