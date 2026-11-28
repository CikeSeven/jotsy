import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';

/// 浮岛顶栏里的一颗“岛”：48 高的胶囊表面，内容由调用方给出（返回圆、
/// 动作胶囊、标题胶囊都是它）。
///
/// 材质跟随组件材质里的顶栏（[AppGlassComponent.topBars]）：
/// - 玻璃：[AppGlassSurface]，总是模糊（岛浮在头图与正文上，下面是文字与
///   图片），投影只画在外侧；
/// - 经典：浮起表面色（亮 `surfaceContainerLowest` / 暗 `surfaceContainerHigh`，
///   与对话框、面板同一层级）+ 0.8dp 微边框 + 单层 softShadow。
///
/// 两种材质都在内容下垫一层 Material，按钮的状态层与水波纹画在岛上、被
/// 胶囊形裁切。玻璃时禁止把岛放进 Opacity / FadeTransition（模糊会采不到
/// 下面的页面），淡入淡出经 `GlassReveal`（[FloatingTopBar] 已处理）。
class FloatingIsland extends StatelessWidget {
  const FloatingIsland({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  /// 岛的高度；里面的图标按钮是主题的 48 × 48，正好放下一行。
  static const double height = 48;

  static const BorderRadius radius = BorderRadius.all(
    Radius.circular(height / 2),
  );

  /// 岛与内容之间的内边距（动作胶囊两端留一点，文字胶囊左右留白）。
  final EdgeInsetsGeometry padding;
  final Widget child;

  /// 经典材质的岛底色（标题胶囊等需要同色的地方也取它）。
  static Color classicFill(ColorScheme colors) =>
      colors.brightness == Brightness.light
      ? colors.surfaceContainerLowest
      : colors.surfaceContainerHigh;

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      height: height,
      child: Padding(padding: padding, child: child),
    );
    if (AppGlass.of(context).isGlass(AppGlassComponent.topBars)) {
      return AppGlassSurface(
        component: AppGlassComponent.topBars,
        borderRadius: radius,
        blur: AppGlassBlur.always,
        shadow: true,
        child: content,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        shadows: AppEffects.softShadow(colors),
      ),
      child: Material(
        color: classicFill(colors),
        shape: StadiumBorder(side: ExpressiveSurfaces.cardBorderSide(colors)),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}

/// 左侧的返回圆岛（`angleLeft`，18）；[onPressed] 为 null 时返回上一页。
class FloatingBackIsland extends StatelessWidget {
  const FloatingBackIsland({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingIsland(
      child: IconButton(
        tooltip: context.l10n.commonBack,
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
      ),
    );
  }
}
