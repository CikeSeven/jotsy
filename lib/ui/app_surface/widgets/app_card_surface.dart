import 'package:flutter/material.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_surfaces.dart';
import 'app_glass_scope.dart';
import 'app_glass_surface.dart';

/// 页面内容卡片 / 分组的统一外壳：按材质设置在“经典实色”与“玻璃”之间
/// 二选一。
///
/// 经典分支与改版前设置分组卡片（`SettingsCardGroup`）的写法逐像素一致：
/// `Container(decoration: 圆角 + 描边 + 静止投影)` 套 `Material(底色, 圆角,
/// 裁切)`。注意 Container 会把描边宽度算进内边距，内容比外框内缩一个描边宽
/// ——改成 `Material(shape: … side: …)` 不是同一组像素，别“顺手”换掉。
///
/// 玻璃分支经 [AppGlassSurface]（`component: cards`，带外侧投影）：卡片在
/// 页面的可滚动列表里，一律共用页面的 `contentBackdropKey` 读取背景；没有
/// 背景图时不模糊，只有半透明底色。两种分支里内容都画在一层 Material 上，
/// 子树里的 InkWell 水波纹照常可见。
///
/// 经典分支以外的卡片写法（`Card.filled`、带底色的 Container 等）不必硬塞进
/// 本组件：在原处判断 `AppGlass.of(context).isGlass(AppGlassComponent.cards)`，
/// 玻璃时改用 `AppGlassSurface(component: AppGlassComponent.cards,
/// shadow: true, …)`，经典分支保持原样。
class AppCardSurface extends StatelessWidget {
  const AppCardSurface({
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.card)),
    this.color,
    this.border,
    this.shadow = true,
    this.clipBehavior = Clip.antiAlias,
    this.padding,
    required this.child,
  });

  final BorderRadius borderRadius;

  /// 经典分支的底色；默认 `ExpressiveSurfaces.cardColor`。玻璃分支不用它。
  final Color? color;

  /// 经典分支的描边；默认 `ExpressiveSurfaces.cardBorderSide`，传
  /// [BorderSide.none] 不画。玻璃分支的描边由材质设置决定。
  final BorderSide? border;

  /// 是否画投影：经典为 `AppEffects.restingCardShadow`（只在亮色），玻璃为
  /// 外侧投影。
  final bool shadow;

  /// 经典分支 Material 的裁切方式；玻璃表面总按圆角裁切。
  final Clip clipBehavior;

  /// 内容的内边距（画在表面之内，两种分支一致）。
  final EdgeInsetsGeometry? padding;
  final Widget child;

  /// 当前位置的卡片是否用玻璃（便于调用方在卡片之外做相应调整）。
  static bool isGlass(BuildContext context) =>
      AppGlass.of(context).isGlass(AppGlassComponent.cards);

  @override
  Widget build(BuildContext context) {
    final inner = padding;
    final content = inner == null
        ? child
        : Padding(padding: inner, child: child);
    if (isGlass(context)) {
      return AppGlassSurface(
        component: AppGlassComponent.cards,
        borderRadius: borderRadius,
        shadow: shadow,
        child: content,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final side = border ?? ExpressiveSurfaces.cardBorderSide(scheme);
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: side == BorderSide.none ? null : Border.fromBorderSide(side),
        boxShadow: shadow ? AppEffects.restingCardShadow(scheme) : null,
      ),
      child: Material(
        color: color ?? ExpressiveSurfaces.cardColor(scheme),
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: content,
      ),
    );
  }
}
