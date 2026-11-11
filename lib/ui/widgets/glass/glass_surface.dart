import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'glass_bottom_fade_painter.dart';
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
/// - 底缘渐隐（[bottomFadeExtent]）时底色改由 [GlassBottomFadePainter] 画，
///   模糊的淡出靠在背景模糊图层里擦除实现，见该字段的说明。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    this.borderRadius = BorderRadius.zero,
    required this.fill,
    this.blurSigma = 20,
    this.saturation = 1,
    this.blur = true,
    this.border,
    this.bottomHairline,
    this.bottomHairlineWidth = hairlineWidth,
    this.shadowColor,
    this.progress = 1,
    this.bottomFadeExtent,
    this.bottomFadeTrailing,
    this.grouped = false,
    this.backdropKey,
    required this.child,
  }) : assert(
         bottomFadeExtent == null || bottomFadeExtent >= 0,
         'bottomFadeExtent 不能为负。',
       ),
       assert(
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

  /// 模糊后背景的饱和度倍数（1 = 不变）。大于 1 时透出来的颜色更鲜亮，
  /// 底色再淡也看得出是一块玻璃而不是一层灰；随 [progress] 从 1 过渡到
  /// 目标值。为 1 时滤镜与只有模糊时完全相同（菜单、卡片等其余玻璃不受
  /// 影响）。
  final double saturation;

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

  /// 底缘渐隐的高度（玻璃顶栏用）：表面最下面这么高的一段里，玻璃自上而下
  /// 淡出——底色在整段里淡到全透明，背景模糊（连同饱和度增强）在最下面
  /// 三分之一里淡出（分两段的原因见 [GlassBottomFadePainter]）；到下缘时
  /// 只剩没有模糊的页面，表面没有看得见的下边界。内容（文字、按钮）不受
  /// 影响。表面比它矮时仍按下缘对齐，只是从半途开始。
  ///
  /// - null（默认）：不渐隐，树结构与没有这个参数时完全相同；
  /// - 0：不渐隐，但保留渐隐用的节点——调用方在“渐隐 / 不渐隐”之间切换时
  ///   传 0 而不是 null，树结构不变，内容不会被重新挂载；
  /// - 大于 0：渐隐。模糊的那一段只在模糊开启时画（[blur] 为 false 或
  ///   [progress] 为 0 时只淡底色）：它靠在背景模糊的离屏图层里擦除实现，
  ///   没有这一层时会直接擦掉下方的页面。
  ///
  /// 只适合直角、不画底部细线与描边的表面：它们都落在淡没了的那一段上。
  final double? bottomFadeExtent;

  /// 本表面下缘之下、同属一条栏的玻璃还有多高：一条栏由上下几片玻璃拼成时
  /// （日记页的刊头 + 标签栏），渐隐区按整条栏的下缘量，上面的片把下面
  /// 各片的高度经这里传入，渐隐就能跨片接着画，接缝处不断开。null（默认）
  /// 即 0——本表面的下缘就是栏的下缘。只在 [bottomFadeExtent] 大于 0 时
  /// 使用；值变化时只触发重画。
  final ValueListenable<double>? bottomFadeTrailing;

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

  /// 保持亮度不变的饱和度矩阵（Rec. 709 亮度系数）。
  static List<double> _saturationMatrix(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final k = 1 - s;
    return <double>[
      r * k + s, g * k, b * k, 0, 0, //
      r * k, g * k + s, b * k, 0, 0, //
      r * k, g * k, b * k + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }

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
    // 始终保留 BackdropFilter 节点、只切换 enabled：增删节点会让内容整棵
    // 重建，丢掉焦点、滚动位置与水波纹。
    final enabled = blur && t > 0 && blurSigma > 0;
    final fade = bottomFadeExtent;
    final fading = fade != null && fade > 0;
    if (fade != null) {
      // 渐隐时底色不再由外层 Material 均匀地画，改由画笔画成自上而下淡出的
      // 一块（先擦淡模糊、再画底色，见 GlassBottomFadePainter）；CustomPaint
      // 先画 painter 再画 child，内容照常叠在上面。
      //
      // 里面再垫一层透明的 Material 接住水波纹与悬停高亮：外层 Material 的
      // 墨迹画在它的 child（也就是这支画笔）之前，会被擦淡、再被底色盖住，
      // 渐隐区里的按钮按下去高亮就缺了一块。无论此刻渐隐与否都垫着，树
      // 结构不变。
      content = CustomPaint(
        painter: fading
            ? GlassBottomFadePainter(
                extent: fade,
                fill: _scaled(fill, t),
                eraseBackdrop: enabled,
                trailing: bottomFadeTrailing,
              )
            : null,
        child: Material(type: MaterialType.transparency, child: content),
      );
    }
    final surface = Material(
      type: MaterialType.canvas,
      color: fading ? Colors.transparent : _scaled(fill, t),
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
    final blurFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    final saturate = 1 + (saturation - 1) * t;
    // 先模糊再提饱和度：一次背景读取里完成，不多一层离屏。
    final filter = saturate == 1
        ? blurFilter
        : ImageFilter.compose(
            outer: ColorFilter.matrix(_saturationMatrix(saturate)),
            inner: blurFilter,
          );
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
