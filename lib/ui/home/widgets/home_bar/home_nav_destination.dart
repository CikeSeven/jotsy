import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../models/home_bar_style/home_bar_metrics.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';
import '../../models/home_bar_style/home_bar_style.dart';
import 'home_nav_colors.dart';
import 'home_nav_geometry.dart';

export 'home_nav_colors.dart';
export 'home_nav_ink_response.dart';

/// 首页底栏的一个导航项（[HomeNavBar] 内部使用）：一格固定大小的点按区，
/// 图标在上、文字在下，整体在格子里居中。不画指示器——整行共用的那一颗由
/// 导航行画在所有项的下面。
///
/// 图标大小、文字字号、两者间距与指示器圆角取自已解析样式 [style]。
///
/// 语义照搬 Material `NavigationDestination`：按钮 + “第 x 个标签，共 y
/// 个”、长按提示；焦点 / 悬停高亮裁成与指示器相同的形状。
///
/// 图标与文字的选中程度有两种来源：
/// - 未跟随滑动（[position] 为空）：颜色与文字的淡入按 [labelCurve] 渐变
///   （不越界）；图标的放大、“只显示选中项文字”时文字的展开由本项的弹簧
///   [_pop] 驱动——选中的一刻带一个初速度，图标弹过头一点再落回。指示器
///   滑过中间项时它们不变色：只有新旧两项在过渡；
/// - 跟随滑动（[position] 非空）：都按与页面位置的距离逐帧插值，没有弹簧
///   （弹簧会落后于手指）。
///
/// 按下时内容缩小一点，松手弹回并略微弹大：听原始指针事件而不是
/// InkWell 的 onTapDown——长按提示也在手势竞技场里，点按要等 100ms 才判定
/// “按下”，轻点时按下与抬起在同一帧到达，缩放根本来不及出现。减少动画时
/// 没有缩放，其余直接到位。
class HomeNavDestination extends StatefulWidget {
  const HomeNavDestination({
    super.key,
    required this.index,
    required this.count,
    required this.icon,
    required this.label,
    required this.selected,
    required this.labelCurve,
    required this.position,
    required this.style,
    required this.colors,
    required this.onTap,
  });

  final int index;
  final int count;
  final FaIconData icon;
  final String label;
  final bool selected;

  /// 本项选中动画的渐变值（0 未选中、1 选中，不越界）：颜色与文字淡入。
  final Animation<double> labelCurve;

  /// 页面位置；非空时图标与文字的选中程度跟随它（“指示器跟随滑动”）。
  final ValueListenable<double>? position;
  final HomeBarResolvedStyle style;
  final HomeNavColors colors;
  final VoidCallback onTap;

  @override
  State<HomeNavDestination> createState() => _HomeNavDestinationState();
}

