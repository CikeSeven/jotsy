import 'package:flutter/material.dart';

import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';

/// 悬浮工具栏的卡片外壳：表面色、18dp 圆角与浮起阴影，并固定图标尺寸。
///
/// 工具按 40dp 一格排布（`resolveDiaryToolbarLayout`），系统字号放大会把
/// 「更多」面板里的说明文字撑出格子，所以卡片内关闭文字缩放。日记编辑页与
/// 模板编辑页共用这一层，两处的工具栏外观一致。
///
/// 材质：组件 [AppGlassComponent.toolbar] 为玻璃时换成 [AppGlassSurface]——
/// 工具栏叠在正文之上，下面是文字与图片，所以总是模糊（[AppGlassBlur.always]），
/// 投影只画在外侧（半透明底下不能用 elevation，会从底色里透出来）。「更多」、
/// 颜色与代码块面板都在这张卡片里，随之一起成为玻璃。经典材质保持原样。
///
/// 玻璃时调用方的淡入淡出必须用 `GlassReveal` / `ExpressiveEntrance(glass:
/// true)`，不能把本组件放进 Opacity / FadeTransition（模糊会采不到正文）。
class DiaryFloatingToolbarSurface extends StatelessWidget {
  const DiaryFloatingToolbarSurface({super.key, required this.child});

  /// 卡片圆角；玻璃与经典两种材质一致。
  static const double radius = 18;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: IconTheme(data: const IconThemeData(size: 16), child: child),
    );
    if (AppGlass.of(context).isGlass(AppGlassComponent.toolbar)) {
      return AppGlassSurface(
        component: AppGlassComponent.toolbar,
        borderRadius: BorderRadius.circular(radius),
        blur: AppGlassBlur.always,
        shadow: true,
        child: content,
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
