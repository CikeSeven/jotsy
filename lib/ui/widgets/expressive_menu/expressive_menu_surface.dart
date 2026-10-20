import 'package:flutter/material.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_motion.dart';
import '../glass/glass_surface.dart';

/// 菜单的玻璃表面（参照 phase 的 FrostedSurface）：半透明底色 + 背景模糊 +
/// 细描边 + 只画在外侧的柔和投影，28 圆角。
///
/// - 底色：亮色取纯白 surfaceContainerLowest（与卡片同层，旧的 surfaceContainer
///   在白卡片上发灰），暗色取最高一层 surfaceContainerHighest（旧底色与暗色卡片
///   几乎同色，菜单沉在页面里）；都带一点透明，透出模糊后的页面颜色。
/// - 展开动画：进度分别驱动底色、描边、投影的透明度与模糊强度，内容单独淡入。
///   不把整块表面放进 FadeTransition：背景模糊要采样菜单下面的页面，放进整体
///   透明度层后只能采到透明层自己，展开途中会先闪一下没有模糊的底。
/// - 投影只画在表面外侧：底色半透明，普通 BoxShadow / elevation 会从底下透出来，
///   把菜单中间压暗。表面本身的画法见 [GlassSurface]。
/// - 减少动画或高对比度时退回不透明底色、不做模糊，保证文字稳定可读。
class ExpressiveMenuSurface extends StatelessWidget {
  const ExpressiveMenuSurface({
    super.key,
    required this.reveal,
    required this.child,
  });

  static const double radius = AppRadii.nav;
  static const double blurSigma = 20;
  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(radius),
  );

  /// 展开进度（0 收起、1 展开）。
  final Animation<double> reveal;
  final Widget child;

  /// 半透明底色。
  static Color tintOf(ColorScheme colors) =>
      colors.brightness == Brightness.light
      ? colors.surfaceContainerLowest.withValues(alpha: 0.82)
      : colors.surfaceContainerHighest.withValues(alpha: 0.84);

  /// 描边：亮色压在白底上要深一点才看得出轮廓。
  static Color borderOf(ColorScheme colors) => colors.outlineVariant.withValues(
    alpha: colors.brightness == Brightness.light ? 0.6 : 0.5,
  );

  /// 外侧投影色：取 shadow 语义色，暗色页面上要更深才看得出层次。
  static Color shadowOf(ColorScheme colors) => colors.shadow.withValues(
    alpha: colors.brightness == Brightness.light ? 0.12 : 0.32,
  );

  /// 是否退回不透明、无模糊的底。
  static bool solidOf(BuildContext context) =>
      ExpressiveMotion.reduceMotion(context) ||
      MediaQuery.highContrastOf(context);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: reveal,
    child: FadeTransition(
      opacity: reveal,
      alwaysIncludeSemantics: true,
      child: child,
    ),
    builder: (BuildContext context, Widget? child) =>
        _buildSurface(context, reveal.value.clamp(0.0, 1.0), child!),
  );

  Widget _buildSurface(BuildContext context, double progress, Widget child) {
    final colors = Theme.of(context).colorScheme;
    final solid = solidOf(context);
    final tint = tintOf(colors);
    return GlassSurface(
      borderRadius: borderRadius,
      fill: solid ? Color.alphaBlend(tint, colors.surface) : tint,
      blurSigma: blurSigma,
      blur: !solid,
      border: BorderSide(color: borderOf(colors)),
      shadowColor: shadowOf(colors),
      progress: progress,
      child: child,
    );
  }
}
