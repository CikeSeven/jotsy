import 'package:flutter/widgets.dart';

import '../../app/theme/expressive_motion.dart';

/// `Image.frameBuilder` 的统一实现：首次解码出画面时淡入，缓存命中时直接显示。
///
/// 封面、缩略图、查看器图片原先各自 `Image.file/network`，解码完成的那一帧画面
/// 会“啪”地冒出来，列表滚动到新卡片时尤其明显。正文嵌图早已做了淡入，这里把
/// 同一规则收敛成一处，所有图片入口共用，避免各处时长/曲线各写各的而漂移。
///
/// - [wasSynchronouslyLoaded] 为 true（ImageCache 命中）时不套任何动画层，
///   滚回已经显示过的卡片不会再闪一次；
/// - 时长经 [ExpressiveMotion.duration] 解析，系统开启“减少动态效果”时直接显示；
/// - 淡入结束后不透明度恒为 1，[AnimatedOpacity] 不再产生离屏合成层；
/// - 不用于分享长图的静态封面：截图时机不等图片解码，淡入中途截到的会是半透明画面。
Widget expressiveImageFrameBuilder(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded) {
    return child;
  }
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
    curve: ExpressiveMotion.effects,
    child: child,
  );
}
