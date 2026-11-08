import 'package:flutter/material.dart';

import '../../app/theme/app_radii.dart';
import '../../app/theme/expressive_surfaces.dart';
import '../app_surface/widgets/app_glass_scope.dart';
import '../app_surface/widgets/app_glass_surface.dart';
import 'expressive_state_blend.dart';

/// 可多选列表行的卡片表面：卡片底色 + 0.8dp 微边框、16dp 圆角，选中时底色与
/// 描边经 [ExpressiveStateBlend] 补间到 `secondaryContainer` / `secondary`。
///
/// 草稿箱、回收站（`DiaryListRowCard`）与存储管理的媒体行共用：经典 / 玻璃
/// 两种材质都在这里，行内容只管排版。[selectionMode] 只用于向读屏暴露选中
/// 态，勾选框由行内容自己画。
class SelectableRowSurface extends StatelessWidget {
  const SelectableRowSurface({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.selectionMode = false,
  });

  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadii.input);
    final glass = AppGlass.of(context).isGlass(AppGlassComponent.cards);
    return ExpressiveStateBlend(
      active: selected,
      builder: (BuildContext context, double t, Widget? child) {
        if (glass) {
          return _buildGlass(radius, t, child!, colorScheme);
        }
        return Material(
          color: Color.lerp(
            ExpressiveSurfaces.cardColor(colorScheme),
            colorScheme.secondaryContainer,
            t,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: Color.lerp(
                ExpressiveSurfaces.cardBorderColor(colorScheme),
                colorScheme.secondary,
                t,
              )!,
              width: 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: Semantics(
        selected: selectionMode ? selected : null,
        child: InkWell(onTap: onTap, onLongPress: onLongPress, child: child),
      ),
    );
  }

  /// 玻璃材质的行：内容玻璃（共用页面背景读取、无背景图不模糊），选中态
  /// 叠在玻璃之上——底色按 [t] 补间到 secondaryContainer、描边到 secondary，
  /// 与经典分支同一组目标色。节点结构不随 [t] 变化，补间中不重建内容。
  ///
  /// 水波纹画在最上面那层透明 Material 上：玻璃表面自带的 Material 在选中
  /// 底色之下，选中后水波纹会被底色盖住。
  Widget _buildGlass(
    BorderRadius radius,
    double t,
    Widget child,
    ColorScheme colorScheme,
  ) {
    return AppGlassSurface(
      component: AppGlassComponent.cards,
      borderRadius: radius,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: colorScheme.secondary.withValues(alpha: t),
              width: 0.8,
            ),
          ),
        ),
        child: ColoredBox(
          color: colorScheme.secondaryContainer.withValues(alpha: t),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}
