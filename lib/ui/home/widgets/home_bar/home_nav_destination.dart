import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../models/home_bar_style/home_bar_style.dart';
import 'home_nav_block.dart';
import 'home_nav_colors.dart';
import 'home_nav_indicator.dart';
import 'home_nav_ink_response.dart';
import 'home_nav_layout.dart';

// 颜色与水波纹从本文件拆出（保持在拆分阈值附近），底栏与侧边导航栏共用；
// 这里转出，引用方不必改 import。
export 'home_nav_colors.dart';
export 'home_nav_ink_response.dart';

/// 首页底栏的一个导航项（[HomeNavBar] 内部使用）。
///
/// 结构照搬 Material `NavigationDestination`：按钮语义 + “第 x 个标签，共 y
/// 个”、长按提示、水波纹裁到指示器形状、文字最多放大到 1.3 倍。
///
/// 指示器整栏只有一个，由 [indicatorPosition] 所在的锚点项画并平移到相邻
/// 一项（见 [HomeNavDestinationLayout]）。图标与文字的选中程度有两种来源：
/// - 未跟随滑动（[position] 为空）：本项自己的选中动画——颜色与“只显示
///   选中项文字”的文字显现按 [labelCurve] 渐变（不越界），图标的放大由弹簧
///   弹出（[ExpressiveMotion.springSpatialFast]，略微过冲）。指示器滑过
///   中间项时它们不变色：只有新旧两项在过渡；
/// - 跟随滑动（[position] 非空）：颜色、放大与文字显现都按与页面位置的距离
///   逐帧插值。
///
/// 按下时整项（连同落在本项的指示器）缩小一点，松手弹回：位移 / 缩放类的
/// 反馈都走真弹簧，按下中途松手会带着速度回弹。减少动画时没有缩放。
class HomeNavDestination extends StatefulWidget {
  const HomeNavDestination({
    super.key,
    required this.index,
    required this.count,
    required this.icon,
    required this.label,
    required this.selected,
    required this.selection,
    required this.labelCurve,
    required this.position,
    required this.indicatorPosition,
    required this.indicatorVelocity,
    required this.labelMode,
    required this.iconSize,
    required this.indicator,
    required this.labelGap,
    required this.blockPadding,
    required this.cornerRadius,
    required this.barHeight,
    required this.metrics,
    required this.colors,
    required this.onTap,
  });

  final int index;
  final int count;
  final FaIconData icon;
  final String label;
  final bool selected;

  /// 本项的选中动画（线性）与它的文字显现曲线。
  final Animation<double> selection;
  final Animation<double> labelCurve;

  /// 页面位置；非空时图标与文字的选中程度跟随它（“指示器跟随滑动”）。
  final ValueListenable<double>? position;

  /// 指示器的位置（小数序号）：跟随滑动时就是 [position]，否则是导航行的
  /// 弹簧。[indicatorVelocity] 给出弹簧此刻的速度（项 / 秒），指示器按它
  /// 拉长；跟随滑动时为 null。
  final ValueListenable<double> indicatorPosition;
  final ValueGetter<double>? indicatorVelocity;
  final HomeBarLabelMode labelMode;
  final double iconSize;
  final HomeBarIndicator indicator;

  /// 文字与图标框的间距、圆角块的内边距（见 HomeBarStyle 同名字段）。
  final double labelGap;
  final double blockPadding;

  /// 栏的圆角与高度：圆角块按它们推算同心圆角（见 [HomeNavBlockBorder]）。
  final double cornerRadius;
  final double barHeight;

  /// 同一栏共享的内容尺寸，跟随滑动时推算相邻一项的块大小。
  final HomeNavContentMetrics metrics;
  final HomeNavColors colors;
  final VoidCallback onTap;

  @override
  State<HomeNavDestination> createState() => _HomeNavDestinationState();
}

