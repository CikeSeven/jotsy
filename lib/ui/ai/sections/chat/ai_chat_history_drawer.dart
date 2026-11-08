import 'package:flutter/material.dart';

import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../app_surface/widgets/app_glass_surface.dart';

/// 手机与中宽窗口的历史抽屉：宽为页面的 85%、最多 340，结束边 24 圆角。
///
/// 材质与底部面板同一口径：玻璃（“面板”为玻璃）时为总是模糊的
/// `AppGlassSurface`；经典时亮色 `surfaceContainerLowest`、暗色
/// `surfaceContainerHigh`（DESIGN §2.1“二级表面”）。
class AiChatHistoryDrawer extends StatelessWidget {
  const AiChatHistoryDrawer({
    super.key,
    required this.pageWidth,
    required this.child,
  });

  final double pageWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final glass = AppGlass.of(context).isGlass(AppGlassComponent.sheets);
    const radius = BorderRadiusDirectional.horizontal(end: Radius.circular(24));
    final width = pageWidth * 0.85;
    return Drawer(
      width: width < 340 ? width : 340,
      backgroundColor: glass
          ? Colors.transparent
          : (theme.brightness == Brightness.light
                ? colors.surfaceContainerLowest
                : colors.surfaceContainerHigh),
      shape: const RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: glass
          ? AppGlassSurface(
              component: AppGlassComponent.sheets,
              blur: AppGlassBlur.always,
              borderRadius: radius.resolve(Directionality.of(context)),
              child: child,
            )
          : child,
    );
  }
}
