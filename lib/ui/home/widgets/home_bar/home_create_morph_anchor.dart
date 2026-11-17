import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app_surface/widgets/app_glass_fab.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../diaries/controllers/diary_create_morph.dart';
import '../../../widgets/container_transform/morph_anchor.dart';

/// 首页的新建按钮（悬浮 FAB、悬浮底栏旁的方块按钮、宽窗口侧栏的按钮）作为
/// 新建日记整页收放的起点与落点（[DiaryCreateMorph.createButton]）。
///
/// 底色与前景色与按钮一致：实色为 primaryContainer / onPrimaryContainer；
/// “控件”为玻璃时取玻璃的主色底叠在页面估计色上的近似色（容器画不出背后的
/// 模糊，落定那一刻换回真正的玻璃，颜色只差在模糊上）与玻璃 FAB 的前景色。
///
/// [enabled] 为 false（按钮此刻新建的是待办）时换成一个永远不会被找的标签：
/// 结构不变，按钮不重建。
class HomeCreateMorphAnchor extends StatelessWidget {
  const HomeCreateMorphAnchor({
    super.key,
    required this.borderRadius,
    required this.face,
    required this.child,
    this.enabled = true,
  });

  final bool enabled;
  final double borderRadius;

  /// 按钮里的内容（不含底色），按 [Color] 前景色画；须与按钮逐像素一致。
  final Widget Function(Color foreground) face;

  final Widget child;

  /// 主题里 FAB 的圆角（与 [AppGlassFab] 同一取法）。
  static double fabRadius(BuildContext context) {
    final shape = Theme.of(context).floatingActionButtonTheme.shape;
    return shape is RoundedRectangleBorder
        ? shape.borderRadius.resolve(Directionality.of(context)).topLeft.x
        : 16;
  }

  /// 只看加号的按钮（底栏旁的方块、侧栏按钮）的样子。
  static Widget plusFace(Color foreground, {double size = 20}) => Center(
    child: FaIcon(FontAwesomeIcons.plus, size: size, color: foreground),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = AppGlass.of(context);
    final isGlass = glass.isGlass(AppGlassComponent.controls);
    final color = isGlass
        ? Color.alphaBlend(
            AppGlassFab.fillOf(glass, scheme),
            AppPageBackdrop.of(context).estimatedColor,
          )
        : scheme.primaryContainer;
    final foreground = isGlass
        ? AppGlassFab.foregroundOf(context)
        : scheme.onPrimaryContainer;
    return MorphAnchor(
      tag: enabled ? DiaryCreateMorph.createButton : const _Inactive(),
      borderRadius: borderRadius,
      color: color,
      landingSquash: 0.1,
      appearance: face(foreground),
      child: child,
    );
  }
}

class _Inactive {
  const _Inactive();
}
