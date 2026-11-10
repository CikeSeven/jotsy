import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/launch_reveal.dart';
import '../../models/home_bar_style/home_bar_metrics.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';
import 'home_floating_bar.dart';
import 'home_nav_bar.dart';

/// 首页 `Scaffold.bottomNavigationBar` 槽位里的底栏：居中悬浮的玻璃胶囊，
/// 并负责启动编排与“滚动时隐藏”的位移。
///
/// 输入：导航项、选中项、点按回调、已解析样式 [style]、页面位置
/// [position]、并排新建按钮 [inlineAction] 与是否显示，以及 [hidden]（滚动
/// 隐藏的结果，由首页决定）；输出：槽位内容，无副作用。
///
/// - 胶囊按内容定宽、水平居中（见 [HomeFloatingBar]），左右至少留
///   [HomeBarMetrics.minSideMargin]，下方留系统手势条 + bottomGap（且不少于
///   [HomeBarMetrics.minBottomSpace]，见 [HomeBarMetrics.bottomSpace]）；胶囊之外
///   的部分透明且不拦截点按。系统手势条取 viewPadding，首页不随键盘缩放
///   （resizeToAvoidBottomInset: false），键盘弹出时底栏不跟着上移；
/// - 隐藏时整条向下移出屏幕（连同投影），从不淡出玻璃；位移由弹簧驱动
///   （见 [_HomeBarSlide]）；
/// - 启动编排用 [LaunchReveal.builder]，玻璃只经 `progress` 显现，绝不放进
///   Opacity。
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

  /// 悬浮底栏在屏幕底部占用的高度（胶囊 + 底部间距 + 系统手势条）；
  /// FAB 等浮在底栏上方的元素按它让位。
  static double floatingSlotExtent(
    BuildContext context,
    HomeBarResolvedStyle style,
  ) =>
      style.barHeight +
      style.bottomSpace(MediaQuery.viewPaddingOf(context).bottom);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomSpace = style.bottomSpace(bottomInset);
    final hiddenOffset = style.barHeight + bottomSpace + hiddenShadowAllowance;
    return Padding(
      padding: EdgeInsets.only(
        left: HomeBarMetrics.minSideMargin,
        right: HomeBarMetrics.minSideMargin,
        bottom: bottomSpace,
      ),
      child: _HomeBarSlide(
        offset: hidden ? hiddenOffset : 0,
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

/// 把 [child] 向下平移 [offset]，目标变化时用弹簧过渡。
///
/// 位移而不是淡出：玻璃不能放进透明度层。用真弹簧而不是补间：滚动方向
/// 来回变时目标会在动画中途翻转，弹簧带着当前速度掉头，不会先停一下再从
/// 零速起步；出现时略微越过终点再落回（约 2%），收起时的过冲在屏幕外。
/// 减少动画时直接到位。首帧不播动画：一出现就在目标位置。
class _HomeBarSlide extends StatefulWidget {
  const _HomeBarSlide({required this.offset, required this.child});

  final double offset;
  final Widget child;

  @override
  State<_HomeBarSlide> createState() => _HomeBarSlideState();
}

class _HomeBarSlideState extends State<_HomeBarSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dy = AnimationController.unbounded(
    vsync: this,
    value: widget.offset,
  );

  @override
  void didUpdateWidget(_HomeBarSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offset != widget.offset) {
      ExpressiveMotion.springTo(context, _dy, widget.offset);
    }
  }

  @override
  void dispose() {
    _dy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _dy,
    builder: (BuildContext context, Widget? child) =>
        Transform.translate(offset: Offset(0, _dy.value), child: child),
    child: widget.child,
  );
}
