import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/glass/glass_reveal.dart';
import '../../../widgets/glass/glass_surface.dart';
import '../../../widgets/width_layout_builder.dart';
import '../../models/home_bar_style/home_bar_metrics.dart';
import '../../models/home_bar_style/home_bar_resolved_style.dart';
import 'home_inline_create_button.dart';
import 'home_nav_bar.dart';

export 'home_inline_create_button.dart';

/// 悬浮底栏（纯展示）：一颗居中的玻璃胶囊承载导航项，右侧可并排一个新建
/// 按钮。首页底栏与设置页的样式预览共用。
///
/// 输入：导航项、选中项、点按回调、已解析样式 [style]、可选的页面位置
/// [position]（指示器跟随滑动）、启动显现进度 [progress]，以及并排按钮
/// [inlineAction] 与它是否显示 [showInlineAction]；输出：高 `style.barHeight`
/// 的一行，胶囊（连同并排按钮）在给定宽度里水平居中。不加外边距、不避让
/// 系统手势条（由调用方在外面留出），无副作用。
///
/// - 胶囊的宽度由内容决定：项数 × 项宽 + 两侧的缝（[HomeBarMetrics]），
///   不撑满；给定宽度放不下时项宽等比收窄（[HomeBarMetrics.fitItemWidth]）；
///   圆角取 `style.cornerRadius`（圆角程度为 1 时是完整胶囊）；
/// - 胶囊是 [GlassSurface]：禁止整体放进 Opacity（背景模糊会失效），启动
///   显现经 [progress] 交给 GlassSurface，导航项在玻璃内部另行淡入；
/// - 并排按钮的槽位宽度由弹簧在 0 与（栏高 + 间距）之间推动，胶囊与按钮
///   作为一组重新居中；窄屏上胶囊随槽位展开同步收窄，不会先跳一下。
class HomeFloatingBar extends StatefulWidget {
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

  /// 是否显示 [inlineAction]；切换时槽位由弹簧展开 / 收起。
  final bool showInlineAction;

  @override
  State<HomeFloatingBar> createState() => _HomeFloatingBarState();
}

