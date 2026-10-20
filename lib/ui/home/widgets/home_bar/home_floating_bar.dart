import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/glass/glass_surface.dart';
import '../../../widgets/glass/outer_shadow_painter.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';
import 'home_nav_bar.dart';

/// 玻璃材质的悬浮底栏（纯展示）：一条玻璃胶囊承载导航项，右侧可并排一个
/// 新建按钮。首页底栏与设置页的样式预览共用。
///
/// 输入：导航项、选中项、点按回调、已解析样式 [style]、可选的页面位置
/// [position]（指示器跟随滑动）、启动显现进度 [progress]，以及并排按钮
/// [inlineAction] 与它是否显示 [showInlineAction]；输出：高 `style.barHeight`
/// 的一行。不加外边距、不避让系统手势条（由调用方在外面留出），无副作用。
///
/// - 胶囊是 [GlassSurface]：禁止整体放进 Opacity（背景模糊会失效），启动
///   显现经 [progress] 交给 GlassSurface，导航项在玻璃内部另行淡入；
/// - 并排按钮的槽位宽度在 0 与（栏高 + 8）之间动画，胶囊随之收窄 / 铺满；
///   按钮是实色的，可以直接用 Opacity 淡入。
class HomeFloatingBar extends StatelessWidget {
  const HomeFloatingBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.style,
    this.position,
    this.progress = 1,
    this.inlineAction,
    this.showInlineAction = false,
  });

  /// 胶囊与并排按钮之间的距离。
  static const double inlineGap = 8;

  /// 导航项一行在胶囊内的左右内边距。
  static const double horizontalPadding = 4;

  final List<BottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final HomeBarResolvedStyle style;

  /// 页面位置；非空时选中指示器跟随滑动（见 [HomeNavBar.position]）。
  final ValueListenable<double>? position;

  /// 玻璃的启动显现进度（[GlassSurface.progress]），导航项同步淡入。
  final double progress;

  /// 并排的新建按钮（[HomeInlineCreateButton]）。
  final Widget? inlineAction;

  /// 是否显示 [inlineAction]；切换时胶囊收窄 / 铺满、按钮缩放淡入淡出。
  final bool showInlineAction;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(style.cornerRadius);
    final pill = GlassSurface(
      borderRadius: radius,
      fill: style.fill,
      blur: style.translucent,
      blurSigma: style.blurSigma,
      // 描边由 Material 的形状画在裁切范围之内（BorderSide 默认居内），
      // 加粗时向内长、不会被 ClipRRect 切掉，也不压到外侧投影。
      border: style.border
          ? BorderSide(color: style.borderColor, width: style.borderWidth)
          : null,
      shadowColor: style.shadow ? style.shadowColor : null,
      progress: t,
      // 导航项在玻璃内部淡入：Opacity 在 BackdropFilter 之下，只作用于
      // 内容，不影响背景采样。结构恒定，进度到 1 后为恒等值。
      child: Opacity(
        opacity: t,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: items.isEmpty
              ? SizedBox(height: style.barHeight)
              : HomeNavBar(
                  items: items,
                  selectedIndex: selectedIndex,
                  onTap: onTap,
                  style: style,
                  height: style.barHeight,
                  position: position,
                ),
        ),
      ),
    );
    final action = inlineAction;
    if (action == null) {
      return SizedBox(height: style.barHeight, child: pill);
    }
    return SizedBox(
      height: style.barHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: pill),
          _InlineActionSlot(
            show: showInlineAction,
            side: style.barHeight,
            child: action,
          ),
        ],
      ),
    );
  }
}

/// 并排按钮的槽位：宽度在 0 与（[side] + 8）之间动画（spatial），按钮自身
/// 从 0.6 倍放大并淡入（透明度走 effects）。
///
/// 为什么按钮靠槽位左缘对齐：胶囊收窄时按钮紧贴着胶囊右端从屏幕右侧推入，
/// 不会叠在胶囊上；槽位未展开的部分落在右侧外边距与屏幕外，按钮此时透明。
/// 隐藏时排除语义与点按，免得读屏读到、或点到看不见的按钮。
class _InlineActionSlot extends StatefulWidget {
  const _InlineActionSlot({
    required this.show,
    required this.side,
    required this.child,
  });

  final bool show;
  final double side;
  final Widget child;

  @override
  State<_InlineActionSlot> createState() => _InlineActionSlotState();
}

class _InlineActionSlotState extends State<_InlineActionSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.show ? 1 : 0,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 减少动画开关可能在运行中变化，时长随 MediaQuery 更新。
    _controller.duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
  }

  @override
  void didUpdateWidget(_InlineActionSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show == widget.show) {
      return;
    }
    if (widget.show) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extent = widget.side + HomeFloatingBar.inlineGap;
    return ExcludeSemantics(
      excluding: !widget.show,
      child: IgnorePointer(
        ignoring: !widget.show,
        child: AnimatedBuilder(
          animation: _controller,
          child: Padding(
            padding: const EdgeInsets.only(left: HomeFloatingBar.inlineGap),
            child: SizedBox.square(dimension: widget.side, child: widget.child),
          ),
          builder: (BuildContext context, Widget? child) {
            final t = _controller.value;
            // spatial 会越过 1 再回落，也可能在起点附近略低于 0：宽度因子夹到
            // 不小于 0（负宽度会触发布局断言），越过 1 的部分保留弹性。
            final settle = ExpressiveMotion.spatial.transform(t);
            return SizedBox(
              width: math.max(0.0, settle) * extent,
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: extent,
                maxWidth: extent,
                child: Opacity(
                  opacity: ExpressiveMotion.effects.transform(t),
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * settle,
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 与悬浮底栏并排的新建按钮：边长为栏高的方块，圆角与胶囊一致（不超过
/// 边长一半），主色容器底色 + 加号图标，投影与胶囊同源。
///
/// [label] 用作长按提示与读屏文字（如“新建”“写进「旅行」”），按钮本身
/// 只有图标。[progress] 为显现进度：按钮是实色的，直接按比例淡入。
class HomeInlineCreateButton extends StatelessWidget {
  const HomeInlineCreateButton({
    super.key,
    required this.style,
    required this.label,
    required this.onPressed,
    this.progress = 1,
  });

  static const double iconSize = 20;

  final HomeBarResolvedStyle style;
  final String label;
  final VoidCallback onPressed;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final side = style.barHeight;
    final radius = BorderRadius.circular(
      math.min(style.cornerRadius, side / 2),
    );
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: CustomPaint(
            // 没有投影时也保留 CustomPaint 节点，开关投影不改变树结构。
            painter: style.shadow
                ? OuterShadowPainter(
                    color: style.shadowColor,
                    borderRadius: radius,
                  )
                : null,
            child: SizedBox.square(
              dimension: side,
              child: Material(
                color: scheme.primaryContainer,
                shape: RoundedRectangleBorder(borderRadius: radius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.plus,
                      size: iconSize,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
