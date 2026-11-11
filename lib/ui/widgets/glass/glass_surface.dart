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
/// - 自上而下渐变（[fadeToBottom]）时底色改由 [GlassBottomFadePainter] 画，
///   且不与其他玻璃共用背景读取，见该字段的说明。
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
    this.fadeToBottom,
    this.extendAbove = 0,
    this.extendAboveVisible,
    this.grouped = false,
    this.backdropKey,
    required this.child,
  }) : assert(
         extendAbove >= 0 &&
             (extendAbove == 0 && extendAboveVisible == null ||
                 fadeToBottom != null),
         'extendAbove 不能为负，且与 extendAboveVisible 只用于渐变结构'
         '（fadeToBottom 非 null）。',
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

  /// 自上而下逐渐变透明（玻璃顶栏用）：从玻璃露出来的上缘到表面的下缘，
  /// 底色与背景模糊（连同饱和度增强）按同一条曲线一起由完整淡到没有，下缘
  /// 处只剩没有模糊的页面、看不出一条边。内容（文字、按钮）不受影响。
  ///
  /// - null（默认）：不渐变，树结构与没有这个参数时完全相同；
  /// - false：不渐变（均匀的底色），但保留渐变用的节点——调用方在“渐变 /
  ///   不渐变”之间切换时传 false 而不是 null，树结构不变，内容不会被重新
  ///   挂载；
  /// - true：渐变。模糊只在模糊开启时一起淡出（[blur] 为 false 或
  ///   [progress] 为 0 时只淡底色）：它靠在背景模糊的离屏图层里擦除实现，
  ///   没有这一层时会直接擦掉下方的页面。同样的原因，渐变时不与其他玻璃
  ///   共用背景读取（忽略 [grouped] 与 [backdropKey]）：Impeller 在几块
  ///   玻璃共用背景且滤镜相同时不开新图层、把子节点直接画进父图层，擦除会
  ///   把页面擦成黑色。
  ///
  /// 只适合直角、不画描边与投影的表面（顶栏）。
  final bool? fadeToBottom;

  /// 玻璃越过表面的上缘再往上铺多高（只画、不占布局、不接点按）：一条
  /// 顶栏由上下几片拼成时（日记页：刊头 + 钉住的标签栏），整条栏只用最下面
  /// 一片的这一块玻璃，往上垫到上面各片之后，上面的片只画内容。不各画各的：
  /// 后画的那片读背景时，先画的那片连同里面的标签、按钮已经在画布上，会被
  /// 模糊进它的下缘，接缝处看得出一道线；渐变也没法跨两块玻璃连成一条。
  /// 取上面各片可能的最大总高度，铺过头的部分落在滚动视图之外。只用于
  /// 渐变结构（[fadeToBottom] 非 null）。
  final double extendAbove;

  /// 往上铺的那截此刻露出来多高（上面各片此刻的总高度，布局时变化）；
  /// null 即 [extendAbove] 全部露出。渐变从露出来的上缘起算，没露出来的
  /// 那截不画；值变化时只触发重画。
  final ValueListenable<double>? extendAboveVisible;

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
    // Opacity 只包内容、不包玻璃（在 BackdropFilter 之内或与之并列），
    // 不妨碍模糊采样。
    // 只有存在作用域时才包这一层，没有作用域时树结构与原来完全相同。
    // （自身的 progress 不参与：它只管玻璃表面，内容由调用方另行淡入。）
    if (GlassReveal.hasScope(context)) {
      content = Opacity(opacity: reveal, child: content);
    }
    // 渐变结构里细线这一层始终在（没有细线时是空装饰）：顶栏在“渐变”与
    // “分隔线”之间切换时内容不被重新挂载。
    if (hairline != null || fadeToBottom != null) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: hairline == null
            ? const BoxDecoration()
            : BoxDecoration(
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
    final fade = fadeToBottom;
    final Widget glass;
    if (fade == null) {
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
      glass = ClipRRect(
        borderRadius: borderRadius,
        child: _backdrop(
          enabled: enabled,
          filter: filter,
          shared: true,
          child: surface,
        ),
      );
    } else {
      glass = _layeredGlass(
        fading: fade,
        fill: _scaled(fill, t),
        enabled: enabled,
        filter: filter,
        content: content,
      );
    }
    final shadow = shadowColor;
    // 没有投影时也保留 CustomPaint 节点（画笔为 null），开关投影不改变树结构。
    return CustomPaint(
      painter: shadow == null
          ? null
          : OuterShadowPainter(
              color: _scaled(shadow, t),
              borderRadius: borderRadius,
            ),
      child: glass,
    );
  }

  /// 背景模糊节点。[shared] 为 true 时按 [grouped] / [backdropKey] 共用
  /// 背景读取；为 false 时自己读一次背景、开自己的离屏图层（渐变要在这个
  /// 图层里擦除，见 [fadeToBottom]）。两种写法是同一个 widget 类型，
  /// 切换时节点不重建。
  Widget _backdrop({
    required bool enabled,
    required ImageFilter filter,
    required bool shared,
    required Widget child,
  }) {
    if (shared && grouped) {
      return BackdropFilter.grouped(
        enabled: enabled,
        filter: filter,
        child: child,
      );
    }
    return BackdropFilter(
      enabled: enabled,
      filter: filter,
      backdropGroupKey: shared ? backdropKey : null,
      child: child,
    );
  }

  /// 渐变结构：玻璃（模糊 + 底色）是垫在内容下面、往上多铺 [extendAbove]
  /// 的一块，内容照常按表面自己的大小布局。
  ///
  /// - 玻璃放在 Positioned 里、上边越出 Stack，只画不占位；IgnorePointer
  ///   之外，点按本来也落不到 Stack 的范围之外，往上铺的那截不挡上面那片的
  ///   内容；
  /// - 内容外包一层透明 Material 接住水波纹与悬停高亮（没有它，墨迹会画到
  ///   更外层、被玻璃盖住的 Material 上），并按表面裁切，与不渐变时一样；
  /// - Stack 用 passthrough：把外面的约束原样交给内容，表面的大小与不渐变
  ///   时相同。
  ///
  /// [fading] 为 false（不渐变、只是保留结构）时底色均匀，背景读取照常
  /// 共用；树结构与渐变时完全相同。
  Widget _layeredGlass({
    required bool fading,
    required Color fill,
    required bool enabled,
    required ImageFilter filter,
    required Widget content,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: <Widget>[
        Positioned(
          left: 0,
          top: -extendAbove,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: ClipRect(
              child: _backdrop(
                enabled: enabled,
                filter: filter,
                shared: !fading,
                child: CustomPaint(
                  painter: GlassBottomFadePainter(
                    fade: fading,
                    fill: fill,
                    eraseBackdrop: enabled && fading,
                    overhang: extendAbove,
                    visibleOverhang: extendAboveVisible,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        ClipRect(
          child: Material(
            type: MaterialType.transparency,
            animationDuration: Duration.zero,
            child: content,
          ),
        ),
      ],
    );
  }
}
