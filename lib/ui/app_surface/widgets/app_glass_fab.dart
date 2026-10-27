import 'package:flutter/material.dart';

import '../../widgets/glass/glass_surface.dart';
import 'app_glass_scope.dart';
import 'app_glass_surface.dart';
import 'app_page_backdrop.dart';

/// “控件”组件为玻璃时的 FAB 外壳：主色玻璃（primaryContainer 乘玻璃的
/// tintOpacity）+ 玻璃描边 + 外侧投影，按 [blur] 模糊下方内容。
///
/// 输入：一个照常构建的 FloatingActionButton（[child]）；输出：同样外形的
/// 玻璃按钮。按钮本身保留——点按水波纹、语义、tooltip、Hero 都不变——只是
/// 经一层局部 Theme 把它的底色换成透明、各状态 elevation 归零（半透明底下
/// 的普通阴影会透出来把按钮中间压暗，投影改由玻璃只画在外侧），并把点按
/// 区域收成按钮本身的尺寸（[MaterialTapTargetSize.shrinkWrap]）：否则小号
/// FAB 会被补成 48dp，玻璃比看得见的按钮大一圈。需要 48dp 点按区的调用方
/// 自行在外面补（见预览页“回到顶部”）。
///
/// 高对比度时底色换成不透明的 primaryContainer、不模糊（与其他玻璃同口径）。
/// 前景沿用主题的 onPrimaryContainer（FAB 主题已设），不做对比度兜底：主色
/// 容器色与它本就成对，模糊后的背景只是让底色略有起伏。
///
/// 约束：与 [GlassSurface] 相同——禁止放进 Opacity / FadeTransition，显隐
/// 与入场经祖先 `GlassReveal`（它会把按钮内容放进玻璃里面一起淡入）。
class AppGlassFab extends StatelessWidget {
  const AppGlassFab({
    super.key,
    this.borderRadius,
    this.blur = AppGlassBlur.always,
    required this.child,
  });

  /// 圆角；缺省取 FAB 主题的圆角（`floatingActionButtonTheme.shape`），与
  /// 经典 FAB 外形一致。调用方给按钮另设了 shape 时必须传同样的圆角。
  final BorderRadius? borderRadius;

  /// 模糊策略，见 [AppGlassBlur]：浮在列表 / 正文上的按钮为 always；下面
  /// 没有内容的（如宽窗口侧栏上的）为 none。
  final AppGlassBlur blur;
  final Widget child;

  /// 主色玻璃的底色：primaryContainer 取玻璃底色的透明度；高对比度时不透明。
  static Color fillOf(AppGlassResolved glass, ColorScheme scheme) =>
      glass.translucent
      ? scheme.primaryContainer.withValues(alpha: glass.tint.a)
      : scheme.primaryContainer;

  /// 没有可用圆角时的回退（M3 FAB 规格）。
  static const double _fallbackRadius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = AppGlass.of(context);
    final fabTheme = theme.floatingActionButtonTheme;
    final shape = fabTheme.shape;
    final radius =
        borderRadius ??
        (shape is RoundedRectangleBorder
            ? shape.borderRadius.resolve(Directionality.of(context))
            : BorderRadius.circular(_fallbackRadius));
    final wantsBlur = switch (blur) {
      AppGlassBlur.auto => AppPageBackdrop.of(context).hasImage,
      AppGlassBlur.always => true,
      AppGlassBlur.none => false,
    };
    return GlassSurface(
      borderRadius: radius,
      fill: fillOf(glass, theme.colorScheme),
      blurSigma: glass.blurSigma,
      blur: wantsBlur && glass.canBlur,
      border: glass.border,
      shadowColor: glass.shadowColor,
      child: Theme(
        data: theme.copyWith(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          floatingActionButtonTheme: fabTheme.copyWith(
            backgroundColor: Colors.transparent,
            elevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            disabledElevation: 0,
          ),
        ),
        child: child,
      ),
    );
  }
}