class _HomeFloatingBarState extends State<HomeFloatingBar>
    with SingleTickerProviderStateMixin {
  /// 并排按钮槽位的展开程度：0 收起、1 展开；无界，展开时略微越过 1 再
  /// 落回（按钮弹出来）。
  late final AnimationController _slot = AnimationController.unbounded(
    vsync: this,
    value: widget.showInlineAction ? 1 : 0,
  );

  @override
  void didUpdateWidget(HomeFloatingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showInlineAction != widget.showInlineAction) {
      ExpressiveMotion.springTo(
        context,
        _slot,
        widget.showInlineAction ? 1 : 0,
        tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
      );
    }
  }

  @override
  void dispose() {
    _slot.dispose();
    super.dispose();
  }

  Widget _pill(double itemWidth) {
    final style = widget.style;
    final items = widget.items;
    final t = widget.progress.clamp(0.0, 1.0);
    return GlassSurface(
      borderRadius: BorderRadius.circular(style.cornerRadius),
      fill: style.fill,
      blur: style.translucent,
      blurSigma: style.blurSigma,
      saturation: style.saturation,
      // 描边由 Material 的形状画在裁切范围之内（BorderSide 默认居内），
      // 不会被 ClipRRect 切掉，也不压到外侧投影。
      border: BorderSide(
        color: style.borderColor,
        width: HomeBarMetrics.borderWidth,
      ),
      shadowColor: style.shadowColor,
      progress: t,
      // 与新建按钮共用首页外壳 BackdropGroup 的一次背景读取。
      grouped: true,
      // 导航项在玻璃内部淡入：Opacity 在 BackdropFilter 之下，只作用于
      // 内容，不影响背景采样。结构恒定，进度到 1 后为恒等值。
      child: Opacity(
        opacity: t,
        child: Padding(
          padding: EdgeInsets.all(style.itemInset),
          child: items.isEmpty
              ? SizedBox(width: itemWidth, height: style.itemHeight)
              : HomeNavBar(
                  items: items,
                  selectedIndex: widget.selectedIndex,
                  onTap: widget.onTap,
                  style: style,
                  itemWidth: itemWidth,
                  position: widget.position,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final action = widget.inlineAction;
    final side = style.barHeight;
    final count = math.max(1, widget.items.length);
    return SizedBox(
      height: side,
      // 只按宽度重建：槽位里的高度约束不影响项宽。
      child: WidthLayoutBuilder(
        builder: (BuildContext context, double maxWidth) {
          if (action == null) {
            return Center(
              child: _pill(
                HomeBarMetrics.fitItemWidth(
                  style.itemWidth,
                  count,
                  maxWidth,
                  inset: style.itemInset,
                ),
              ),
            );
          }
          final extent = side + HomeBarMetrics.inlineGap;
          // 胶囊按“槽位此刻的宽度”收窄：窄屏上槽位展开多少、胶囊就让出
          // 多少，两者始终恰好排满，不必在切换的那一帧跳到最终宽度。宽屏上
          // 项宽不变，胶囊复用同一个 widget，途中不重建。
          Widget? pill;
          double? pillItemWidth;
          return AnimatedBuilder(
            animation: _slot,
            builder: (BuildContext context, Widget? slot) {
              // 弹簧会越过 1 再回落，收起时也会略低于 0：宽度夹到不小于 0
              // （负宽度会触发布局断言），越过 1 的部分保留弹性。
              final slotWidth = math.max(0.0, _slot.value) * extent;
              final itemWidth = HomeBarMetrics.fitItemWidth(
                style.itemWidth,
                count,
                maxWidth - slotWidth,
                inset: style.itemInset,
              );
              if (pill == null || pillItemWidth != itemWidth) {
                pillItemWidth = itemWidth;
                pill = _pill(itemWidth);
              }
              return Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    pill!,
                    SizedBox(
                      width: slotWidth,
                      height: side,
                      child: OverflowBox(
                        alignment: AlignmentDirectional.centerStart,
                        minWidth: extent,
                        maxWidth: extent,
                        child: slot,
                      ),
                    ),
                  ],
                ),
              );
            },
            child: _InlineActionSlot(
              show: widget.showInlineAction,
              progress: _slot,
              side: side,
              child: action,
            ),
          );
        },
      ),
    );
  }
}

/// 并排按钮的槽位内容：按钮随 [progress]（弹簧）从 0.6 倍放大并淡入。
///
/// 按钮靠槽位起始一侧对齐（外层 OverflowBox）：槽位展开时按钮紧贴着胶囊
/// 末端长出来，不会叠在胶囊上。隐藏时排除语义与点按，免得读屏读到、或点到
/// 看不见的按钮。
class _InlineActionSlot extends StatelessWidget {
  const _InlineActionSlot({
    required this.show,
    required this.progress,
    required this.side,
    required this.child,
  });

  final bool show;
  final Animation<double> progress;
  final double side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = HomeInlineCreateButton.isGlass(context);
    return ExcludeSemantics(
      excluding: !show,
      child: IgnorePointer(
        ignoring: !show,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: HomeBarMetrics.inlineGap,
          ),
          child: AnimatedBuilder(
            animation: progress,
            child: SizedBox.square(dimension: side, child: child),
            builder: (BuildContext context, Widget? child) {
              final t = progress.value;
              // 透明度不越界；缩放保留弹簧的过冲。
              final opacity = t.clamp(0.0, 1.0);
              final scaled = Transform.scale(
                scale: math.max(0.0, 0.6 + 0.4 * t),
                child: child,
              );
              // 玻璃按钮不能放进透明度层，经 GlassReveal 由玻璃自己淡入。
              return glass
                  ? GlassReveal(progress: opacity, child: scaled)
                  : Opacity(opacity: opacity, child: scaled);
            },
          ),
        ),
      ),
    );
  }
}
