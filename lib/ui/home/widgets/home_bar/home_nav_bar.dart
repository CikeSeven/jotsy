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

/// 首页底栏的导航项一行（取代 Material `NavigationBar`），实色与玻璃两种
/// 材质共用，因此文字模式、图标大小、指示器样式与跟随滑动在实色栏也生效。
///
/// 输入：导航项、选中项、点按回调、已解析的首页栏样式 [style]，可选的栏高
/// [height]（缺省取 `style.barHeight`）与页面位置 [position]；输出：一行
/// 等宽的导航项，不画底色（底色、SafeArea 与外框由 BottomNav /
/// 悬浮底栏负责）。
///
/// - 默认样式（始终显示文字、图标 20、胶囊、不跟随）与改版前的
///   `NavigationBar` 逐像素一致：结构、尺寸、语义与动画照搬 M3（见
///   home_nav_layout.dart / home_nav_destination.dart）；
/// - 颜色：玻璃材质（`style.isGlass`，高对比度下仍为 true）用 style 的前景色
///   与指示器色；实色沿用主题（选中图标 onSecondaryContainer、未选中
///   onSurfaceVariant、指示器 secondaryContainer，文字取 navigationBarTheme）；
/// - [position] 非空时指示器跟着页面的小数位置在相邻两项间连续移动；
///   语义上的“已选中”始终按 [selectedIndex]。
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

  /// 导航项，至少一项（空态由调用方处理，如 BottomNav 不画栏）。
  final List<BottomNavItem> items;

  /// 选中项；越界时夹到有效范围（Tab 集合变化的那一帧可能短暂越界）。
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final HomeBarResolvedStyle style;
  final double? height;

  /// 页面位置（如 PageController.page）；null 时指示器只在选中变化时动画。
  final ValueListenable<double>? position;

  @override
  State<HomeNavBar> createState() => _HomeNavBarState();
}

/// 有状态只为持有各项共享的内容尺寸（跟随滑动时推算相邻一项的圆角块
/// 大小，见 [HomeNavContentMetrics]），它要跨帧保留。
class _HomeNavBarState extends State<HomeNavBar> {
  final HomeNavContentMetrics _metrics = HomeNavContentMetrics();

  int get _clampedIndex =>
      widget.selectedIndex.clamp(0, widget.items.length - 1);

  HomeNavColors _colors(ThemeData theme) {
    final style = widget.style;
    final scheme = theme.colorScheme;
    final labelTheme = theme.navigationBarTheme.labelTextStyle;
    final base = theme.textTheme.labelMedium ?? const TextStyle();
    // 与 M3 NavigationBar 取文字样式的顺序一致：主题优先，缺省用 M3 默认。
    final selectedLabel =
        labelTheme?.resolve(const <WidgetState>{WidgetState.selected}) ??
        base.apply(color: scheme.onSurface);
    final unselectedLabel =
        labelTheme?.resolve(const <WidgetState>{}) ??
        base.apply(color: scheme.onSurfaceVariant);
    if (!style.isGlass) {
      return HomeNavColors(
        indicator: scheme.secondaryContainer,
        selectedIcon: scheme.onSecondaryContainer,
        unselectedIcon: scheme.onSurfaceVariant,
        selectedLabel: selectedLabel,
        unselectedLabel: unselectedLabel,
      );
    }
    return HomeNavColors(
      indicator: style.indicatorColor,
      selectedIcon: style.selectedForeground,
      unselectedIcon: style.unselectedForeground,
      selectedLabel: selectedLabel.copyWith(color: style.selectedForeground),
      unselectedLabel: unselectedLabel.copyWith(
        color: style.unselectedForeground,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final items = widget.items;
    final position = widget.position;
    final colors = _colors(Theme.of(context));
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
                      child: _SelectionAnimator(
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
class _SelectionAnimator extends StatefulWidget {
  const _SelectionAnimator({
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
  State<_SelectionAnimator> createState() => _SelectionAnimatorState();
}

class _SelectionAnimatorState extends State<_SelectionAnimator>
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
  void didUpdateWidget(_SelectionAnimator oldWidget) {
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