class _HomeNavDestinationState extends State<HomeNavDestination>
    with TickerProviderStateMixin {
  /// 按压程度：0 松开、1 按到底；无界，松手时越过 0 再回落（内容略微弹大）。
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  /// 未跟随滑动时的选中程度（弹簧）：0 未选中、1 选中；无界，选中时弹过头。
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(HomeNavDestination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) {
      return;
    }
    final target = widget.selected ? 1.0 : 0.0;
    if (widget.position != null) {
      // 跟随滑动时不用弹簧，但值保持对齐：关掉跟随的那一刻图标不会跳。
      _pop.value = target;
      return;
    }
    ExpressiveMotion.springTo(
      context,
      _pop,
      target,
      spring: ExpressiveMotion.springSpatialFast,
      // 只在选中时弹一下；取消选中安静地收回。
      kick: widget.selected ? HomeNavGeometry.popKick : 0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    // 减少动画时不做按压缩放：没有过渡的缩小再复原只是一下闪动。
    if (ExpressiveMotion.reduceMotion(context)) {
      return;
    }
    ExpressiveMotion.springTo(
      context,
      _press,
      pressed ? 1 : 0,
      spring: ExpressiveMotion.springSpatialFast,
    );
  }

  /// 选中程度 [t]（0~1）下的颜色；端点直接取原色，不经插值。
  static Color _mixColor(Color from, Color to, double t) =>
      t <= 0 ? from : (t >= 1 ? to : Color.lerp(from, to, t)!);

  static TextStyle _mixStyle(TextStyle from, TextStyle to, double t) =>
      t <= 0 ? from : (t >= 1 ? to : TextStyle.lerp(from, to, t)!);

  /// 图标 + 文字。[tone] 是颜色与文字淡入的程度（0~1），[pop] 是图标放大
  /// 与文字展开的程度（弹簧驱动时可以越过 0~1）。
  Widget _content(double tone, double pop) {
    final colors = widget.colors;
    final style = widget.style;
    final labelMode = style.labelMode;
    final icon = SizedBox.square(
      dimension: style.iconBox,
      child: Center(
        child: Transform.scale(
          scale: 1 + (HomeNavGeometry.selectedIconScale - 1) * pop,
          child: FaIcon(
            widget.icon,
            size: style.iconSize,
            color: _mixColor(colors.unselectedIcon, colors.selectedIcon, tone),
          ),
        ),
      ),
    );
    Widget? label;
    if (labelMode != HomeBarLabelMode.never) {
      label = Padding(
        padding: EdgeInsets.only(top: style.labelGap),
        // 文字最多放大到 1.3 倍，大字体下栏的层级不变；格子宽度固定，
        // 太长的名称等比缩小到放得下，不截成省略号。
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.label,
              maxLines: 1,
              softWrap: false,
              style:
                  _mixStyle(
                    colors.unselectedLabel,
                    colors.selectedLabel,
                    tone,
                  ).copyWith(
                    fontSize: style.labelSize,
                    height: HomeBarMetrics.labelLineHeight,
                  ),
            ),
          ),
        ),
      );
      if (labelMode == HomeBarLabelMode.selected) {
        // 只显示选中项文字：文字从图标下方展开（高度由弹簧给出，图标随之
        // 让到上方）并淡入；收起时反向。结构恒定，未选中时高度为 0。
        label = ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: pop.clamp(0.0, 1.0),
            child: Opacity(opacity: tone.clamp(0.0, 1.0), child: label),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeBarMetrics.labelSideInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[icon, ?label],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    // 画出来的文字不进语义：名称由下面的 Semantics 给出，只有图标时读屏
    // 也读得到。
    final content = ExcludeSemantics(
      child: position == null
          ? AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                widget.labelCurve,
                _pop,
              ]),
              builder: (BuildContext context, Widget? _) =>
                  _content(widget.labelCurve.value, _pop.value),
            )
          : ValueListenableBuilder<double>(
              valueListenable: position,
              builder: (BuildContext context, double value, Widget? _) {
                final t = HomeNavGeometry.followAmount(
                  widget.index,
                  value,
                  widget.count,
                );
                return _content(t, t);
              },
            ),
    );

    final localizations = MaterialLocalizations.of(context);
    final button = Tooltip(
      message: widget.label,
      // 与 M3 NavigationBar 相同的提示位置。
      verticalOffset: 42,
      excludeFromSemantics: true,
      preferBelow: false,
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: InkWell(
          onTap: widget.onTap,
          // 不画点按水波纹：按压反馈只有内容的缩放回弹，波纹叠在玻璃上
          // 显得脏。焦点 / 悬停高亮仍裁成指示器的形状（铺满一格，圆角与
          // 指示器相同；完整胶囊时圆角被夹到格高的一半）。
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.style.indicatorRadius),
          ),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: SizedBox.expand(
            child: Center(
              child: AnimatedBuilder(
                animation: _press,
                builder: (BuildContext context, Widget? child) =>
                    Transform.scale(
                      scale: 1 - HomeNavGeometry.pressDepth * _press.value,
                      child: child,
                    ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      enabled: true,
      button: true,
      label: widget.label,
      child: kIsWeb
          ? button
          : Stack(
              alignment: Alignment.center,
              children: <Widget>[
                button,
                Semantics(
                  label: localizations.tabLabel(
                    tabIndex: widget.index + 1,
                    tabCount: widget.count,
                  ),
                ),
              ],
            ),
    );
  }
}
