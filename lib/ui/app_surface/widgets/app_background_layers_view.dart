import 'package:flutter/material.dart';

import '../../../app/theme/expressive_surfaces.dart';
import '../controllers/app_background_slot.dart';

/// 把 [AppBackgroundSlot.layers] 画出来：自下而上叠放，每层按自己的透明度
/// 淡入，铺满父级。
///
/// - 纯色：一块铺满的颜色；
/// - 无背景（交叉淡入里的不透明底）：主题页面底色；
/// - 图片：`RepaintBoundary` 里的 cover 图 + 遮罩。图片层自成重绘边界，页面
///   内容重绘、滚动时只合成这一层缓存好的画面，不重画位图。图片下面先垫
///   一层页面底色：带透明区域的 PNG 不会透出下面的路由。
///
/// [opaque] 为 true 时，即使没有层也画一层页面底色——首页按页位置插值时
/// 下层必须始终不透明（见 `AppPagedBackground`）。
///
/// [drawScrim] 为 false 时图片层不画遮罩：遮罩交给页面自己画（见
/// `AppPageBackground.deferScrim`）。
class AppBackgroundLayersView extends StatelessWidget {
  const AppBackgroundLayersView({
    super.key,
    required this.layers,
    this.opaque = false,
    this.drawScrim = true,
  });

  final List<AppBackgroundLayer> layers;
  final bool opaque;
  final bool drawScrim;

  @override
  Widget build(BuildContext context) {
    final pageColor = ExpressiveSurfaces.pageBackground(
      Theme.of(context).colorScheme,
    );
    if (layers.isEmpty) {
      return opaque ? ColoredBox(color: pageColor) : const SizedBox.expand();
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        for (final layer in layers)
          FadeTransition(
            key: layer.key,
            opacity: layer.opacity,
            child: _AppBackgroundVisualView(
              visual: layer.visual,
              pageColor: pageColor,
              drawScrim: drawScrim,
            ),
          ),
      ],
    );
  }
}

class _AppBackgroundVisualView extends StatelessWidget {
  const _AppBackgroundVisualView({
    required this.visual,
    required this.pageColor,
    required this.drawScrim,
  });

  final AppBackgroundVisual visual;
  final Color pageColor;
  final bool drawScrim;

  @override
  Widget build(BuildContext context) {
    final background = visual.background;
    final image = visual.image;
    if (background.isImage && image != null) {
      final scrim = drawScrim ? background.scrimColor : null;
      return RepaintBoundary(
        child: ColoredBox(
          color: pageColor,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              RawImage(
                image: image.image,
                fit: BoxFit.cover,
                alignment: background.alignment,
                filterQuality: FilterQuality.medium,
              ),
              if (scrim != null && scrim.a > 0) ColoredBox(color: scrim),
            ],
          ),
        ),
      );
    }
    return ColoredBox(color: background.color ?? pageColor);
  }
}
