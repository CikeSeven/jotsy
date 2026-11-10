import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';
import 'home_nav_block.dart';
import 'home_nav_destination.dart';

/// 底部导航栏单项配置。
class BottomNavItem {
  const BottomNavItem({required this.label, required this.icon});

  final String label;
  final FaIconData icon;
}

/// 首页底栏的导航项一行（取代 Material `NavigationBar`）。
///
/// 输入：导航项、选中项、点按回调、已解析的首页栏样式 [style]，可选的栏高
/// [height]（缺省取 `style.barHeight`）与页面位置 [position]；输出：一行
/// 等宽的导航项，不画底色（玻璃底色与外框由悬浮底栏负责）。
///
/// - 结构、尺寸与语义照搬 M3 `NavigationBar`（见 home_nav_layout.dart /
///   home_nav_destination.dart），颜色取 [style] 的前景色与指示器色；
/// - 指示器只有一个，在导航项之间滑动（位置是一个小数序号）：
///   - [position] 为空：选中项变化时由本组件的弹簧推到新的一项
///     （[ExpressiveMotion.springIndicator]，略微过冲；连点时带着速度改道），
///     途中按速度横向拉长一点，像一滴被拖着走的水；
///   - [position] 非空（“指示器跟随滑动”）：跟着页面的小数位置走，图标、
///     文字的选中程度也按它插值，没有弹簧；
/// - 语义上的“已选中”始终按 [selectedIndex]。
class HomeNavBar extends StatefulWidget {
  const HomeNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.style,
    this.height,
    this.position,
  });

  /// 导航项，至少一项（空态由调用方处理，悬浮底栏此时只画空胶囊）。
  final List<BottomNavItem> items;

  /// 选中项；越界时夹到有效范围（Tab 集合变化的那一帧可能短暂越界）。
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final HomeBarResolvedStyle style;
  final double? height;

  /// 页面位置（如 PageController.page）；null 时指示器由弹簧滑向选中项。
  final ValueListenable<double>? position;

  @override
  State<HomeNavBar> createState() => _HomeNavBarState();
}

/// 持有两样跨帧的东西：各项共享的内容尺寸（指示器滑动途中推算相邻一项的
/// 圆角块大小，见 [HomeNavContentMetrics]）与指示器的弹簧位置。
class _HomeNavBarState extends State<HomeNavBar>
    with SingleTickerProviderStateMixin {
  /// 弹簧停稳的阈值：位置以“项”为单位，千分之一项不到 0.1 像素。
  static const Tolerance _settleTolerance = Tolerance(
    distance: 0.001,
    velocity: 0.01,
  );

  final HomeNavContentMetrics _metrics = HomeNavContentMetrics();

  /// 指示器的位置（小数序号），无界：弹簧会越过目标再回落。跟随滑动时
  /// 不用它，但值保持对齐选中项，关掉跟随的那一刻指示器不会跳。
  late final AnimationController _indicator = AnimationController.unbounded(
    vsync: this,
    value: _clampedIndex.toDouble(),
  );

  int get _clampedIndex =>
      widget.selectedIndex.clamp(0, widget.items.length - 1);

  double _indicatorVelocity() =>
      _indicator.isAnimating ? _indicator.velocity : 0;

  @override
  void didUpdateWidget(HomeNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _clampedIndex.toDouble();
    if (widget.position != null ||
        oldWidget.items.length != widget.items.length) {
      // 跟随滑动时位置由页面给出；Tab 集合变化（功能管理开关）时旧序号
      // 已不对应同一项，滑过去只会经过无关的项——两种情况都直接到位。
      _indicator.value = target;
      return;
    }
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.position != null) {
      ExpressiveMotion.springTo(
        context,
        _indicator,
        target,
        spring: ExpressiveMotion.springIndicator,
        tolerance: _settleTolerance,
      );
    }
  }

  @override
  void dispose() {
    _indicator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final items = widget.items;
    final position = widget.position;
    final colors = HomeNavColors.resolve(Theme.of(context), style);
    final barHeight = widget.height ?? style.barHeight;
    final selected = _clampedIndex;
    final duration = ExpressiveMotion.duration(context);
    // 透明 Material 承载指示器（Ink）与水波纹，底色由外层负责。
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        role: SemanticsRole.tabBar,
        explicitChildNodes: true,
        container: true,
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: <Widget>[
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: MergeSemantics(
                    child: Semantics(
                      role: SemanticsRole.tab,
                      selected: i == selected,
                      child: HomeNavSelectionAnimator(
                        selected: i == selected,
                        duration: duration,
                        builder:
                            (
                              BuildContext context,
                              Animation<double> selection,
                              Animation<double> labelCurve,
                            ) => HomeNavDestination(
                              index: i,
                              count: items.length,
                              icon: items[i].icon,
                              label: items[i].label,
                              selected: i == selected,
                              selection: selection,
                              labelCurve: labelCurve,
                              position: position,
                              indicatorPosition: position ?? _indicator,
                              indicatorVelocity: position == null
                                  ? _indicatorVelocity
                                  : null,
                              labelMode: style.labelMode,
                              iconSize: style.iconSize,
                              indicator: style.indicator,
                              labelGap: style.labelGap,
                              blockPadding: style.blockPadding,
                              cornerRadius: style.cornerRadius,
                              barHeight: barHeight,
                              metrics: _metrics,
                              colors: colors,
                              onTap: () => widget.onTap(i),
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 每项自己的选中动画：选中时 0→1、取消时 1→0，时长取 ExpressiveMotion
/// （减少动画时为 0，直接跳到终点）。另给出文字显现用的曲线版本，
/// 正向 effects、反向 exit（与 effects 对称），由本 State 持有并释放。
/// 底栏与宽窗口的侧边导航栏共用，两处的选中动画节奏一致。
class HomeNavSelectionAnimator extends StatefulWidget {
  const HomeNavSelectionAnimator({
    super.key,
    required this.selected,
    required this.duration,
    required this.builder,
  });

  final bool selected;
  final Duration duration;
  final Widget Function(
    BuildContext context,
    Animation<double> selection,
    Animation<double> labelCurve,
  )
  builder;

  @override
  State<HomeNavSelectionAnimator> createState() =>
      _HomeNavSelectionAnimatorState();
}

class _HomeNavSelectionAnimatorState extends State<HomeNavSelectionAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.selected ? 1 : 0,
  );
  late final CurvedAnimation _labelCurve = CurvedAnimation(
    parent: _controller,
    curve: ExpressiveMotion.effects,
    reverseCurve: ExpressiveMotion.exit,
  );

  @override
  void didUpdateWidget(HomeNavSelectionAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.selected != widget.selected) {
      if (widget.selected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _labelCurve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _controller, _labelCurve);
}
