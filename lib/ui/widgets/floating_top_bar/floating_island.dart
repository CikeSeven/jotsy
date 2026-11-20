import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';

/// 浮岛顶栏里的一颗“岛”：48 高的胶囊表面，内容由调用方给出（返回圆、
/// 动作胶囊、标题胶囊都是它）。
///
/// 材质跟随组件材质里的顶栏（[AppGlassComponent.topBars]）：
/// - 玻璃：[AppGlassSurface]，投影只画在外侧。不在渐隐带上（宽窗口右栏）时
///   总是模糊（岛浮在头图与正文上，下面是文字与图片）；压在状态栏渐隐带
///   （[FloatingIslandBand]）上时不再模糊——那块带子已是一块模糊的玻璃，
///   同一区域不叠两层模糊——底色改用不透明的等效色，带子淡到透明的下半截
///   也不让底下清晰的文字透上来；
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
      final onBand = FloatingIslandBand.of(context);
      return AppGlassSurface(
        component: AppGlassComponent.topBars,
        borderRadius: radius,
        blur: onBand ? AppGlassBlur.none : AppGlassBlur.always,
        opaqueFill: onBand,
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

/// 标记子树里的岛压在状态栏渐隐带（`FloatingTopBarStatusStrip`）之上：由
/// `FloatingTopBarHost` 在画了渐隐带时包在浮岛那一行外面，[FloatingIsland]
/// 据此决定玻璃岛要不要自己模糊。岛由调用方构建、层层传进来，所以经
/// InheritedWidget 而不是参数。
class FloatingIslandBand extends InheritedWidget {
  const FloatingIslandBand({
    super.key,
    required this.onBand,
    required super.child,
  });

  final bool onBand;

  /// [context] 上方的岛是否压在渐隐带上；没有标记时为 false。
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FloatingIslandBand>()
          ?.onBand ??
      false;

  @override
  bool updateShouldNotify(FloatingIslandBand oldWidget) =>
      oldWidget.onBand != onBand;
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

/// 动作胶囊里的主色文字按钮（“完成”“保存”“发布”）：比图标按钮矮一截，
/// 嵌在 48 高的胶囊里上下各留 4。文字样式取主题的按钮字阶（不传裸
/// TextStyle，免得丢应用字体）。
class FloatingIslandPill extends StatelessWidget {
  const FloatingIslandPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
  });

  final String label;

  /// null 时停用（没有可保存的修改、写库中）。
  final VoidCallback? onPressed;

  /// 文字前的小图标（如保存成功后的对勾）。
  final Widget? icon;
  final String? tooltip;

  static final ButtonStyle _style = FilledButton.styleFrom(
    minimumSize: const Size(56, 40),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
  );

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    // 文字变化（“保存” ⇄ “✓ 已保存”）时宽度补间，胶囊跟着平滑伸缩。
    final content = AnimatedSize(
      duration: ExpressiveMotion.durationNonZero(
        context,
        ExpressiveMotion.medium,
      ),
      curve: ExpressiveMotion.spatial,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[icon, const SizedBox(width: 6)],
          Text(label),
        ],
      ),
    );
    final button = FilledButton(
      onPressed: onPressed,
      style: _style,
      child: content,
    );
    final tooltip = this.tooltip;
    final padded = Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, end: 4),
      child: button,
    );
    return tooltip == null ? padded : Tooltip(message: tooltip, child: padded);
  }
}
