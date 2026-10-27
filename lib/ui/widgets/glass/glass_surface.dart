import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'glass_reveal.dart';
import 'outer_shadow_painter.dart';

/// 通用的毛玻璃表面：外侧投影 → 圆角裁切 → 背景模糊 → 半透明底色 + 描边 /
/// 底部细线 → 内容。菜单、悬浮底栏与玻璃顶栏共用这一套做法。
///
/// 输入：底色（已带透明度）、模糊强度与开关、可选的描边 / 底部细线 / 投影，
/// 以及整体显现进度 [progress]；输出：一块按进度显现的玻璃。无副作用。
///
/// 约束（调用方必须遵守）：
/// - 禁止把玻璃表面整体放进 `Opacity` / `FadeTransition`：背景模糊要采样
///   表面下方的页面，放进透明度层后只能采到透明层自己，显现途中会先闪一下
///   没有模糊的底。需要淡入时用 [progress]——它按比例缩放底色、描边、细线与
///   投影的透明度以及模糊强度；内容另行淡入。整块（玻璃连同内容）淡入时
///   用祖先 [GlassReveal]：它的进度与 [progress] 相乘，并由本表面把内容放进
///   玻璃里面的一层 Opacity 一起淡入。
/// - 投影只画在外侧（[OuterShadowPainter]）：底色半透明，普通 elevation
///   会从底下透出来，把表面中间压暗。
/// - 底色由一层 canvas 类型的 [Material] 画出，因此内容里的 InkWell 水波纹
///   可以直接画在玻璃上。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    this.borderRadius = BorderRadius.zero,
    required this.fill,
    this.blurSigma = 20,
    this.blur = true,
    this.border,
    this.bottomHairline,
    this.bottomHairlineWidth = hairlineWidth,
    this.shadowColor,
    this.progress = 1,
    this.grouped = false,
    this.backdropKey,
    required this.child,
  }) : assert(
         !grouped || backdropKey == null,
         'grouped 与 backdropKey 只能二选一：前者取最近的 BackdropGroup，'
         '后者直接指定共享背景的键。',
       );

  /// 底部细线的默认粗细（与实色栏顶部分隔线同一规格）。
  static const double hairlineWidth = 0.6;

  /// 圆角；顶栏贴边铺满时为 [BorderRadius.zero]。
  final BorderRadius borderRadius;

  /// 底色（已带透明度；不透明时就是实色表面）。
  final Color fill;
  final double blurSigma;

  /// 是否模糊背景；高对比度等退回不透明底色时为 false。
  final bool blur;

  /// 四周描边（悬浮胶囊用）；null 不画。
  final BorderSide? border;

  /// 底部细线颜色（玻璃顶栏用）；null 不画。只适合直角表面：带圆角时细线
  /// 两端会被圆角裁掉。
  final Color? bottomHairline;

  /// 底部细线的粗细；默认 [hairlineWidth]，玻璃顶栏按用户的设置传入。
  final double bottomHairlineWidth;

  /// 外侧投影颜色；null 不画投影。
  final Color? shadowColor;

  /// 显现进度（0 完全透明、1 完全显现）。
  final double progress;

  /// 是否经 `BackdropFilter.grouped` 共用最近的 [BackdropGroup]：相邻的几块
  /// 玻璃（如顶栏与底栏）同在一个 BackdropGroup 下时只读一次背景，省掉重复
  /// 的背景回读。没有 BackdropGroup 祖先时与普通模糊相同。
  final bool grouped;

  /// 直接指定共享背景读取的键（`BackdropFilter.backdropGroupKey`）：同一键下
  /// 的多块玻璃只读一次背景。用于不在同一个 [BackdropGroup] 子树里、却叠在
  /// 同一片背景上的玻璃（如页面背景交给内容卡片的
  /// `AppPageBackdrop.contentBackdropKey`）。与 [grouped] 互斥。
  final BackdropKey? backdropKey;
  final Widget child;

  static Color _scaled(Color color, double factor) =>
      color.withValues(alpha: color.a * factor);

  @override
  Widget build(BuildContext context) {
    final reveal = GlassReveal.of(context);
    final t = (progress * reveal).clamp(0.0, 1.0);
    final side = border;
    final hairline = bottomHairline;
    Widget content = child;
    // 祖先 GlassReveal 代替了外面的透明度层，内容的淡入改由这里负责：
    // Opacity 放在 BackdropFilter 之内，只影响内容本身，不妨碍模糊采样。
    // 只有存在作用域时才包这一层，没有作用域时树结构与原来完全相同。
    // （自身的 progress 不参与：它只管玻璃表面，内容由调用方另行淡入。）
    if (GlassReveal.hasScope(context)) {
      content = Opacity(opacity: reveal, child: content);
    }
    if (hairline != null) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _scaled(hairline, t),
              width: bottomHairlineWidth,
            ),
          ),
        ),
        child: content,
      );
    }
    final surface = Material(
      type: MaterialType.canvas,
      color: _scaled(fill, t),
      surfaceTintColor: Colors.transparent,
      // 进度已经逐帧给出颜色与描边，关掉 Material 自己的颜色补间，免得拖尾。
      animationDuration: Duration.zero,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: side == null
            ? BorderSide.none
            : side.copyWith(color: _scaled(side.color, t)),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
    final sigma = blurSigma * t;
    final filter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    // 始终保留 BackdropFilter 节点、只切换 enabled：增删节点会让内容整棵
    // 重建，丢掉焦点、滚动位置与水波纹。
    final enabled = blur && t > 0 && blurSigma > 0;
    final blurred = ClipRRect(
      borderRadius: borderRadius,
      child: grouped
          ? BackdropFilter.grouped(
              enabled: enabled,
              filter: filter,
              child: surface,
            )
          : BackdropFilter(
              enabled: enabled,
              filter: filter,
              backdropGroupKey: backdropKey,
              child: surface,
            ),
    );
    final shadow = shadowColor;
    // 没有投影时也保留 CustomPaint 节点（画笔为 null），开关投影不改变树结构。
    return CustomPaint(
      painter: shadow == null
          ? null
          : OuterShadowPainter(
              color: _scaled(shadow, t),
              borderRadius: borderRadius,
            ),
      child: blurred,
    );
  }
}