class _HomeNavDestinationState extends State<HomeNavDestination>
    with TickerProviderStateMixin {
  /// 按到底时整项缩小的比例。
  static const double _pressDepth = 0.07;

  /// 图标框（胶囊大小）的 key：胶囊样式的水波纹按它的位置画。
  final GlobalKey _iconKey = GlobalKey();

  /// 按压程度：0 松开、1 按到底；无界，松手时越过 0 再回落（整项略微弹大）。
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  /// 未跟随滑动时图标的选中放大：0 未选中、1 选中；无界，选中时弹过头一点。
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(HomeNavDestination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      ExpressiveMotion.springTo(
        context,
        _pop,
        widget.selected ? 1 : 0,
        spring: ExpressiveMotion.springSpatialFast,
      );
    }
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

  /// 本项圆角块占位的 key：圆角块与无指示器的水波纹按它的位置画。块的
  /// 大小要到布局时才知道（随文字宽度、内边距与文字显现变化），由布局
  /// delegate 把占位摆到块的位置。
  final GlobalKey _blockKey = GlobalKey();

  /// 选中程度 [t]（0~1）下的颜色；端点直接取原色，保证默认样式逐像素不变。
  static Color _mixColor(Color from, Color to, double t) =>
      t <= 0 ? from : (t >= 1 ? to : Color.lerp(from, to, t)!);

  static TextStyle _mixStyle(TextStyle from, TextStyle to, double t) =>
      t <= 0 ? from : (t >= 1 ? to : TextStyle.lerp(from, to, t)!);

  /// 选中程度 t 下的内容：未跟随时取本项选中动画的渐变值（[labelCurve]，
  /// 不越界），跟随时随页面位置逐帧重建。
  Widget _tracked(Widget Function(double t) builder) {
    final position = widget.position;
    if (position == null) {
      return AnimatedBuilder(
        animation: widget.labelCurve,
        builder: (BuildContext context, Widget? _) =>
            builder(widget.labelCurve.value),
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: position,
      builder: (BuildContext context, double value, Widget? _) => builder(
        HomeNavGeometry.followAmount(widget.index, value, widget.count),
      ),
    );
  }

  Animation<double> get _labelReveal {
    final position = widget.position;
    return switch (widget.labelMode) {
      HomeBarLabelMode.always => kAlwaysCompleteAnimation,
      HomeBarLabelMode.never => kAlwaysDismissedAnimation,
      HomeBarLabelMode.selected =>
        position == null
            ? widget.labelCurve
            : HomeNavFollowAmount(position, widget.index, widget.count),
    };
  }

  bool get _isCapsule => widget.indicator == HomeBarIndicator.capsule;

  ShapeBorder get _rippleShape => _isCapsule
      ? const StadiumBorder()
      : HomeNavBlockBorder(
          cornerRadius: widget.cornerRadius,
          barHeight: widget.barHeight,
        );

  /// 胶囊的水波纹画在图标框上；圆角块与“无指示器”都裁成本项圆角块的形状。
  Rect _rippleRect(RenderBox referenceBox) {
    final key = _isCapsule ? _iconKey : _blockKey;
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    return referenceBox.globalToLocal(rect.topLeft) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final position = widget.position;
    final iconSize = widget.iconSize;
    const grow = HomeNavGeometry.selectedIconScale - 1;

    final icon = _tracked((double t) {
      final color = _mixColor(colors.unselectedIcon, colors.selectedIcon, t);
      final glyph = FaIcon(widget.icon, size: iconSize, color: color);
      return IconTheme.merge(
        data: IconThemeData(size: iconSize, color: color),
        // 跟随滑动时放大量按页面位置逐帧给出（弹簧会落后于手指）；否则由
        // 弹簧 _pop 给出，可以越过 1。
        child: position == null
            ? AnimatedBuilder(
                animation: _pop,
                builder: (BuildContext context, Widget? child) =>
                    Transform.scale(scale: 1 + grow * _pop.value, child: child),
                child: glyph,
              )
            : Transform.scale(scale: 1 + grow * t, child: glyph),
      );
    });
    // 间距不再包在文字外（M3 用 Padding），由布局 delegate 加上：栏太矮
    // 时 delegate 要先收窄间距，文字才不越出栏。
    final label = _tracked(
      // 与 M3 相同：文字最多放大到 1.3 倍，大字体下栏的层级不变；
      // 再长就省略，窄屏不溢出。
      (double t) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Text(
          widget.label,
          style: _mixStyle(colors.unselectedLabel, colors.selectedLabel, t),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    // 胶囊样式的图标框至少是胶囊大小（与 M3 把指示器放进图标 Stack 时的
    // 尺寸相同）；圆角块与无指示器时收紧到图标大小加放大余量，圆角块才能
    // 贴着内容、按内边距包住它，而不是被 32dp 的胶囊框撑开。
    final slot = _isCapsule
        ? const Size(
            HomeNavGeometry.capsuleWidth,
            HomeNavGeometry.capsuleHeight,
          )
        : Size.square(HomeNavGeometry.iconSlot(iconSize));
    final labelReveal = _labelReveal;
    final layout = CustomMultiChildLayout(
      delegate: HomeNavDestinationLayout(
        labelReveal: labelReveal,
        indicator: widget.indicator,
        textDirection: Directionality.of(context),
        labelGap: widget.labelGap,
        blockPadding: widget.blockPadding,
        follow: HomeNavFollow(
          position: widget.indicatorPosition,
          velocity: widget.indicatorVelocity,
          index: widget.index,
          count: widget.count,
          labelMode: widget.labelMode,
          metrics: widget.metrics,
        ),
      ),
      children: <Widget>[
        if (!_isCapsule)
          LayoutId(
            id: HomeNavDestinationLayout.blockSlotId,
            child: SizedBox(key: _blockKey),
          ),
        if (widget.indicator != HomeBarIndicator.none)
          LayoutId(
            id: HomeNavDestinationLayout.indicatorId,
            child: HomeNavIndicator(
              selection: widget.selection,
              position: widget.indicatorPosition,
              index: widget.index,
              count: widget.count,
              shape: _rippleShape,
              color: colors.indicator,
            ),
          ),
        LayoutId(
          id: HomeNavDestinationLayout.iconId,
          child: KeyedSubtree(
            key: _iconKey,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox.fromSize(size: slot),
                icon,
              ],
            ),
          ),
        ),
        LayoutId(
          id: HomeNavDestinationLayout.labelId,
          // 隐藏的文字仍留在语义里（只有图标时读屏也能读出名称）。
          child: FadeTransition(
            alwaysIncludeSemantics: true,
            opacity: labelReveal,
            child: label,
          ),
        ),
      ],
    );

    final localizations = MaterialLocalizations.of(context);
    final content = Tooltip(
      message: widget.label,
      // 与 M3 NavigationBar 相同的提示位置。
      verticalOffset: 42,
      excludeFromSemantics: true,
      preferBelow: false,
      // 按压反馈听原始指针事件而不是 InkResponse 的 onTapDown：长按提示
      // 也在手势竞技场里，点按要等 100ms 才判定“按下”，轻点时按下与抬起
      // 会在同一帧到达，缩放根本来不及出现。
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: HomeNavIndicatorInkResponse(
          rectOf: _rippleRect,
          customBorder: _rippleShape,
          onTap: widget.onTap,
          child: Row(
            children: <Widget>[
              Expanded(
                child: AnimatedBuilder(
                  animation: _press,
                  builder: (BuildContext context, Widget? child) =>
                      Transform.scale(
                        scale: 1 - _pressDepth * _press.value,
                        child: child,
                      ),
                  child: layout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      enabled: true,
      button: true,
      child: kIsWeb
          ? content
          : Stack(
              alignment: Alignment.center,
              children: <Widget>[
                content,
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
